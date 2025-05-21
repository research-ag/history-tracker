import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Nat "mo:base/Nat";
import Timer "mo:base/Timer";
import Result "mo:base/Result";
import Vector "mo:vector";
import Buffer "mo:base/Buffer";

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

  /// Number of canisters that are synchronized per iteration.
  let canisters_num_to_sync = 5;

  type StableData = RBTree.Tree<Principal, Nat>; // history_storage_map

  /// Storage for all the canister histories.
  stable let history_storage = Vector.new<CanisterHistory.History>();

  /// Maps the canister id to the history instance index in the storage.
  let history_storage_map = RBTree.RBTree<Principal, Nat>(Principal.compare);

  stable var stable_data : StableData = (/* convert_hs_to_stable(history_storage), */ history_storage_map.share());

  public query func is_canister_tracked(canister_id : Principal) : async Bool {
    history_storage_map.get(canister_id) != null;
  };

  public func track(canister_id : Principal) : async Result.Result<(), Errors.Track> {
    if (history_storage_map.get(canister_id) != null) return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
    let new_canister_history = CanisterHistory.new(canister_id);
    ignore await* CanisterHistory.API(new_canister_history).sync();
    Vector.add(history_storage, new_canister_history);
    let last_index : Nat = Vector.size(history_storage) - 1;
    history_storage_map.put(canister_id, last_index);
    #ok();
  };

  public query func canister_changes(canister_id : Principal) : async ?CanisterHistory.CanisterChangesResponse {
    switch (history_storage_map.get(canister_id)) {
      case (null) null;
      case (?index) {
        let history = Vector.get(history_storage, index);
        ?CanisterHistory.API(history).canister_changes();
      };
    };
  };

  public query func canister_state(canister_id : Principal) : async ?CanisterHistory.CanisterStateResponse {
    switch (history_storage_map.get(canister_id)) {
      case (null) null;
      case (?index) {
        let history = Vector.get(history_storage, index);
        ?CanisterHistory.API(history).canister_state();
      };
    };
  };

  public query func metadata(canister_id : Principal) : async ?CanisterHistory.Metadata {
    switch (history_storage_map.get(canister_id)) {
      case (null) null;
      case (?index) {
        let history = Vector.get(history_storage, index);
        ?CanisterHistory.API(history).metadata();
      };
    };
  };

  public shared ({ caller }) func update_metadata(canister_id : Principal, name : ?Text, description : ?Text) : async Result.Result<(), Errors.UpdateMetadata> {
    switch (history_storage_map.get(canister_id)) {
      case (null) return #err(#CanisterNotTracked({ message = "The canister is not tracked." }));
      case (?index) {
        let history = Vector.get(history_storage, index);
        await* CanisterHistory.API(history).update_metadata(caller, name, description);
        #ok();
      };
    };
  };

  transient var open_calls = 0; // must be 0 when canister was stopped
  transient var trapsDetected = 0;

  var sync_pos = 0;

  func trigger_sync() : async* () {
    let N = Vector.size(history_storage);
    let sync_num = Nat.min(canisters_num_to_sync, N);
    if (open_calls >= sync_num) return;

    let new_calls : Nat = sync_num - open_calls;
    let calls = Buffer.Buffer<Concurrent.Item>(new_calls);

    var ctr = 0;
    while (ctr < new_calls) {
      let history = Vector.get(history_storage, sync_pos);
      if (not history.sync_ongoing) {
        let item : Concurrent.Item = {
          call_arg = CanisterHistory.API(history).sync_call_arg();
          register_call = func() {
            history.sync_ongoing := true;
            open_calls += 1;
          };
          process_response = func(info) {
            CanisterHistory.API(history).sync_call_process_response(info);
            history.sync_ongoing := false;
            open_calls -= 1;
          };
          process_error = func(_) {
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
      func(i) { trapsDetected += 1 }, // trap_cb
    );
  };

  ignore Timer.recurringTimer<system>(
    #seconds 60,
    func() : async () { await* trigger_sync() },
  );

  system func preupgrade() {
    stable_data := history_storage_map.share();
  };

  system func postupgrade() {
    history_storage_map.unshare(stable_data);
  };
};
