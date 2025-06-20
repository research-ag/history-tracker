import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Prim "mo:prim";

import IC "ic";
import StableOrderedSet "../models/stable_ordered_set";
import StableBucketList "../models/stable_bucket_list";

/// A module containing canister change data type and operations on it
module ExtendedChange {

  /// A change record which we receive from IC and expose
  public type ExtendedChange = IC.CanisterChange and {
    change_index : Nat;
  };

  /// A change record which we store in the memory
  private type StableExtendedChange = {
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

  private func serializeExtendedChange(
    v : ExtendedChange,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
  ) : Blob {
    func mapPrincipal(p : Principal) : Nat {
      let (idx, _) = principalsSet.put(p);
      idx;
    };
    func mapHash(hash : Blob) : Nat {
      let (idx, _) = hashesSet.put(hash);
      idx;
    };
    let change : StableExtendedChange = {
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
    to_candid (change);
  };

  private func deserializeExtendedChange(
    raw : Blob,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
  ) : ?ExtendedChange {
    let ?v : ?StableExtendedChange = from_candid (raw) else return null;

    func mapPrincipal(index : Nat) : Principal {
      let ?p = principalsSet.get(index) else Prim.trap("mapPrincipal failed!");
      p;
    };
    func mapHash(index : Nat) : Blob {
      let ?p = hashesSet.get(index) else Prim.trap("mapHash failed!");
      p;
    };

    ?{
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

  public func readChanges(
    historyIndex : Nat,
    changes : StableBucketList.StableBucketList,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
  ) : [ExtendedChange] {
    StableBucketList.values(changes, Nat64.fromNat(historyIndex))
    |> Iter.map<Blob, ?ExtendedChange.ExtendedChange>(_, func(b) = deserializeExtendedChange(b, principalsSet, hashesSet))
    |> Iter.filter<?ExtendedChange.ExtendedChange>(_, func(x) = Option.isSome(x))
    |> Iter.map<?ExtendedChange.ExtendedChange, ExtendedChange.ExtendedChange>(
      _,
      func(xopt) {
        let ?x = xopt else Prim.trap("Can never happen");
        x;
      },
    )
    |> Iter.toArray(_);
  };

  public func appendChanges(
    historyIndex : Nat,
    latestChangeTimestamp : Nat64,
    info : IC.CanisterInfoResponse,
    changes : StableBucketList.StableBucketList,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
  ) : Nat64 {
    var ret : Nat64 = latestChangeTimestamp;
    let changes_size = info.recent_changes.size();
    var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;
    for (change in info.recent_changes.vals()) {
      if (change.timestamp_nanos > latestChangeTimestamp) {
        StableBucketList.append(
          changes,
          Nat64.fromNat(historyIndex),
          serializeExtendedChange({ change with change_index = cur_change_index }, principalsSet, hashesSet),
        );
        ret := change.timestamp_nanos;
      };
      cur_change_index += 1;
    };
    ret;
  };

};
