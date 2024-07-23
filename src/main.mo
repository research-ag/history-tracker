import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import RBTree "mo:base/RBTree";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import Prim "mo:prim";

import IC "ic"

actor class HistoryTracker(canisterId_ : Principal) = self {
  type InternalState = {
    changes : RBTree.RBTree<Nat64, IC.CanisterChange>; // all tracked changes
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var module_hash : ?[Nat8]; // current module hash
    var controllers : [Principal]; // current controllers
    var timestamp_nanos : Nat64; // latest sync timestamp
  };

  type StableInternalState = {
    changes : RBTree.Tree<Nat64, IC.CanisterChange>;
    latest_change_timestamp : Nat64;
    total_num_changes : Nat64;
    module_hash : ?[Nat8];
    controllers : [Principal];
    timestamp_nanos : Nat64;
  };

  type CanisterChangesResponse = {
    changes : [IC.CanisterChange];
    total_num_changes : Nat64;
    timestamp_nanos : Nat64;
  };

  type CanisterStateResponse = {
    module_hash : ?[Nat8];
    controllers : [Principal];
    timestamp_nanos : Nat64;
  };

  let internal_state : InternalState = {
    changes = RBTree.RBTree<Nat64, IC.CanisterChange>(Nat64.compare);
    var latest_change_timestamp = 0;
    var total_num_changes = 0;
    var module_hash = null;
    var controllers = [];
    var timestamp_nanos = 0;
  };

  func map_to_stable(state : InternalState) : StableInternalState {
    state
    |> {
      changes = _.changes.share();
      latest_change_timestamp = _.latest_change_timestamp;
      total_num_changes = _.total_num_changes;
      module_hash = _.module_hash;
      controllers = _.controllers;
      timestamp_nanos = _.timestamp_nanos;
    };
  };

  var stable_internal_state : StableInternalState = map_to_stable(internal_state);

  let ic = actor "aaaaa-aa" : IC.Management;

  var sync_ongoing = false;

  func sync_() : async* () {
    if (sync_ongoing) throw Error.reject("Synchronization is already in progress.");

    sync_ongoing := true;

    let info = await ic.canister_info({
      canister_id = canisterId_;
      num_requested_changes = ?Nat64.fromNat(20);
    });

    // Merge untracked changes with already saved ones
    for (change in Iter.fromArray(info.recent_changes)) {
      if (change.timestamp_nanos > internal_state.latest_change_timestamp) {
        internal_state.changes.put(change.timestamp_nanos, change);
        internal_state.latest_change_timestamp := change.timestamp_nanos;
      };
    };

    internal_state.total_num_changes := info.total_num_changes;
    internal_state.module_hash := info.module_hash;
    internal_state.controllers := info.controllers;
    internal_state.timestamp_nanos := Prim.time();

    sync_ongoing := false;
  };

  // Timer for state auto-synchronization
  ignore Timer.recurringTimer<system>(
    #seconds 60,
    func() : async () {
      await* sync_();
    },
  );

  public func sync() : async () {
    await* sync_();
  };

  public func canister_changes() : async CanisterChangesResponse {
    internal_state.changes.entries()
    |> Iter.map<(Nat64, IC.CanisterChange), IC.CanisterChange>(_, func((_, v)) = v)
    |> Iter.toArray(_)
    |> {
      changes = _;
      total_num_changes = internal_state.total_num_changes;
      timestamp_nanos = internal_state.timestamp_nanos;
    };
  };

  public func canister_state() : async CanisterStateResponse {
    {
      module_hash = internal_state.module_hash;
      controllers = internal_state.controllers;
      timestamp_nanos = internal_state.timestamp_nanos;
    };
  };

  public func canister_id() : async Principal {
    canisterId_;
  };

  system func preupgrade() {
    stable_internal_state := map_to_stable(internal_state);
  };

  system func postupgrade() {
    internal_state.changes.unshare(stable_internal_state.changes);
    internal_state.latest_change_timestamp := stable_internal_state.latest_change_timestamp;
    internal_state.total_num_changes := stable_internal_state.total_num_changes;
    internal_state.module_hash := stable_internal_state.module_hash;
    internal_state.controllers := stable_internal_state.controllers;
    internal_state.timestamp_nanos := stable_internal_state.timestamp_nanos;
  };
};
