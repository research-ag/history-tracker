import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Prim "mo:prim";

import IC "ic"

module {
  type ExtendedChange = IC.CanisterChange and {
    change_index : Nat;
  };

  type CanisterMetadata = {
    var name : Text;
    var description : Text;
    var latest_update_timestamp : Nat64;
  };

  public type SharedCanisterMetadata = {
    name : Text;
    description : Text;
    latest_update_timestamp : Nat64;
  };

  type InternalState = {
    changes : RBTree.RBTree<Nat, ExtendedChange>; // all tracked changes
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var module_hash : ?[Nat8]; // current module hash
    var controllers : [Principal]; // current controllers
    var timestamp_nanos : Nat64; // latest sync timestamp
    var sync_version : Nat; // sync version (nubmer of syncs)
    var metadata : CanisterMetadata;
  };

  public type StableData = {
    changes : RBTree.Tree<Nat, ExtendedChange>;
    latest_change_timestamp : Nat64;
    total_num_changes : Nat64;
    module_hash : ?[Nat8];
    controllers : [Principal];
    timestamp_nanos : Nat64;
    sync_version : Nat;
    metadata : SharedCanisterMetadata;
    // * for remembering associated canister id
    canister_id : Principal;
  };

  public type CanisterChangesResponse = {
    changes : [ExtendedChange];
    total_num_changes : Nat64;
    timestamp_nanos : Nat64;
    sync_version : Nat;
  };

  public type CanisterStateResponse = {
    module_hash : ?[Nat8];
    controllers : [Principal];
    timestamp_nanos : Nat64;
    sync_version : Nat;
  };

  public func fromStableData(data : StableData) : CanisterHistory {
    let history = CanisterHistory(data.canister_id);
    history.unshare(data);
    history;
  };

  public class CanisterHistory(canister_id : Principal) {

    let internal_state : InternalState = {
      changes = RBTree.RBTree<Nat, ExtendedChange>(Nat.compare);
      var latest_change_timestamp = 0;
      var total_num_changes = 0;
      var module_hash = null;
      var controllers = [];
      var timestamp_nanos = 0;
      var sync_version = 0;
      var metadata = {
        var name = "";
        var description = "";
        var latest_update_timestamp = 0;
      };
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

      let changes_size = info.recent_changes.size();
      var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;

      // Merge untracked changes with already saved ones
      for (change in Iter.fromArray(info.recent_changes)) {
        if (change.timestamp_nanos > internal_state.latest_change_timestamp) {
          internal_state.changes.put(
            cur_change_index,
            {
              change with
              change_index = cur_change_index;
            },
          );
          internal_state.latest_change_timestamp := change.timestamp_nanos;
        };
        cur_change_index += 1;
      };

      internal_state.total_num_changes := info.total_num_changes;
      internal_state.module_hash := info.module_hash;
      internal_state.controllers := info.controllers;
      internal_state.timestamp_nanos := Prim.time();
      internal_state.sync_version += 1;

      sync_ongoing := false;
    };

    public func canister_changes() : CanisterChangesResponse {
      internal_state.changes.entries()
      |> Iter.map<(Nat, ExtendedChange), ExtendedChange>(_, func((_, v)) = v)
      |> Iter.toArray(_)
      |> {
        changes = _;
        total_num_changes = internal_state.total_num_changes;
        timestamp_nanos = internal_state.timestamp_nanos;
        sync_version = internal_state.sync_version;
      };
    };

    public func canister_state() : CanisterStateResponse {
      {
        module_hash = internal_state.module_hash;
        controllers = internal_state.controllers;
        timestamp_nanos = internal_state.timestamp_nanos;
        sync_version = internal_state.sync_version;
      };
    };

    public func metadata() : SharedCanisterMetadata {
      {
        name = internal_state.metadata.name;
        description = internal_state.metadata.description;
        latest_update_timestamp = internal_state.metadata.latest_update_timestamp;
      };
    };

    public func update_metadata(caller : Principal, name : ?Text, description : ?Text) : async* () {
      let info = try {
        await ic.canister_info({
          canister_id;
          num_requested_changes = ?Nat64.fromNat(0);
        });
      } catch (_) throw Error.reject("canister_info error.");

      let is_controller = Array.find<Principal>(info.controllers, func c = c == caller) != null;
      if (not is_controller) throw Error.reject("Access denied.");

      switch (name) {
        case null {};
        case (?value) {
          internal_state.metadata.name := value;
        };
      };

      switch (description) {
        case null {};
        case (?value) {
          internal_state.metadata.description := value;
        };
      };

      internal_state.metadata.latest_update_timestamp := Prim.time();
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
        metadata = {
          name = _.metadata.name;
          description = _.metadata.description;
          latest_update_timestamp = _.metadata.latest_update_timestamp;
        };
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
      internal_state.metadata := {
        var name = data.metadata.name;
        var description = data.metadata.description;
        var latest_update_timestamp = data.metadata.latest_update_timestamp;
      };
    };
  };
};
