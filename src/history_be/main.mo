import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Timer "mo:base/Timer";

import Map "mo:new-base/pure/Map";
import List "mo:new-base/List";

import PT "mo:promtracker";

import Http "tiny_http";
import CanisterHistory "CanisterHistory";
import Concurrent "info/concurrent_calls";

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

  public func setNumToSync(n : Nat) {
    canisters_num_to_sync := n;
  };

  /// Storage for all the canister histories.
  stable let history_storage = List.empty<CanisterHistory.History>();

  /// Maps the canister id to the history instance index in the storage.
  stable var history_storage_map = Map.empty<Principal, Nat>();

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
  stable var open_calls = 0;

  // During the testing phase we don't declare these stable
  // Resetting them to 0 makes it easier to interpret Grafana
  var trapsDetected = 0;
  var round = 0;

  var sync_pos = 0;
  var round_start = 0;

  let backlog = List.empty<CanisterHistory.History>();
  var backlog_pos = 0;

  func inc_sync_pos() = sync_pos += 1;
  func inc_backlog_pos() = backlog_pos += 1;

  // PromTracker
  let pt = PT.PromTracker("", 65);
  pt.addSystemValues();
  // gauges
  let syncSuccessDuration = pt.addGauge("canister_sync_duration_ms", "", #both, [], true);
  let syncFailureDuration = pt.addGauge("canister_sync_duration_ms", "", #both, [], true);
  let changesPerSync = pt.addGauge("canister_changes_per_sync", "", #both, [], true);
  // counters
  let triggers = pt.addCounter("triggers_total", "", true);
  let syncAttempts = pt.addCounter("sync_attempts_total", "", true);
  let metadataUpdates = pt.addCounter("metadata_update_total", "", true);
  let unauthorizedMetadataUpdates = pt.addCounter("unauthorized_metadata_update_total", "", true);
  // pull values
  ignore pt.addPullValue("canisters_synced_per_minute", "", func() = canisters_num_to_sync);
  ignore pt.addPullValue("uptime_seconds", "", uptime);
  ignore pt.addPullValue("traps_detected", "", func() = trapsDetected);
  ignore pt.addPullValue("backlog_size", "", func() = List.size(backlog));
  ignore pt.addPullValue("backlog_pos", "", func() = backlog_pos);
  ignore pt.addPullValue("tracked_canisters_total", "", func() = List.size(history_storage));
  ignore pt.addPullValue("sync_pos", "", func() = sync_pos);
  ignore pt.addPullValue("round_start", "", func() = round_start);
  ignore pt.addPullValue("round", "", func() = round);
  ignore pt.addPullValue("open_calls", "", func() = open_calls);

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
    List.add(history_storage, new_canister_history);
    assert insert_id(canister_id, new_index);
    #ok();
  };

  public func trackMany(canister_ids : [Principal]) : async [Result.Result<(), Errors.Track>] {
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
          List.add(history_storage, new_canister_history);
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
        metadataUpdates.add(1);
        #ok();
      };
      case false {
        unauthorizedMetadataUpdates.add(1);
        throw Error.reject("Access denied.");
      };
    };
  };

  func callItem(h : CanisterHistory.History, register_cb : () -> ()) : Concurrent.Item {
    let start_time = Time.now();
    {
      call_arg = CanisterHistory.API(h).sync_call_arg();
      register_call = func() {
        register_cb();
        syncAttempts.add(1);
        open_calls += 1;
      };
      process_response = func(info) {
        CanisterHistory.API(h).sync_call_process_response(info);
        changesPerSync.update(info.recent_changes.size());
        syncSuccessDuration.update(Int.abs(Time.now() - start_time) / 1_000_000_000);
        open_calls -= 1;
      };
      process_error = func(e) {
        switch (Error.code(e)) {
          case (#system_transient or #system_unknown) List.add(backlog, h);
          case (_) {}; // canister was deleted, skip it
        };
        syncFailureDuration.update(Int.abs(Time.now() - start_time) / 1_000_000_000);
        open_calls -= 1;
      };
    };
  };

  func trigger_sync() : async* () {
    triggers.add(1);
    let calls = Buffer.Buffer<Concurrent.Item>(canisters_num_to_sync);
    var ctr = 0;

    func addList(l : List.List<CanisterHistory.History>, start : Nat, register_cb : () -> ()) {
      var i = start;
      while (ctr < canisters_num_to_sync and i < List.size(l)) {
        let history = List.get(l, i);
        calls.add(callItem(history, register_cb));
        ctr += 1;
        i += 1;
      };
    };

    // process backlog first
    addList(backlog, backlog_pos, inc_backlog_pos);

    // now continue normal sync, but:
    // We only start a new round if all calls from the previous round have
    // returned and 5 min has passed since the last round started.
    // All calls from the previous round have returned if open_calls is 0 and
    // we are not scheduling new ones from the backlog.
    if (sync_pos == List.size(history_storage)) {
      sync_pos := 0;
      round += 1;
    };
    if (
      sync_pos > 0 or (
        calls.size() == 0 and
        open_calls == 0 and
        Time.now() >= round_start + 300_000_000_000
      )
    ) {
      addList(history_storage, sync_pos, inc_sync_pos);
    };

    await* Concurrent.make_calls(
      Buffer.toArray(calls),
      func(i) { trapsDetected += 1 }, // trap_cb
    );
  };

  ignore Timer.recurringTimer<system>(
    #seconds 60,
    func() : async () { await* trigger_sync() },
  );

  system func preupgrade() = pt_data := pt.share();

  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = Text.split(req.url, #char '?').next() else return Http.render400();
    let labels = "canister=\"" # PT.shortName(self) # "\"";
    switch (req.method, path) {
      case ("GET", "/metrics") Http.renderPlainText(pt.renderExposition(labels));
      case (_) Http.render400();
    };
  };
};
