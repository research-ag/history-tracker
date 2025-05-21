import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Map "mo:new-base/pure/Map";
import List "mo:new-base/List";

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
    await* CanisterHistory.API(h).update_metadata(caller, name, description);
    #ok();
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

};
