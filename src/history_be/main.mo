import Array "mo:core/Array";
import VarArray "mo:core/VarArray";
import Error "mo:core/Error";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import Prim "mo:prim";
import Principal "mo:core/Principal";
import Result "mo:core/Result";
import Text "mo:core/Text";
import Time "mo:core/Time";
import Timer "mo:core/Timer";
import ExtendedChange "history/extended_change";

import Iter "mo:core/Iter";
import Map "mo:core/pure/Map";
import List "mo:core/List";
import Queue "mo:core/Queue";
import PT "mo:promtracker";
import { Tracker; Counter; Gauge; Heatmap } "mo:promtracker";
import Http "mo:promtracker/mixins/http";

import LogLists "mo:stable-log-lists";

import Task "models/task";

import RoundRobin "utils/round_robin";

import History "history";
import Metadata "history/metadata";
import Concurrent "history/info/concurrent_calls";

import Storage "./storage";
import HTracker "./tracker";

persistent actor class HistoryTracker() = self {

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
  transient var canisters_num_to_sync = 100;

  /// A storage of history data
  var storageDataV2 : Storage.StableDataV1 = Storage.defaultStableDataV1();

  /// Main task which loops over all of the canisters
  var allCanistersTaskData : (RoundRobin.RoundRobinGeneratorData, Task.TaskState) = (
    { size = 0; ctr = 0; round = 0 },
    {
      alias = "all_canisters";
      var roundsInterval = 300;
      var roundStart = 0;
      var lastRoundCompletedAt = 0;
      var lastRoundDuration = 0;
    },
  );
  transient let allCanistersTaskDataSource : RoundRobin.RoundRobinNatGenerator = RoundRobin.RoundRobinNatGenerator(?allCanistersTaskData.0);

  /// Custom tasks
  var tasksData = Map.empty<Text, (RoundRobin.RoundRobinBufferData<Nat>, Task.TaskState)>();
  transient var tasks : Map.Map<Text, Task.BufferTask> = Map.map<Text, (RoundRobin.RoundRobinBufferData<Nat>, Task.TaskState), Task.BufferTask>(
    tasksData,
    func((_, td)) = Task.newBufferTask(td.1, RoundRobin.RoundRobinBuffer<Nat>(?td.0)),
  );

  var trackerData : HTracker.StableDataV1 = HTracker.defaultStableDataV1();
  transient let tracker : HTracker.Tracker = HTracker.Tracker(trackerData);

  func insertCanister(canisterId : Principal, history : History.History) : Nat {
    let id = storage.insertCanister(canisterId, history);
    allCanistersTaskDataSource.setSize(storage.size());
    tracker.inc();
    id;
  };

  transient let canister_start_time = Time.now();
  func uptime() : Nat = Int.abs(Time.now() - canister_start_time) / 1_000_000_000;

  // must be 0 when canister was stopped, but we declare it stable to test whether that is true
  transient var open_calls = 0;

  // During the testing phase we don't declare these stable
  // Resetting them to 0 makes it easier to interpret Grafana
  transient var trapsDetected = 0;

  transient let backlog = Queue.empty<Nat>();

  // PromTracker
  let pt = Tracker.new();
  transient let renderer = PT.Renderer();
  renderer.addValue(pt.toValue());
  include Http(renderer.renderExposition, "/metrics");
  renderer.addCanisterLabel(self);
  renderer.addValue(PT.allSystemMetrics);

  // gauges
  func logarithmic(n : Nat, base : Nat, unit : Nat) : [Nat] = Array.tabulate<Nat>(n + 1, func(i) = if (i == 0) 0 else unit * base ** (i - 1));
  func linear(n : Nat, unit : Nat) : [Nat] = Array.tabulate<Nat>(n, func(i) = unit * i);
  let pt_syncSuccessDuration = pt.newGauge("canister_sync_success_duration", [], logarithmic(10, 2, 1));
  let pt_syncFailureDuration = pt.newGauge("canister_sync_failure_duration", [], logarithmic(10, 2, 1));
  let pt_changesPerSync = pt.newGauge("canister_changes_per_sync", [], linear(10, 2));
  let pt_openCalls = pt.newGauge("trigger_open_calls", [], logarithmic(10, 2, 1));
  let pt_backlog = pt.newGauge("trigger_backlog", [], logarithmic(10, 2, 1));
  let pt_spawnedCalls = pt.newGauge("trigger_spawned_calls", [], logarithmic(10, 2, 1));
  // counters
  let pt_triggers = pt.newCounter("triggers_total", []);
  let pt_syncAttempts = pt.newCounter("sync_attempts_total", []);
  let pt_metadataUpdates = pt.newCounter("metadata_update_total", []);
  let pt_unauthorizedMetadataUpdates = pt.newCounter("unauthorized_metadata_update_total", []);
  let pt_trigger_interval = pt.newCounter("trigger_interval", []);
  // heatmaps
  let changesAmountDistribution = pt.newHeatmap("changes_amount_distribution", []);

  transient let storage : Storage.Storage = Storage.Storage(storageDataV2, changesAmountDistribution);

  // refresh heatmap completely on canister upgrade (optional)
  changesAmountDistribution.count := 0;
  changesAmountDistribution.sum := 0;
  changesAmountDistribution.buckets := [var];
  for (i in List.keys(storageDataV2.historyStorage)) {
    changesAmountDistribution.add(LogLists.size(storageDataV2.changes, i));
  };

  allCanistersTaskDataSource.setSize(storage.size());
  transient let allCanistersTask : Task.Task = Task.newTask(allCanistersTaskData.1, allCanistersTaskDataSource);

  // pull values
  renderer.addValue(
    [
      PT.newValue("canisters_synced_per_minute", [], func() = canisters_num_to_sync),
      PT.newValue("uptime_seconds", [], uptime),
      PT.newValue("traps_detected", [], func() = trapsDetected),
      PT.newValue("backlog_size", [], func() = Queue.size(backlog)),
      PT.newValue("open_calls", [], func() = open_calls),
    ].bundle([])
  );

  tracker.registerMetrics(renderer);
  storage.registerMetrics(renderer);
  Task.registerMetrics(allCanistersTask, pt, renderer);
  for (task in Map.values(tasks)) {
    Task.registerMetrics(task, pt, renderer);
  };

  public query func tracked_canisters_total() : async Nat = async storage.size();

  public query func tracked_canisters(limit : Nat, skip : Nat) : async [Principal] = async storage.trackedCanisters(limit, skip);

  public query func get_tracking_stats() : async HTracker.TrackingStats = async tracker.getTrackingStats();

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

  func callItem(trigger_start_time : Nat64, canisterIdx : Nat, register_cb : () -> ()) : Concurrent.Item {
    let h = storage.get(canisterIdx);
    let ?canisterId = storage.canisterId(canisterIdx) else Prim.trap("Can never happen!");
    {
      call_arg = History.sync_call_arg(canisterId);
      register_call = func() {
        register_cb();
        pt_syncAttempts.add(1);
        open_calls += 1;
      };
      process_response = func(info) {
        History.sync_call_process_response(h, info);
        h.latest_change_timestamp := storage.appendChanges(canisterIdx, h.latest_change_timestamp, info);
        pt_changesPerSync.update(info.recent_changes.size());
        pt_syncSuccessDuration.update(Nat64.toNat(Prim.time() / 1_000_000_000 - trigger_start_time));
        if (open_calls == 0) {
          Prim.trap("Open calls cannot be less than 0 in 'process_response'");
        };
        open_calls -= 1;
      };
      process_error = func(e) {
        let error = History.sync_call_process_error(h, e);
        switch (error) {
          case (#Busy _) Queue.pushBack(backlog, canisterIdx);
          case (_) {};
        };
        pt_syncFailureDuration.update(Nat64.toNat(Prim.time() / 1_000_000_000 - trigger_start_time));
        if (open_calls == 0) {
          Prim.trap("Open calls cannot be less than 0 in 'process_error'");
        };
        open_calls -= 1;
      };
    };
  };

  func trigger_sync() : async* () {
    pt_triggers.add(1);
    pt_openCalls.update(open_calls);
    // Debug.print("Open calls: " # debug_show open_calls);
    pt_backlog.update(Queue.size(backlog));

    let trigger_start_time = Prim.time() / 1_000_000_000;
    var callsToSpawn = Int.abs(Int.max(0, canisters_num_to_sync : Int - open_calls));
    var spawnedCalls = 0;

    let calls = List.empty<Concurrent.Item>();

    // process backlog first
    let backlogItems = Queue.values(backlog) |> Iter.take(_, callsToSpawn);
    for (idx in backlogItems) {
      let call = callItem(
        trigger_start_time,
        idx,
        func() {
          ignore Queue.popFront(backlog);
          spawnedCalls += 1;
        },
      );
      List.add(calls, call);
      callsToSpawn -= 1;
    };

    var tasksToRun : List.List<(Task.Task, lastRound : Nat)> = List.empty();
    var roundStartCandidates : List.List<(Task.Task, lastRound : Nat)> = List.empty();

    if (callsToSpawn > 0) {
      List.add(tasksToRun, (allCanistersTask, allCanistersTask.dataSource.round()));
      List.addAll(tasksToRun, Map.values(tasks) |> Iter.map<Task.Task, (Task.Task, Nat)>(_, func(t) = (t, t.dataSource.round())));

      // TODO rotate list of tasks each trigger, so with big amount of tasks (relatively to canisters_num_to_sync) all of them have progress
      tasksToRun := List.filter<(Task.Task, Nat)>(
        tasksToRun,
        func(t, _) = t.dataSource.ctr() > 0 or trigger_start_time >= t.roundStart + t.roundsInterval,
      );

      // compile a list of tasks that about to start a new round
      roundStartCandidates := tasksToRun
      |> List.filter<(Task.Task, Nat)>(_, func(t, _) = t.dataSource.ctr() == 0 and t.dataSource.itemsRemaining() > 0);

      let dataSources : [Iter.Iter<(Nat, Nat)>] = tasksToRun
      |> List.map<(Task.Task, Nat), Iter.Iter<(Nat, Nat)>>(_, func(t, _) = t.dataSource.view())
      |> List.toArray(_);

      let canistersToCall = RoundRobin.roundRobinCollect<(Nat, Nat)>(dataSources, ?(func((_, cidA), (_, cidB)) = Nat.equal(cidA, cidB)));
      label l for ((sourceIdx, (canisterTaskIdx, canisterId)) in canistersToCall) {
        if (storage.get(canisterId).is_deleted) {
          continue l;
        };
        let call = callItem(
          trigger_start_time,
          canisterId,
          func() {
            let ?(task, initialRound) = List.get(tasksToRun, sourceIdx) else Prim.trap("Could not get task from list");
            if (task.dataSource.ctr() <= canisterTaskIdx and task.dataSource.round() == initialRound) {
              task.dataSource.setCtr(canisterTaskIdx + 1);
            };
            spawnedCalls += 1;
          },
        );
        List.add(calls, call);
        callsToSpawn -= 1;
        if (callsToSpawn == 0) {
          break l;
        };
      };
    };

    await* Concurrent.make_calls(
      List.toArray(calls),
      func(i) { trapsDetected += 1 }, // trap_cb
    );
    pt_spawnedCalls.update(spawnedCalls);

    // detect the start of a round
    for ((t, initialRound) in List.values(roundStartCandidates)) {
      if (t.dataSource.round() != initialRound or t.dataSource.ctr() > 0) {
        t.roundStart := trigger_start_time;
      };
    };

    // detect the end of a round
    for ((t, _) in List.values(tasksToRun)) {
      if (t.dataSource.ctr() == 0) {
        t.lastRoundCompletedAt := trigger_start_time;
        t.lastRoundDuration := trigger_start_time - t.roundStart;
        switch (t.metrics) {
          case (?{ roundDurationGauge }) roundDurationGauge.update(t.lastRoundDuration |> Nat64.toNat(_));
          case (_) {};
        };
      };
    };
  };

  transient var triggerTimer : ?Nat = ?Timer.recurringTimer<system>(
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

  public func setNumToSync(n : Nat) : async () {
    canisters_num_to_sync := n;
  };

  public func setRoundsInterval(taskAlias : ?Text, n_ : Nat) : async () {
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
    Task.registerMetrics(task, pt, renderer);
  };

  public func deleteTask(taskAlias : Text) : async () {
    let ?task = Map.get(tasks, Text.compare, taskAlias) else throw Error.reject("Task with provided alias not found");
    let (upd, _) = Map.delete<Text, Task.BufferTask>(tasks, Text.compare, taskAlias);
    tasks := upd;
    Task.deregisterMetrics(task, renderer);
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

      let results = VarArray.repeat<Result.Result<(), History.TrackError>>(#ok(), len);
      let calls = List.empty<(Nat, async Result.Result<(), History.TrackError>)>();

      label L for (i in canister_ids.keys()) {
        let id = canister_ids[i];
        if (storage.isCanisterTracked(id)) {
          results[i] := #err(#AlreadyTracked({ message = "The canister is already tracked." }));
          continue L;
        };
        try {
          List.add(calls, (i, syncCall(id)));
        } catch (_) {
          results[i] := #err(#Busy({ message = "Cannot schedule self-call" }));
        };
      };

      for ((i, c) in List.values(calls)) {
        results[i] := try {
          await c;
        } catch (e) {
          #err(History.track_error(e));
        };
      };

      Array.fromVarArray(results);
    };

    switch (taskAlias) {
      case (null) await* trackInMainTask_(canister_ids);
      case (?ta) {
        let ?task = Map.get(tasks, Text.compare, ta) else throw Error.reject("Task with provided alias not found");
        let trackResult = (await* trackInMainTask_(canister_ids)) |> Array.toVarArray<Result.Result<(), History.TrackError>>(_);
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
        Array.fromVarArray(trackResult);
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

    Task.deregisterMetrics(allCanistersTask, renderer);
    for (task in Map.values(tasks)) {
      Task.deregisterMetrics(task, renderer);
    };
  };

};
