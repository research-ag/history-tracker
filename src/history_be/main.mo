import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
// import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import ExtendedChange "history/extended_change";

import Iter "mo:new-base/Iter";
import Map "mo:new-base/pure/Map";
import List "mo:new-base/List";
import Queue "mo:new-base/Queue";
import PT "mo:promtracker";

import Task "models/task";

import Http "utils/tiny_http";
import RoundRobin "utils/round_robin";

import History "history";
import Metadata "history/metadata";
import Concurrent "history/info/concurrent_calls";

import Storage "./storage";
import Tracker "./tracker";

actor class HistoryTracker() = self {

  module Errors {
    public type UpdateMetadata = {
      #CanisterNotTracked : { message : Text };
    };
  };

  type CanisterChangesResponse = {
    changes : [ExtendedChange.ExtendedChange];
    total_num_changes : Nat64;
    timestamp_nanos : Nat64;
    sync_version : Nat;
  };

  /// Number of canisters that are synchronized per iteration.
  var canisters_num_to_sync = 100;

  /// A storage of history data
  stable var storageDataV2 : Storage.StableDataV1 = Storage.defaultStableDataV1();
  let storage : Storage.Storage = Storage.Storage(storageDataV2);

  /// Main task which loops over all of the canisters
  stable var allCanistersTaskData : (RoundRobin.RoundRobinGeneratorData, Task.TaskState) = (
    { size = 0; ctr = 0; round = 0 },
    {
      alias = "all_canisters";
      var roundsInterval = 300;
      var roundStart = 0;
      var lastRoundCompletedAt = 0;
      var lastRoundDuration = 0;
    },
  );
  let allCanistersTaskDataSource : RoundRobin.RoundRobinNatGenerator = RoundRobin.RoundRobinNatGenerator(?allCanistersTaskData.0);
  allCanistersTaskDataSource.setSize(storage.size());
  let allCanistersTask : Task.Task = Task.newTask(allCanistersTaskData.1, allCanistersTaskDataSource);

  /// Custom tasks
  stable var tasksData = Map.empty<Text, (RoundRobin.RoundRobinBufferData<Nat>, Task.TaskState)>();
  var tasks : Map.Map<Text, Task.BufferTask> = Map.map<Text, (RoundRobin.RoundRobinBufferData<Nat>, Task.TaskState), Task.BufferTask>(
    tasksData,
    func((_, td)) = Task.newBufferTask(td.1, RoundRobin.RoundRobinBuffer<Nat>(?td.0)),
  );

  stable var trackerData : Tracker.StableDataV1 = Tracker.defaultStableDataV1();
  let tracker : Tracker.Tracker = Tracker.Tracker(trackerData);

  func insertCanister(canisterId : Principal, history : History.History) : Nat {
    let id = storage.insertCanister(canisterId, history);
    allCanistersTaskDataSource.setSize(storage.size());
    tracker.inc();
    id;
  };

  let canister_start_time = Time.now();
  func uptime() : Nat = Int.abs(Time.now() - canister_start_time) / 1_000_000_000;

  // must be 0 when canister was stopped, but we declare it stable to test whether that is true
  var open_calls = 0;

  // During the testing phase we don't declare these stable
  // Resetting them to 0 makes it easier to interpret Grafana
  var trapsDetected = 0;

  let backlog = Queue.empty<Nat>();

  // PromTracker
  let pt = PT.PromTracker("", 65);
  pt.addSystemValues();
  // gauges
  func logarithmic(n : Nat, base : Nat, unit : Nat) : [Nat] = Array.tabulate<Nat>(n + 1, func(i) = if (i == 0) 0 else unit * base ** (i - 1));
  func linear(n : Nat, unit : Nat) : [Nat] = Array.tabulate<Nat>(n, func(i) = unit * i);
  let pt_syncSuccessDuration = pt.addGauge("canister_sync_success_duration", "", #both, logarithmic(10, 2, 1), false);
  let pt_syncFailureDuration = pt.addGauge("canister_sync_failure_duration", "", #both, logarithmic(10, 2, 1), false);
  let pt_changesPerSync = pt.addGauge("canister_changes_per_sync", "", #both, linear(10, 2), false);
  let pt_openCalls = pt.addGauge("trigger_open_calls", "", #both, logarithmic(10, 2, 1), false);
  let pt_backlog = pt.addGauge("trigger_backlog", "", #both, logarithmic(10, 2, 1), false);
  let pt_spawnedCalls = pt.addGauge("trigger_spawned_calls", "", #both, logarithmic(10, 2, 1), false);
  // counters
  let pt_triggers = pt.addCounter("triggers_total", "", false);
  let pt_syncAttempts = pt.addCounter("sync_attempts_total", "", false);
  let pt_metadataUpdates = pt.addCounter("metadata_update_total", "", true);
  let pt_unauthorizedMetadataUpdates = pt.addCounter("unauthorized_metadata_update_total", "", true);
  let pt_trigger_interval = pt.addCounter("trigger_interval", "", false);
  // pull values constants
  ignore pt.addPullValue("canisters_synced_per_minute", "", func() = canisters_num_to_sync);
  // pull values variables
  ignore pt.addPullValue("uptime_seconds", "", uptime);
  ignore pt.addPullValue("traps_detected", "", func() = trapsDetected);
  ignore pt.addPullValue("backlog_size", "", func() = Queue.size(backlog));
  ignore pt.addPullValue("open_calls", "", func() = open_calls);

  tracker.registerMetrics(pt);
  storage.registerMetrics(pt);
  Task.registerMetrics(pt, allCanistersTask);
  for (task in Map.values(tasks)) {
    Task.registerMetrics(pt, task);
  };

  stable var ptData : PT.StableData = null;
  pt.unshare(ptData);

  public query func tracked_canisters_total() : async Nat = async storage.size();

  public query func tracked_canisters(limit : Nat, skip : Nat) : async [Principal] = async storage.trackedCanisters(limit, skip);

  public query func get_tracking_stats() : async Tracker.TrackingStats = async tracker.getTrackingStats();

  public query func last_round_details(taskAlias : ?Text) : async {
    completed_at : Nat64;
    duration : Nat64;
    current_round : Nat;
  } {
    let task = switch (taskAlias) {
      case (?"all_canisters" or null) allCanistersTask;
      case (?alias) {
        let ?task = Map.get(tasks, Text.compare, alias) else throw Error.reject("Task with provided alias not found");
        task;
      };
    };
    {
      completed_at = task.lastRoundCompletedAt;
      duration = task.lastRoundDuration;
      current_round = task.dataSource.round();
    };
  };

  public query func is_canister_tracked(canister_id : Principal) : async Bool = async storage.isCanisterTracked(canister_id);

  public func track(canister_id : Principal) : async Result.Result<(), History.TrackError> {
    if (storage.isCanisterTracked(canister_id)) return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
    let new_canister_history = History.new();
    let info = switch (
      await* History.sync(canister_id, new_canister_history)
    ) {
      case (#ok x) x;
      case (#err err) return #err(err);
    };
    if (storage.isCanisterTracked(canister_id)) return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
    let id = insertCanister(canister_id, new_canister_history);
    new_canister_history.latest_change_timestamp := storage.appendChanges(id, 0, info);
    #ok();
  };

  public query func canister_changes(canister_id : Principal) : async ?CanisterChangesResponse {
    let ?canisterIdx = storage.canisterIndex(canister_id) else return null;
    let history = storage.get(canisterIdx);
    ?{
      changes = storage.readChanges(canisterIdx);
      total_num_changes = history.total_num_changes;
      timestamp_nanos = history.timestamp_nanos;
      sync_version = history.sync_version;
    };
  };

  public query func metadata(canister_id : Principal) : async ?Metadata.SharedMetadata {
    let ?idx = storage.canisterIndex(canister_id) else return null;
    let ?md = storage.readMetadata(idx) else return null;
    ?Metadata.shareMetadata(md);
  };

  public shared ({ caller }) func update_metadata(canister_id : Principal, name : ?Text, description : ?Text) : async Result.Result<(), Errors.UpdateMetadata> {
    if (not Principal.isController(caller)) {
      pt_unauthorizedMetadataUpdates.add(1);
      throw Error.reject("Access denied.");
    };
    let ?idx = storage.canisterIndex(canister_id) else return #err(#CanisterNotTracked({ message = "The canister is not tracked." }));
    storage.updateMetadata(idx, name, description);
    pt_metadataUpdates.add(1);
    #ok();
  };

  func trigger_sync() : async* () {
    pt_triggers.add(1);
    pt_openCalls.update(open_calls);
    // Debug.print("Open calls: " # debug_show open_calls);
    pt_backlog.update(Queue.size(backlog));

    let trigger_start_time = Prim.time() / 1_000_000_000;
    var callsToSpawn = Int.abs(Int.max(0, canisters_num_to_sync - open_calls));
    var spawnedCalls = 0;

    let calls = Buffer.Buffer<Concurrent.Item>(callsToSpawn);

    func callItem(canisterIdx : Nat, register_cb : () -> ()) : () {
      let h = storage.get(canisterIdx);
      let ?canisterId = storage.canisterId(canisterIdx) else Prim.trap("Can never happen!");
      let item : Concurrent.Item = {
        call_arg = History.sync_call_arg(canisterId);
        register_call = func() {
          register_cb();
          pt_syncAttempts.add(1);
          open_calls += 1;
          spawnedCalls += 1;
        };
        process_response = func(info) {
          History.sync_call_process_response(h, info);
          h.latest_change_timestamp := storage.appendChanges(canisterIdx, h.latest_change_timestamp, info);
          pt_changesPerSync.update(info.recent_changes.size());
          pt_syncSuccessDuration.update(Nat64.toNat(Prim.time() / 1_000_000_000 - trigger_start_time));
          open_calls -= 1;
        };
        process_error = func(e) {
          let error = History.sync_call_process_error(h, e);
          switch (error) {
            case (#Busy _) Queue.pushBack(backlog, canisterIdx);
            case (_) {};
          };
          pt_syncFailureDuration.update(Nat64.toNat(Prim.time() / 1_000_000_000 - trigger_start_time));
          open_calls -= 1;
        };
      };
      calls.add(item);
    };

    // process backlog first
    let backlogItems = Queue.values(backlog) |> Iter.take(_, callsToSpawn);
    for (idx in backlogItems) {
      callItem(idx, func() = ignore Queue.popFront(backlog));
      callsToSpawn -= 1;
    };

    if (callsToSpawn > 0) {
      var tasksToRun : List.List<Task.Task> = List.empty();
      List.add(tasksToRun, allCanistersTask);
      List.addAll(tasksToRun, Map.values(tasks));

      // TODO rotate list of tasks each trigger, so with big amount of tasks (relatively to canisters_num_to_sync) all of them have progress
      tasksToRun := List.filter<Task.Task>(
        tasksToRun,
        func(t) = t.dataSource.ctr() > 0 or trigger_start_time >= t.roundStart + t.roundsInterval,
      );

      // compile a list of tasks that about to start a new round
      let roundStartCandidates : List.List<(Task.Task, lastRound : Nat)> = tasksToRun
      |> List.filter<Task.Task>(_, func(t) = t.dataSource.ctr() == 0 and t.dataSource.itemsRemaining() > 0)
      |> List.map<Task.Task, (Task.Task, Nat)>(_, func(t) = (t, t.dataSource.round()));

      let dataSources : [Iter.Iter<Nat>] = tasksToRun
      |> List.map<Task.Task, Iter.Iter<Nat>>(_, func(t) = t.dataSource.view())
      |> List.toArray(_);

      let canistersToCall = RoundRobin.roundRobinCollect(dataSources, ?Nat.equal);
      label l for ((sourceIdx, canisterIdx) in canistersToCall) {
        callItem(canisterIdx, func() = List.get(tasksToRun, sourceIdx).dataSource.commit(1));
        callsToSpawn -= 1;
        if (callsToSpawn == 0) {
          break l;
        };
      };

      // detect the start of a round
      for ((t, lastRound) in List.values(roundStartCandidates)) {
        if (t.dataSource.round() != lastRound or t.dataSource.ctr() > 0) {
          t.roundStart := trigger_start_time;
        };
      };

      // detect the end of a round
      for (t in List.values(tasksToRun)) {
        if (t.dataSource.ctr() == 0) {
          t.lastRoundCompletedAt := trigger_start_time;
          t.lastRoundDuration := trigger_start_time - t.roundStart;
          switch (t.metrics.roundDurationGauge) {
            case (?g) g.update(t.lastRoundDuration |> Nat64.toNat(_));
            case (_) {};
          };
        };
      };
    };

    await* Concurrent.make_calls(
      Buffer.toArray(calls),
      func(i) { trapsDetected += 1 }, // trap_cb
    );
    pt_spawnedCalls.update(spawnedCalls);
  };

  var triggerTimer : ?Nat = ?Timer.recurringTimer<system>(
    #seconds 60,
    func() : async () { await* trigger_sync() },
  );
  pt_trigger_interval.set(60);

  // ADMIN API
  public func startTriggerTimer(intervalSeconds : Nat) : async () {
    switch (triggerTimer) {
      case (?t) {
        Timer.cancelTimer(t);
        triggerTimer := null;
      };
      case (null) {};
    };
    triggerTimer := ?Timer.recurringTimer<system>(
      #seconds intervalSeconds,
      func() : async () { await* trigger_sync() },
    );
    pt_trigger_interval.set(intervalSeconds);
  };

  public func stopTriggerTimer() : async () {
    switch (triggerTimer) {
      case (?t) {
        Timer.cancelTimer(t);
        triggerTimer := null;
      };
      case (_) {};
    };
    pt_trigger_interval.set(0);
  };

  public func setNumToSync(n : Nat) {
    canisters_num_to_sync := n;
  };

  public func setRoundsInterval(taskAlias : ?Text, n_ : Nat) {
    let n = Nat64.fromNat(n_);
    switch (taskAlias) {
      case (?"all_canisters" or null) allCanistersTask.roundsInterval := n;
      case (?alias) {
        let ?task = Map.get(tasks, Text.compare, alias) else throw Error.reject("Task with provided alias not found");
        task.roundsInterval := n;
      };
    };
  };

  public query func listTasks() : async [Text] {
    Map.keys(tasks) |> Iter.toArray(_);
  };

  public func createTask(taskAlias : Text) : async () {
    switch (Map.get(tasks, Text.compare, taskAlias)) {
      case (?t) throw Error.reject("Task with provided alias already exists");
      case (null) {};
    };
    let task = Task.newBufferTask(
      {
        alias = taskAlias;
        var roundStart = 0;
        var roundsInterval = 300;
        var lastRoundCompletedAt = 0;
        var lastRoundDuration = 0;
      },
      RoundRobin.RoundRobinBuffer(null),
    );
    tasks := Map.add(tasks, Text.compare, taskAlias, task);
    Task.registerMetrics(pt, task);
  };

  public func deleteTask(taskAlias : Text) : async () {
    let ?task = Map.get(tasks, Text.compare, taskAlias) else throw Error.reject("Task with provided alias not found");
    let (upd, _) = Map.delete<Text, Task.BufferTask>(tasks, Text.compare, taskAlias);
    tasks := upd;
    Task.deregisterMetrics(pt, task);
  };

  public func trackMany(taskAlias : ?Text, canister_ids : [Principal]) : async [Result.Result<(), History.TrackError>] {

    func syncCall(canister_id : Principal) : async Result.Result<(), History.TrackError> {
      if (storage.isCanisterTracked(canister_id)) return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
      let newCanisterHistory = History.new();
      let info = switch (
        await* History.sync(canister_id, newCanisterHistory)
      ) {
        case (#ok x) x;
        case (#err err) return #err(err);
      };
      if (storage.isCanisterTracked(canister_id)) return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
      let id = insertCanister(canister_id, newCanisterHistory);
      newCanisterHistory.latest_change_timestamp := storage.appendChanges(id, 0, info);
      #ok();
    };

    func trackInMainTask_(canister_ids : [Principal]) : async* [Result.Result<(), History.TrackError>] {
      let len = canister_ids.size();
      if (len > 100) throw Error.reject("Not more than 100 canister ids allowed in input.");

      let results = Array.init<Result.Result<(), History.TrackError>>(len, #ok());
      let calls = Buffer.Buffer<(Nat, async Result.Result<(), History.TrackError>)>(len);

      label L for (i in canister_ids.keys()) {
        let id = canister_ids[i];
        if (storage.isCanisterTracked(id)) {
          results[i] := #err(#AlreadyTracked({ message = "The canister is already tracked." }));
          continue L;
        };
        try {
          calls.add(i, syncCall(id));
        } catch (_) {
          results[i] := #err(#Busy({ message = "Cannot schedule self-call" }));
        };
      };

      for ((i, c) in calls.vals()) {
        results[i] := try {
          await c;
        } catch (e) {
          #err(History.track_error(e));
        };
      };

      Array.freeze(results);
    };

    switch (taskAlias) {
      case (null) await* trackInMainTask_(canister_ids);
      case (?ta) {
        let ?task = Map.get(tasks, Text.compare, ta) else throw Error.reject("Task with provided alias not found");
        let trackResult = (await* trackInMainTask_(canister_ids)) |> Array.thaw<Result.Result<(), History.TrackError>>(_);
        for (i in trackResult.keys()) {
          switch (trackResult[i]) {
            case (#ok or #err(#AlreadyTracked _)) {
              let ?idx = storage.canisterIndex(canister_ids[i]) else Prim.trap("Can never happen!");
              if (task.dataSource.hasItem(idx, Nat.equal)) {
                trackResult[i] := #err(#AlreadyTracked({ message = "Already tracked with priority" }));
              } else {
                task.dataSource.insertItem(idx);
                trackResult[i] := #ok();
              };
            };
            case (_) {};
          };
        };
        Array.freeze(trackResult);
      };
    };
  };

  system func preupgrade() {
    storageDataV2 := storage.share();
    allCanistersTaskData := (allCanistersTaskDataSource.share(), allCanistersTask);
    tasksData := Map.map<Text, Task.BufferTask, (RoundRobin.RoundRobinBufferData<Nat>, Task.TaskState)>(
      tasks,
      func((_, t)) = (t.dataSource.share(), t),
    );
    trackerData := tracker.share();
    ptData := pt.share();
  };

  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = Text.split(req.url, #char '?').next() else return Http.render400();
    let labels = "canister=\"" # PT.shortName(self) # "\"";
    switch (req.method, path) {
      case ("GET", "/metrics") Http.renderPlainText(pt.renderExposition(labels));
      case (_) Http.render400();
    };
  };
};
