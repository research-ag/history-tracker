import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
// import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import Iter "mo:base/Iter";

import Map "mo:new-base/pure/Map";
import List "mo:new-base/List";
import Queue "mo:new-base/Queue";
import Enumeration "mo:stable-trie/Enumeration";
import PT "mo:promtracker";

import Http "tiny_http";
import CanisterHistory "CanisterHistory";
import RoundRobin "round_robin";
import PB "principal_blob";

actor class HistoryTracker() = self {

  module Errors {
    public type Track = {
      #AlreadyTracked : { message : Text };
      #DoesNotExist : { message : Text };
      #Busy : { message : Text };
      #Unexpected : { message : Text };
    };

    public type UpdateMetadata = {
      #CanisterNotTracked : { message : Text };
    };
  };

  module Task {
    public type TaskState = {
      alias : Text;
      var roundsInterval : Nat64;
      var roundStart : Nat64;
    };

    // common interface
    public type Task = {
      alias : Text;
      dataSource : RoundRobin.RoundRobinSource<Nat>;
      var roundsInterval : Nat64;
      var roundStart : Nat64;
    };
    public func newTask(state : TaskState, dataSource : RoundRobin.RoundRobinSource<Nat>) : Task = {
      alias = state.alias;
      dataSource;
      var roundsInterval = state.roundsInterval;
      var roundStart = state.roundStart;
    };

    // sub-interface
    public type BufferTask = {
      alias : Text;
      dataSource : RoundRobin.RoundRobinBuffer<Nat>;
      var roundsInterval : Nat64;
      var roundStart : Nat64;
    };
    public func newBufferTask(state : TaskState, dataSource : RoundRobin.RoundRobinBuffer<Nat>) : BufferTask = {
      alias = state.alias;
      dataSource;
      var roundsInterval = state.roundsInterval;
      var roundStart = state.roundStart;
    };

  };

  type TrackingBuckets = {
    var buckets : [var Nat]; // Mutable array of hourly counters
    var head_index : Nat; // Points to the current hour's bucket
    var last_rotation : Int; // Last time buckets were rotated
  };

  type TrackingStats = {
    new_24h : Nat;
    new_7d : Nat;
    new_30d : Nat;
  };

  // Time constants
  let HOUR_NS = 3600_000_000_000; // 1 hour in nanoseconds
  let DAY_HOURS = 24;
  let WEEK_HOURS = 168; // 7 * 24
  let MONTH_HOURS = 720; // 30 * 24

  /// Number of canisters that are synchronized per iteration.
  var canisters_num_to_sync = 100;

  stable let history_storage = List.empty<CanisterHistory.History>();

  /// Maps the canister id to the history instance index in the storage.
  var storage_map : Enumeration.Enumeration = Enumeration.Enumeration({
    aridity = 4;
    pointer_size = 6;
    key_size = 32;
    root_aridity = ?(4 ** 6);
    value_size = 0;
  });
  stable var storage_map_data : ?Enumeration.StableData = null;
  switch (storage_map_data) {
    case (?d) storage_map.unshare(d);
    case (null) {};
  };

  if (storage_map.size() == 0) {
    for (h in List.values(history_storage)) {
      ignore storage_map.add(PB.toBlob(h.canister_id), "");
    };
  } else if (storage_map.size() != List.size(history_storage)) {
    Prim.trap("Storage map out of sync");
  };

  /// Main task which loops over all of the canisters
  stable var allCanistersTaskData : (RoundRobin.RoundRobinGeneratorData, Task.TaskState) = (
    { size = 0; ctr = 0; round = 0 },
    { alias = "all_canisters"; var roundsInterval = 300; var roundStart = 0 },
  );
  let allCanistersTaskDataSource : RoundRobin.RoundRobinNatGenerator = RoundRobin.RoundRobinNatGenerator(?allCanistersTaskData.0);
  allCanistersTaskDataSource.setSize(List.size(history_storage));
  let allCanistersTask : Task.Task = Task.newTask(allCanistersTaskData.1, allCanistersTaskDataSource);

  /// Custom tasks
  stable var tasksData = Map.empty<Text, (RoundRobin.RoundRobinBufferData<Nat>, Task.TaskState)>();
  var tasks : Map.Map<Text, Task.BufferTask> = Map.map<Text, (RoundRobin.RoundRobinBufferData<Nat>, Task.TaskState), Task.BufferTask>(
    tasksData,
    func((_, td)) = Task.newBufferTask(td.1, RoundRobin.RoundRobinBuffer<Nat>(?td.0)),
  );

  stable var tracking_buckets : TrackingBuckets = {
    var buckets = Array.init<Nat>(MONTH_HOURS, 0);
    var head_index = 0;
    var last_rotation = Time.now();
  };

  func get_bucket_index(hours_ago : Nat) : Nat {
    // Calculate real index using circular buffer logic
    (tracking_buckets.head_index + hours_ago) % MONTH_HOURS;
  };

  func sum_buckets(hours : Nat) : Nat {
    var sum = 0;
    for (i in Iter.range(0, hours - 1)) {
      sum += tracking_buckets.buckets[get_bucket_index(i)];
    };
    sum;
  };

  func get_index(canister_id : Principal) : ?Nat {
    let ?(_, idx) = storage_map.lookup(PB.toBlob(canister_id)) else return null;
    ?idx;
  };

  func get_history(canister_id : Principal) : ?CanisterHistory.History {
    Option.map<Nat, CanisterHistory.History>(
      get_index(canister_id),
      func(i) = List.get(history_storage, i),
    );
  };

  func insert_id(canister_id : Principal, index : Nat) : Bool {
    let idx = storage_map.add(PB.toBlob(canister_id), "");
    idx == index;
  };

  func exists_id(canister_id : Principal) : Bool {
    Option.isSome(storage_map.lookup(PB.toBlob(canister_id)));
  };

  let start_time = Time.now();
  func uptime() : Nat = Int.abs(Time.now() - start_time) / 1_000_000_000;

  // must be 0 when canister was stopped, but we declare it stable to test whether that is true
  var open_calls = 0;

  // During the testing phase we don't declare these stable
  // Resetting them to 0 makes it easier to interpret Grafana
  var trapsDetected = 0;

  let backlog = Queue.empty<CanisterHistory.History>();
  var last_round_completed_at : Int = 0;
  var last_round_duration : Int = 0;

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
  let pt_roundDuration = pt.addGauge("round_duration", "", #both, linear(1, 1), false);
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
  ignore pt.addPullValue("tracked_24h", "", func() = sum_buckets(DAY_HOURS));
  ignore pt.addPullValue("tracked_7d", "", func() = sum_buckets(WEEK_HOURS));
  ignore pt.addPullValue("tracked_30d", "", func() = sum_buckets(MONTH_HOURS));

  func registerTaskMetrics(task : Task.Task) {
    ignore pt.addPullValue("tracked_canisters_total", "task=\"" # task.alias # "\"", func() = task.dataSource.size());
    ignore pt.addPullValue("sync_pos", "task=\"" # task.alias # "\"", func() = task.dataSource.ctr());
    ignore pt.addPullValue("round", "task=\"" # task.alias # "\"", func() = task.dataSource.round());
    ignore pt.addPullValue("round_start", "task=\"" # task.alias # "\"", func() = task.roundStart |> Nat64.toNat(_));
    ignore pt.addPullValue("rounds_interval", "task=\"" # task.alias # "\"", func() = task.roundsInterval |> Nat64.toNat(_));
    // TODO
    ignore pt.addPullValue("last_round_completed_at", "", func() = Int.abs(last_round_completed_at));
      ignore pt.addPullValue("last_round_duration", "", func() = Int.abs(last_round_duration));

  };
  registerTaskMetrics(allCanistersTask);
  for (task in Map.values(tasks)) {
    registerTaskMetrics(task);
  };

  stable var pt_data : PT.StableData = null;
  pt.unshare(pt_data);

  public query func tracked_canisters_total() : async Nat {
    List.size(history_storage);
  };

  func rotate_tracking_buckets() {
    let now = Time.now();
    let hours_passed = Int.abs(now - tracking_buckets.last_rotation) / HOUR_NS;

    if (hours_passed > 0) {
      // Clear only the new buckets we'll use
      let rotation_count = Nat.min(hours_passed, MONTH_HOURS);

      // Update head position
      for (i in Iter.range(0, rotation_count - 1)) {
        let new_head = (tracking_buckets.head_index + (MONTH_HOURS - 1) : Nat) % MONTH_HOURS;
        tracking_buckets.buckets[new_head] := 0;
        tracking_buckets.head_index := new_head;
      };

      tracking_buckets.last_rotation := now;
    };
  };

  func record_new_track() {
    rotate_tracking_buckets();
    tracking_buckets.buckets[tracking_buckets.head_index] += 1;
  };

  public query func get_tracking_stats() : async TrackingStats {
    rotate_tracking_buckets();
    {
      new_24h = sum_buckets(DAY_HOURS);
      new_7d = sum_buckets(WEEK_HOURS);
      new_30d = sum_buckets(MONTH_HOURS);
    };
  };

  public query func last_round_details() : async {
    completed_at : Int;
    duration : Int;
    current_round : Nat;
  } {
    {
      completed_at = last_round_completed_at;
      duration = last_round_duration;
      current_round = round;
    };
  };

  public query func is_canister_tracked(canister_id : Principal) : async Bool = async exists_id(canister_id);

  func track_error(e : Error.Error) : Errors.Track {
    switch (Error.code(e)) {
      case (#destination_invalid) return #DoesNotExist({
        message = "The canister does not exist.";
      });
      case (#system_transient or #system_unknown) return #Busy({
        message = "The system is busy. Try again.";
      });
      case (_) return #Unexpected({
        message = "An unexpected error was encountered: " # Error.message(e);
      });
    };
  };

  public func track(canister_id : Principal) : async Result.Result<(), Errors.Track> {
    if (Option.isSome(get_index(canister_id))) return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
    let new_canister_history = CanisterHistory.new(canister_id);
    try {
      ignore await* CanisterHistory.API(new_canister_history).sync();
    } catch (e) {
      return #err(track_error(e));
    };
    let new_index : Nat = List.size(history_storage);
    List.add(history_storage, new_canister_history);
    allCanistersTaskDataSource.setSize(new_index + 1);
    record_new_track();
    assert insert_id(canister_id, new_index);
    #ok();
  };

  public query func canister_changes(canister_id : Principal) : async ?CanisterHistory.CanisterChangesResponse {
    Option.map<CanisterHistory.History, CanisterHistory.CanisterChangesResponse>(
      get_history(canister_id),
      func(h) = CanisterHistory.API(h).canister_changes(),
    );
  };

  public query func metadata(canister_id : Principal) : async ?CanisterHistory.Metadata {
    Option.map<CanisterHistory.History, CanisterHistory.Metadata>(
      get_history(canister_id),
      func(h) = CanisterHistory.API(h).metadata(),
    );
  };

  public shared ({ caller }) func update_metadata(canister_id : Principal, name : ?Text, description : ?Text) : async Result.Result<(), Errors.UpdateMetadata> {
    let ?h = get_history(canister_id) else return #err(#CanisterNotTracked({ message = "The canister is not tracked." }));
    let result = await* CanisterHistory.API(h).update_metadata(caller, name, description);
    switch (result) {
      case true {
        pt_metadataUpdates.add(1);
        #ok();
      };
      case false {
        pt_unauthorizedMetadataUpdates.add(1);
        throw Error.reject("Access denied.");
      };
    };
  };

  func callItem(h : CanisterHistory.History) : async () {
    let start_time = Time.now();
    pt_syncAttempts.add(1);
    open_calls += 1;
    try {
      let info = await* CanisterHistory.API(h).sync();
      pt_changesPerSync.update(info.recent_changes.size());
      pt_syncSuccessDuration.update(Int.abs(Time.now() - start_time) / 1_000_000_000);
    } catch (e) {
      switch (Error.code(e)) {
        case (#system_transient or #system_unknown) Queue.pushBack(backlog, h);
        case (_) {}; // canister was deleted, skip it
      };
      pt_syncFailureDuration.update(Int.abs(Time.now() - start_time) / 1_000_000_000);
    } finally {
      open_calls -= 1;
    };
  };

  func trigger_sync() : async* () {
    pt_triggers.add(1);
    pt_openCalls.update(open_calls);
    // Debug.print("Open calls: " # debug_show open_calls);
    pt_backlog.update(Queue.size(backlog));

    let now = Prim.time() / 1_000_000_000;
    var callsToSpawn = Int.abs(Int.max(0, canisters_num_to_sync - open_calls));
    var spawnedCalls = 0;

    // process backlog first
    label l while (callsToSpawn > 0) {
      switch (Queue.peekFront(backlog)) {
        case (?h) {
          try {
            ignore callItem(h);
            spawnedCalls += 1;
          } catch (err) {
            Debug.print("Error while making self call for backlog entry: " # Error.message(err));
            pt_spawnedCalls.update(spawnedCalls);
            return;
          };
          ignore Queue.popFront(backlog);
          callsToSpawn -= 1;
        };
        case (_) break l;
      };
    };

    if (callsToSpawn > 0) {
      var tasksToRun : List.List<Task.Task> = List.empty();
      List.add(tasksToRun, allCanistersTask);
      List.addAll(tasksToRun, Map.values(tasks));

      // TODO rotate list of tasks each trigger, so with big amount of tasks (relatively to canisters_num_to_sync) all of them have progress
      tasksToRun := List.filter<Task.Task>(
        tasksToRun,
        func(t) = t.dataSource.ctr() > 0 or now >= t.roundStart + t.roundsInterval,
      );

      // compile a list of tasks that about to start a new round
      let roundStartCandidates : List.List<(Task.Task, lastRound : Nat)> = tasksToRun
      |> List.filter<Task.Task>(_, func(t) = t.dataSource.ctr() == 0 and t.dataSource.itemsRemaining() > 0)
      |> List.map<Task.Task, (Task.Task, Nat)>(_, func(t) = (t, t.dataSource.round()));

      let dataSources : [Iter.Iter<Nat>] = tasksToRun
      |> List.map<Task.Task, Iter.Iter<Nat>>(_, func(t) = t.dataSource)
      |> List.toArray(_);

      let canistersToCall = RoundRobin.roundRobinCollect(dataSources, callsToSpawn, ?Nat.equal);
      label l for ((sourceIdx, canisterIdx) in canistersToCall) {
        try {
          ignore callItem(List.get(history_storage, canisterIdx));
          spawnedCalls += 1;
        } catch (err) {
          Debug.print("Error while making self call: " # Error.message(err));
          // revert ctr increment in the data source
          let task = List.get(tasksToRun, sourceIdx);
          task.dataSource.decCtr();
          break l;
        };
      };

      for ((t, lastRound) in List.values(roundStartCandidates)) {
        if (t.dataSource.round() != lastRound or t.dataSource.ctr() > 0) {
          t.roundStart := now;
        };
      };
    };

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
      case (?"all_canisters") allCanistersTask.roundsInterval := n;
      case (?alias) {
        let ?task = Map.get(tasks, Text.compare, alias) else throw Error.reject("Task with provided alias not found");
        task.roundsInterval := n;
      };
      case (null) {
        allCanistersTask.roundsInterval := n;
        for (task in Map.values(tasks)) {
          task.roundsInterval := n;
        };
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
      },
      RoundRobin.RoundRobinBuffer(null),
    );
    tasks := Map.add(tasks, Text.compare, taskAlias, task);
    registerTaskMetrics(task);
  };

  public func trackMany(taskAlias : ?Text, canister_ids : [Principal]) : async [Result.Result<(), Errors.Track>] {

    func syncCall(id : Principal) : async Result.Result<(), Errors.Track> {
      if (exists_id(id)) {
        return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
      };
      let newCanisterHistory = CanisterHistory.new(id);
      try {
        ignore await* CanisterHistory.API(newCanisterHistory).sync();
      } catch (err) {
        return #err(track_error(err));
      };
      if (exists_id(id)) {
        return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
      };
      let new_index : Nat = List.size(history_storage);
      List.add(history_storage, newCanisterHistory);
      record_new_track();
      allCanistersTaskDataSource.setSize(new_index + 1);
      assert insert_id(id, new_index);
      #ok();
    };

    func trackInMainTask_(canister_ids : [Principal]) : async* [Result.Result<(), Errors.Track>] {
      let len = canister_ids.size();
      if (len > 100) throw Error.reject("Not more than 100 canister ids allowed in input.");

      let results = Array.init<Result.Result<(), Errors.Track>>(len, #ok());
      let calls = Buffer.Buffer<(Nat, async Result.Result<(), Errors.Track>)>(len);

      label L for (i in canister_ids.keys()) {
        let id = canister_ids[i];
        if (exists_id(id)) {
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
        } catch (err) {
          #err(track_error(err));
        };
      };

      Array.freeze(results);
    };

    switch (taskAlias) {
      case (null) await* trackInMainTask_(canister_ids);
      case (?ta) {
        let ?task = Map.get(tasks, Text.compare, ta) else throw Error.reject("Task with provided alias not found");
        let trackResult = (await* trackInMainTask_(canister_ids)) |> Array.thaw<Result.Result<(), Errors.Track>>(_);
        for (i in trackResult.keys()) {
          switch (trackResult[i]) {
            case (#ok or #err(#AlreadyTracked _)) {
              let ?idx = get_index(canister_ids[i]) else Prim.trap("Can never happen!");
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
    storage_map_data := ?storage_map.share();
    allCanistersTaskData := (allCanistersTaskDataSource.share(), allCanistersTask);
    tasksData := Map.map<Text, Task.BufferTask, (RoundRobin.RoundRobinBufferData<Nat>, Task.TaskState)>(
      tasks,
      func((_, t)) = (t.dataSource.share(), t),
    );
    pt_data := pt.share();
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
