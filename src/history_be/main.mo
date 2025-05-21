import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Map "mo:new-base/pure/Map";
import List "mo:new-base/List";

import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Error "mo:base/Error";
import PT "mo:promtracker";

import Http "tiny_http";
import CanisterHistory "CanisterHistory";
import Concurrent "info/concurrent_calls";

actor class HistoryTracker() = self {

  module Errors {
    public type Track = {
      #AlreadyTracked : { message : Text };
    };

    public type UpdateMetadata = {
      #CanisterNotTracked : { message : Text };
    };
  };

  let pt = PT.PromTracker("", 65);
  pt.addSystemValues();

  /// Number of canisters that are synchronized per iteration.
  let canisters_num_to_sync = 5;

  type StableData = PT.StableData;

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

  let start_time = Time.now();

  func uptime() : Nat {
    let end_time = Time.now();
    let duration : ?Nat = Nat.fromText(Int.toText(end_time - start_time));

    switch (duration) {
      case (?x) { x / 1_000_000_000 };
      case null {
        Debug.trap("Internal error");
      };
    };
  };

  ignore pt.addPullValue("tracked_canisters_total", "", func() = List.size(history_storage));
  let syncAttempts = pt.addCounter("sync_attempts_total", "", true);
  let syncSuccess = pt.addCounter("sync_success_total", "", true);
  let syncFailure = pt.addCounter("sync_failure_total", "", true);
  let syncDuration = pt.addGauge("canister_sync_duration_ms", "", #both, [], true);
  let changesPerSync = pt.addGauge("canister_changes_per_sync", "", #both, [], true);
  ignore pt.addPullValue("canisters_synced_per_minute", "", func() = canisters_num_to_sync);
  let metadataUpdates = pt.addCounter("metadata_update_total", "", true);
  let unauthorizedMetadataUpdates = pt.addCounter("unauthorized_metadata_update_total", "", true);
  ignore pt.addPullValue("uptime_seconds", "", uptime);

  stable var stable_data : StableData = pt.share();

  public query func tracked_canisters_total() : async Nat {
    List.size(history_storage);
  };

  public query func is_canister_tracked(canister_id : Principal) : async Bool {
    Map.get(history_storage_map, Principal.compare, canister_id) != null;
  };

  public func track(canister_id : Principal) : async Result.Result<(), Errors.Track> {
    if (Option.isSome(get_index(canister_id))) return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
    let new_canister_history = CanisterHistory.new(canister_id);
    ignore await* CanisterHistory.API(new_canister_history).sync();
    let new_index : Nat = List.size(history_storage);
    List.add(history_storage, new_canister_history);
    assert insert_id(canister_id, new_index);
    #ok();
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

  transient var open_calls = 0; // must be 0 when canister was stopped
  transient var trapsDetected = 0;

  var sync_pos = 0;

  func trigger_sync() : async* () {
    let N = List.size(history_storage);
    let sync_num = Nat.min(canisters_num_to_sync, N);
    if (open_calls >= sync_num) return;

    let new_calls : Nat = sync_num - open_calls;
    let calls = Buffer.Buffer<Concurrent.Item>(new_calls);

    var ctr = 0;
    while (ctr < new_calls) {
      let history = List.get(history_storage, sync_pos);
      if (not history.sync_ongoing) {
        var start_time = Time.now();
        let item : Concurrent.Item = {
          call_arg = CanisterHistory.API(history).sync_call_arg();
          register_call = func() {
            start_time := Time.now();
            syncAttempts.add(1);
            history.sync_ongoing := true;
            open_calls += 1;
          };
          process_response = func(info) {
            CanisterHistory.API(history).sync_call_process_response(info);
            syncSuccess.add(1);
            changesPerSync.update(info.recent_changes.size());

            let end_time = Time.now();
            let duration : ?Nat = Nat.fromText(Int.toText(end_time - start_time));

            switch (duration) {
              case (?x) { syncDuration.update((x) / 1_000_000) };
              case null {};
            };

            history.sync_ongoing := false;
            open_calls -= 1;
          };
          process_error = func(_) {
            syncFailure.add(1);
            history.sync_ongoing := false;
            open_calls -= 1;
          };
        };
        calls.add(item);
      };
      ctr += 1;
      sync_pos += 1;
      if (sync_pos >= N) sync_pos -= N;
    };

    await* Concurrent.make_calls(
      Buffer.toArray(calls),
      func(i) { syncFailure.add(1); trapsDetected += 1 }, // trap_cb
    );
  };

  ignore Timer.recurringTimer<system>(
    #seconds 60,
    func() : async () { await* trigger_sync() },
  );

  system func preupgrade() {
    stable_data := pt.share();
  };

  system func postupgrade() {
    pt.unshare(stable_data);
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
