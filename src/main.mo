import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import Deque "mo:base/Deque";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Timer "mo:base/Timer";
import Vector "mo:vector/Class";
import Vec "mo:vector";

import CanisterHistory "CanisterHistory";

actor class HistoryTracker() = self {

  /// Number of canisters that are synchronized per iteration.
  let canisters_num_to_sync = 5;

  type StableData = (
    [CanisterHistory.StableData], // history_storage
    RBTree.Tree<Principal, Nat>, // history_storage_map
    Deque.Deque<Nat>, // sync_queue
  );

  /// Converts the history storage to stable type.
  func convert_hs_to_stable(data : Vector.Vector<CanisterHistory.CanisterHistory>) : [CanisterHistory.StableData] {
    data.vals()
    |> Iter.map<CanisterHistory.CanisterHistory, CanisterHistory.StableData>(_, func(v) = v.share())
    |> Iter.toArray(_);
  };

  /// Storage for all the canister histories.
  let history_storage = Vector.Vector<CanisterHistory.CanisterHistory>();

  /// Maps the canister id to the history instance index in the storage.
  let history_storage_map = RBTree.RBTree<Principal, Nat>(Principal.compare);

  /// Contains indexes of the canister histories in the order in which they will sync.
  var sync_queue = Deque.empty<Nat>();

  stable var stable_data : StableData = (convert_hs_to_stable(history_storage), history_storage_map.share(), sync_queue);

  public func track(canister_id : Principal) : async () {
    if (history_storage_map.get(canister_id) != null) throw Error.reject("The canister is already tracked.");
    let new_canister_history = CanisterHistory.CanisterHistory(canister_id);
    await* new_canister_history.sync();
    history_storage.add(new_canister_history);
    let last_index : Nat = history_storage.size() - 1;
    history_storage_map.put(canister_id, last_index);
    sync_queue := Deque.pushBack(sync_queue, last_index);
  };

  public func canister_changes(canister_id : Principal) : async CanisterHistory.CanisterChangesResponse {
    switch (history_storage_map.get(canister_id)) {
      case (null) throw Error.reject("The canister is not tracked.");
      case (?index) {
        let history = history_storage.get(index);
        history.canister_changes();
      };
    };
  };

  public func canister_state(canister_id : Principal) : async CanisterHistory.CanisterStateResponse {
    switch (history_storage_map.get(canister_id)) {
      case (null) throw Error.reject("The canister is not tracked.");
      case (?index) {
        let history = history_storage.get(index);
        history.canister_state();
      };
    };
  };

  func trigger_sync() : async* () {
    var ctr = 0;
    let sync_num = Nat.min(canisters_num_to_sync, history_storage.size());
    while (ctr < sync_num) {
      let (index, queue_after_pop) = switch (Deque.popFront(sync_queue)) {
        case (?v) v;
        case (null) Debug.trap("Internal error.");
      };
      sync_queue := queue_after_pop;
      let history = history_storage.get(index);
      try { ignore async { await* history.sync() } } catch (_) {};
      sync_queue := Deque.pushBack(sync_queue, index);
      ctr += 1;
    };
  };

  ignore Timer.recurringTimer<system>(
    #seconds 60,
    func() : async () { await* trigger_sync() },
  );

  system func preupgrade() {
    stable_data := (convert_hs_to_stable(history_storage), history_storage_map.share(), sync_queue);
  };

  system func postupgrade() {
    history_storage.unshare(
      (stable_data.0)
      |> Iter.fromArray(_)
      |> Iter.map<CanisterHistory.StableData, CanisterHistory.CanisterHistory>(
        _,
        func(v) = CanisterHistory.fromStableData(v),
      )
      |> Vec.fromIter(_)
    );

    history_storage_map.unshare(stable_data.1);
    sync_queue := stable_data.2;
  };
};
