import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import Prim "mo:prim";

import IC "ic"

module {

  type InternalState = {
    changes : RBTree.RBTree<Nat64, IC.CanisterChange>; // all tracked changes
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var module_hash : ?[Nat8]; // current module hash
    var controllers : [Principal]; // current controllers
    var timestamp_nanos : Nat64; // latest sync timestamp
    var sync_version : Nat; // sync version (nubmer of syncs)
    var corruption_timestamp : ?Nat64; // first corruption detection timestamp
  };

  public type StableData = {
    changes : RBTree.Tree<Nat64, IC.CanisterChange>;
    latest_change_timestamp : Nat64;
    total_num_changes : Nat64;
    module_hash : ?[Nat8];
    controllers : [Principal];
    timestamp_nanos : Nat64;
    sync_version : Nat;
    corruption_timestamp : ?Nat64;
    // * for remembering associated canister id
    canister_id : Principal;
  };

  public type CanisterChangesResponse = {
    changes : [IC.CanisterChange];
    total_num_changes : Nat64;
    timestamp_nanos : Nat64;
    sync_version : Nat;
    corruption_timestamp : ?Nat64;
  };

  public type CanisterStateResponse = {
    module_hash : ?[Nat8];
    controllers : [Principal];
    timestamp_nanos : Nat64;
    sync_version : Nat;
    corruption_timestamp : ?Nat64;
  };

  public func fromStableData(data : StableData) : CanisterHistory {
    let history = CanisterHistory(data.canister_id);
    history.unshare(data);
    history;
  };

  public class CanisterHistory(canister_id : Principal) {

    let internal_state : InternalState = {
      changes = RBTree.RBTree<Nat64, IC.CanisterChange>(Nat64.compare);
      var latest_change_timestamp = 0;
      var total_num_changes = 0;
      var module_hash = null;
      var controllers = [];
      var timestamp_nanos = 0;
      var sync_version = 0;
      var corruption_timestamp = ?0;
    };

    let ic = actor "aaaaa-aa" : IC.Management;

    var sync_ongoing = false;

    public func sync() : async* () {
      if (sync_ongoing) throw Error.reject("Synchronization is already in progress.");

      sync_ongoing := true;

      let info = await ic.canister_info({
        canister_id;
        num_requested_changes = ?Nat64.fromNat(20);
      });

      // Merge untracked changes with already saved ones
      for (change in Iter.fromArray(info.recent_changes)) {
        if (change.timestamp_nanos > internal_state.latest_change_timestamp) {
          internal_state.changes.put(change.timestamp_nanos, change);
          internal_state.latest_change_timestamp := change.timestamp_nanos;
        };
      };

      // The history is corrupted in case the contoller makes more than 20 changes between sync iterations.
      // We can fetch only the 20 latest changes from the management canister.
      // So such frequent changes can be an opportunity for abuse.
      let is_corrupted = internal_state |> _.total_num_changes != 0 and (_.total_num_changes + 20 < info.total_num_changes);

      internal_state.total_num_changes := info.total_num_changes;
      internal_state.module_hash := info.module_hash;
      internal_state.controllers := info.controllers;
      internal_state.timestamp_nanos := Prim.time();
      internal_state.sync_version += 1;

      if (is_corrupted and internal_state.corruption_timestamp == null) internal_state.corruption_timestamp := ?Prim.time();

      sync_ongoing := false;
    };

    public func canister_changes() : CanisterChangesResponse {
      internal_state.changes.entries()
      |> Iter.map<(Nat64, IC.CanisterChange), IC.CanisterChange>(_, func((_, v)) = v)
      |> Iter.toArray(_)
      |> {
        changes = _;
        total_num_changes = internal_state.total_num_changes;
        timestamp_nanos = internal_state.timestamp_nanos;
        sync_version = internal_state.sync_version;
        corruption_timestamp = internal_state.corruption_timestamp;
      };
    };

    public func canister_state() : CanisterStateResponse {
      {
        module_hash = internal_state.module_hash;
        controllers = internal_state.controllers;
        timestamp_nanos = internal_state.timestamp_nanos;
        sync_version = internal_state.sync_version;
        corruption_timestamp = internal_state.corruption_timestamp;
      };
    };

    public func share() : StableData {
      internal_state
      |> {
        changes = _.changes.share();
        latest_change_timestamp = _.latest_change_timestamp;
        total_num_changes = _.total_num_changes;
        module_hash = _.module_hash;
        controllers = _.controllers;
        timestamp_nanos = _.timestamp_nanos;
        sync_version = _.sync_version;
        corruption_timestamp = _.corruption_timestamp;
        canister_id;
      };
    };

    public func unshare(data : StableData) {
      internal_state.changes.unshare(data.changes);
      internal_state.latest_change_timestamp := data.latest_change_timestamp;
      internal_state.total_num_changes := data.total_num_changes;
      internal_state.module_hash := data.module_hash;
      internal_state.controllers := data.controllers;
      internal_state.timestamp_nanos := data.timestamp_nanos;
      internal_state.sync_version := data.sync_version;
      internal_state.corruption_timestamp := data.corruption_timestamp;
    };
  };
};
