import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Timer "mo:base/Timer";

import Map "mo:new-base/pure/Map";
import List "mo:new-base/List";
import Queue "mo:new-base/Queue";

import PT "mo:promtracker";

import Http "tiny_http";
import CanisterHistory "CanisterHistory";
import Concurrent "info/concurrent_calls";
import RoundRobin "round_robin";

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

  /// Number of canisters that are synchronized per iteration.
  var canisters_num_to_sync = 100;

  var rounds_interval = 300;

  stable let history_storage = List.empty<CanisterHistory.History>();
  /// Maps the canister id to the history instance index in the storage.
  stable var history_storage_map = Map.empty<Principal, Nat>();

  /// Main task which loops over all of the canisters
  let all_canisters_task : RoundRobin.RoundRobinNatGenerator = RoundRobin.RoundRobinNatGenerator();
  all_canisters_task.setSize(List.size(history_storage));

  /// Task with canisters marked as prioritized
  stable var prioritized_canisters_task_data : RoundRobin.RoundRobinBufferData<Nat> = {
    items = List.empty();
    ctr = 0;
    round = 0;
  };
  let prioritized_canisters_task : RoundRobin.RoundRobinBuffer<Nat> = RoundRobin.RoundRobinBuffer<Nat>();
  prioritized_canisters_task.unshare(prioritized_canisters_task_data);
  // TODO remove in future. Now we want to start all over again each upgrade
  prioritized_canisters_task.resetProgress();

  func get_index(canister_id : Principal) : ?Nat {
    Map.get<Principal, Nat>(history_storage_map, Principal.compare, canister_id);
  };

  func get_history(canister_id : Principal) : ?CanisterHistory.History {
    Option.map<Nat, CanisterHistory.History>(
      get_index(canister_id),
      func(i) = List.get(history_storage, i),
    );
  };

  func insert_id(canister_id : Principal, index : Nat) : Bool {
    let res = Map.insert<Principal, Nat>(history_storage_map, Principal.compare, canister_id, index);
    history_storage_map := res.0;
    res.1;
  };

  func exists_id(canister_id : Principal) : Bool {
    Map.containsKey(history_storage_map, Principal.compare, canister_id);
  };

  let start_time = Time.now();
  func uptime() : Nat = Int.abs(Time.now() - start_time) / 1_000_000_000;

  // must be 0 when canister was stopped, but we declare it stable to test whether that is true
  var open_calls = 0;

  // During the testing phase we don't declare these stable
  // Resetting them to 0 makes it easier to interpret Grafana
  var trapsDetected = 0;
  var round_start = 0;
  let backlog = Queue.empty<CanisterHistory.History>();

  // PromTracker
  let pt = PT.PromTracker("", 65);
  pt.addSystemValues();
  // gauges
  func logarithmic(n : Nat, base : Nat, unit : Nat) : [Nat] = Array.tabulate<Nat>(n + 1, func(i) = if (i == 0) 0 else unit * base ** (i - 1));
  func linear(n : Nat, unit : Nat) : [Nat] = Array.tabulate<Nat>(n, func(i) = unit * i);
  let pt_syncSuccessDuration = pt.addGauge("canister_sync_duration", "", #both, logarithmic(10, 2, 1), false);
  let pt_syncFailureDuration = pt.addGauge("canister_sync_duration", "", #both, logarithmic(10, 2, 1), false);
  let pt_changesPerSync = pt.addGauge("canister_changes_per_sync", "", #both, linear(10, 2), false);
  let pt_openCalls = pt.addGauge("trigger_open_calls", "", #both, logarithmic(10, 2, 1), false);
  let pt_backlog = pt.addGauge("trigger_backlog", "", #both, logarithmic(10, 2, 1), false);
  // counters
  let pt_triggers = pt.addCounter("triggers_total", "", false);
  let pt_syncAttempts = pt.addCounter("sync_attempts_total", "", false);
  let pt_metadataUpdates = pt.addCounter("metadata_update_total", "", true);
  let pt_unauthorizedMetadataUpdates = pt.addCounter("unauthorized_metadata_update_total", "", true);
  let pt_trigger_interval = pt.addCounter("trigger_interval", "", false);
  // pull values constants
  ignore pt.addPullValue("canisters_synced_per_minute", "", func() = canisters_num_to_sync);
  ignore pt.addPullValue("rounds_interval", "", func() = rounds_interval);
  // pull values variables
  ignore pt.addPullValue("uptime_seconds", "", uptime);
  ignore pt.addPullValue("traps_detected", "", func() = trapsDetected);
  ignore pt.addPullValue("backlog_size", "", func() = Queue.size(backlog));
  ignore pt.addPullValue("round_start", "", func() = round_start);
  ignore pt.addPullValue("open_calls", "", func() = open_calls);

  func registerTaskMetrics(taskAlias : Text, task : RoundRobin.RoundRobinSource<Nat>) {
    ignore pt.addPullValue("tracked_canisters_total", "task=\"" # taskAlias # "\"", func() = task.size());
    ignore pt.addPullValue("sync_pos", "task=\"" # taskAlias # "\"", func() = task.ctr());
    ignore pt.addPullValue("round", "task=\"" # taskAlias # "\"", func() = task.round());
  };
  registerTaskMetrics("all_canisters", all_canisters_task);
  registerTaskMetrics("prioritized_canisters", prioritized_canisters_task);

  stable var pt_data : PT.StableData = null;
  pt.unshare(pt_data);

  public query func tracked_canisters_total() : async Nat {
    List.size(history_storage);
  };

  public query func is_canister_tracked(canister_id : Principal) : async Bool {
    Map.get(history_storage_map, Principal.compare, canister_id) != null;
  };

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
    all_canisters_task.setSize(new_index);
    assert insert_id(canister_id, new_index);
    #ok();
  };

  private func trackMany_(canister_ids : [Principal]) : async* [Result.Result<(), Errors.Track>] {
    let len = canister_ids.size();
    if (len > 100) throw Error.reject("Not more than 100 canister ids allowed in input.");

    let results = Array.init<Result.Result<(), Errors.Track>>(len, #ok());
    let calls = Buffer.Buffer<Concurrent.Item>(len);

    label L for (i in canister_ids.keys()) {
      let id = canister_ids[i];
      if (exists_id(id)) {
        results[i] := #err(#AlreadyTracked({ message = "The canister is already tracked." }));
        continue L;
      };
      let new_canister_history = CanisterHistory.new(id);
      let item : Concurrent.Item = {
        call_arg = CanisterHistory.API(new_canister_history).sync_call_arg();
        register_call = func() {};
        process_response = func(info) {
          CanisterHistory.API(new_canister_history).sync_call_process_response(info);
          let new_index : Nat = List.size(history_storage);
          all_canisters_task.setSize(new_index);
          assert insert_id(id, new_index);
        };
        process_error = func(e) {
          results[i] := #err(track_error(e));
        };
      };
      calls.add(item);
    };

    await* Concurrent.make_calls(
      Buffer.toArray(calls),
      func(i) { trapsDetected += 1 }, // trap_cb
    );
    Array.freeze(results);
  };

  public func trackMany(canister_ids : [Principal]) : async [Result.Result<(), Errors.Track>] {
    await* trackMany_(canister_ids);
  };

  public query func canister_changes(canister_id : Principal) : async ?CanisterHistory.CanisterChangesResponse {
    Option.map<CanisterHistory.History, CanisterHistory.CanisterChangesResponse>(
      get_history(canister_id),
      func(h) = CanisterHistory.API(h).canister_changes(),
    );
  };

  public query func canister_state(canister_id : Principal) : async ?CanisterHistory.CanisterStateResponse {
    Option.map<CanisterHistory.History, CanisterHistory.CanisterStateResponse>(
      get_history(canister_id),
      func(h) = CanisterHistory.API(h).canister_state(),
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
    Debug.print("Open calls: " # debug_show open_calls);
    pt_backlog.update(Queue.size(backlog));

    var callsToSpawn = Int.abs(Int.max(0, canisters_num_to_sync - open_calls));

    // process backlog first
    label l while (callsToSpawn > 0) {
      switch (Queue.popFront(backlog)) {
        case (?h) {
          ignore callItem(h);
          callsToSpawn -= 1;
        };
        case (_) break l;
      };
    };

    if (callsToSpawn > 0) {
      let tasks : List.List<RoundRobin.RoundRobinSource<Nat>> = List.empty();

      // decide whether to execute "all_canisters" task
      if (all_canisters_task.ctr() > 0) {
        List.add(tasks, all_canisters_task);
      } else if (open_calls == 0) {
        let now = Time.now() / 1_000_000_000;
        // also wait for minimum round interval to pass
        if (now >= round_start + rounds_interval) {
          round_start := Int.abs(now);
          List.add(tasks, all_canisters_task);
        };
      };

      List.add(tasks, prioritized_canisters_task);

      // TODO rotate list of tasks each trigger, so with big amount of tasks (relatively to canisters_num_to_sync) all of them have progress

      for (index in RoundRobin.roundRobinCollect(List.toArray(tasks), callsToSpawn).vals()) {
        ignore callItem(List.get(history_storage, index));
      };
    };
  };

  var triggerTimer : ?Nat = ?Timer.recurringTimer<system>(
    #seconds 60,
    func() : async () { await* trigger_sync() },
  );
  pt_trigger_interval.set(60);

  // ADMIN API
  public func startTriggerTimer(intervalSeconds : Nat) : async () {
    switch (triggerTimer) {
      case (null) {
        triggerTimer := ?Timer.recurringTimer<system>(
          #seconds intervalSeconds,
          func() : async () { await* trigger_sync() },
        );
      };
      case (_) {};
    };
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

  public func setRoundsInterval(n : Nat) {
    rounds_interval := n;
  };

  public func trackWithPriority(canister_ids : [Principal]) : async [Result.Result<(), Errors.Track>] {
    let trackResult = (await* trackMany_(canister_ids)) |> Array.thaw<Result.Result<(), Errors.Track>>(_);
    for (i in trackResult.keys()) {
      switch (trackResult[i]) {
        case (#ok or #err(#AlreadyTracked _)) {
          let ?idx = get_index(canister_ids[i]) else Prim.trap("Can never happen!");
          if (prioritized_canisters_task.hasItem(idx, Nat.equal)) {
            trackResult[i] := #err(#AlreadyTracked({ message = "Already tracked with priority" }));
          } else {
            prioritized_canisters_task.insertItem(idx);
            trackResult[i] := #ok();
          };
        };
        case (_) {};
      };
    };
    Array.freeze(trackResult);
  };

  public func clearPrioritizedCanisters() : async () {
    prioritized_canisters_task.unshare({
      items = List.empty();
      ctr = 0;
      round = 0;
    });
  };

  system func preupgrade() {
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
