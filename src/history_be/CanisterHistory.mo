import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import List "mo:new-base/List";
import Prim "mo:prim";

import IC "ic";
import StableOrderedSet "stable_ordered_set";

module {

  public type ExtendedChange = IC.CanisterChange and {
    change_index : Nat;
  };

  public type StableExtendedChange = {
    change_index : Nat;
    // IC.CanisterChange below  with mapped principals and module hashes to indexes (Nat)
    timestamp_nanos : Nat64;
    canister_version : Nat64;
    origin : {
      #from_user : {
        user_id_index : Nat;
      };
      #from_canister : {
        canister_id_index : Nat;
        canister_version : ?Nat64;
      };
    };
    details : {
      #creation : {
        controller_indexes : [Nat];
      };
      #code_deployment : {
        mode : IC.CanisterInstallMode;
        module_hash_index : Nat;
      };
      #controllers_change : {
        controller_indexes : [Nat];
      };
      #code_uninstall;
      #load_snapshot : IC.SnapshotRecord;
    };
  };

  func wrapExtendedChange(
    v : ExtendedChange,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
  ) : StableExtendedChange {
    func mapPrincipal(p : Principal) : Nat {
      let (idx, _) = principalsSet.put(p);
      idx;
    };
    func mapHash(hash : Blob) : Nat {
      let (idx, _) = hashesSet.put(hash);
      idx;
    };
    return {
      v with
      origin = switch (v.origin) {
        case (#from_user { user_id }) #from_user({
          user_id_index = mapPrincipal(user_id);
        });
        case (#from_canister x) #from_canister({
          canister_id_index = mapPrincipal(x.canister_id);
          canister_version = x.canister_version;
        });
      };
      details = switch (v.details) {
        case (#creation x) #creation({
          controller_indexes = Array.map(x.controllers, mapPrincipal);
        });
        case (#controllers_change x) #controllers_change({
          controller_indexes = Array.map(x.controllers, mapPrincipal);
        });
        case (#code_deployment x) #code_deployment({
          mode = x.mode;
          module_hash_index = mapHash(x.module_hash);
        });
        case (#code_uninstall x) #code_uninstall(x);
        case (#load_snapshot x) #load_snapshot(x);
      };
    };
  };

  func unwrapExtendedChange(
    v : StableExtendedChange,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
  ) : ExtendedChange {
    func mapPrincipal(index : Nat) : Principal {
      let ?p = principalsSet.get(index) else Prim.trap("mapPrincipal failed!");
      p;
    };
    func mapHash(index : Nat) : Blob {
      let ?p = hashesSet.get(index) else Prim.trap("mapHash failed!");
      p;
    };
    return {
      v with
      origin = switch (v.origin) {
        case (#from_user { user_id_index }) #from_user({
          user_id = mapPrincipal(user_id_index);
        });
        case (#from_canister x) #from_canister({
          canister_id = mapPrincipal(x.canister_id_index);
          canister_version = x.canister_version;
        });
      };
      details = switch (v.details) {
        case (#creation x) #creation({
          controllers = Array.map(x.controller_indexes, mapPrincipal);
        });
        case (#controllers_change x) #controllers_change({
          controllers = Array.map(x.controller_indexes, mapPrincipal);
        });
        case (#code_deployment x) #code_deployment({
          mode = x.mode;
          module_hash = mapHash(x.module_hash_index);
        });
        case (#code_uninstall x) #code_uninstall(x);
        case (#load_snapshot x) #load_snapshot(x);
      };
    };
  };

  public type Metadata = {
    name : Text;
    description : Text;
    latest_update_timestamp : Nat64;
  };

  public type History = {
    changes : List.List<StableExtendedChange>; // all tracked changes
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var timestamp_nanos : Nat64; // latest sync timestamp
    var sync_version : Nat; // sync version (number of syncs)
    var metadata : {
      var name : Text;
      var description : Text;
      var latest_update_timestamp : Nat64;
    };
    canister_id : Principal;
  };

  public type CanisterChangesResponse = {
    changes : [ExtendedChange];
    total_num_changes : Nat64;
    timestamp_nanos : Nat64;
    sync_version : Nat;
  };

  public func new(canister_id : Principal) : History = {
    changes = List.empty<StableExtendedChange>();
    var latest_change_timestamp = 0;
    var total_num_changes = 0;
    var timestamp_nanos = 0;
    var sync_version = 0;
    var metadata = {
      var name = "";
      var description = "";
      var latest_update_timestamp = 0;
    };
    canister_id;
  };

  let ic = actor "aaaaa-aa" : IC.Management;
  public class API(
    state : History,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
  ) {

    public func sync() : async* IC.CanisterInfoResponse {
      // no try-catch => async errors are passed through to the caller
      let info = await ic.canister_info({
        canister_id = state.canister_id;
        num_requested_changes = ?20;
      });
      let changes_size = info.recent_changes.size();
      var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;

      // Merge untracked changes with already saved ones
      for (change in info.recent_changes.vals()) {
        if (change.timestamp_nanos > state.latest_change_timestamp) {
          List.add(
            state.changes,
            wrapExtendedChange({ change with change_index = cur_change_index }, principalsSet, hashesSet),
          );
          state.latest_change_timestamp := change.timestamp_nanos;
        };
        cur_change_index += 1;
      };

      state.total_num_changes := info.total_num_changes;
      state.timestamp_nanos := Prim.time();
      state.sync_version += 1;
      info;
    };

    public func canister_changes() : CanisterChangesResponse = {
      changes = List.toArray(state.changes)
      |> Array.map<StableExtendedChange, ExtendedChange>(_, func x = unwrapExtendedChange(x, principalsSet, hashesSet));
      total_num_changes = state.total_num_changes;
      timestamp_nanos = state.timestamp_nanos;
      sync_version = state.sync_version;
    };

    public func metadata() : Metadata {
      {
        name = state.metadata.name;
        description = state.metadata.description;
        latest_update_timestamp = state.metadata.latest_update_timestamp;
      };
    };

    public func update_metadata(caller : Principal, name : ?Text, description : ?Text) : async* Bool {
      if (not Principal.isController(caller)) return false;

      switch (name) {
        case null {};
        case (?value) {
          state.metadata.name := value;
        };
      };

      switch (description) {
        case null {};
        case (?value) {
          state.metadata.description := value;
        };
      };

      state.metadata.latest_update_timestamp := Prim.time();
      return true;
    };
  };
};
