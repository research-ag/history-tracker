import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Prim "mo:prim";

import ExtendedChange "extended_change";

import IC "ic";
import StableOrderedSet "../models/stable_ordered_set";
import StableBucketList "../models/stable_bucket_list";

module History {

  public type History = {
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var timestamp_nanos : Nat64; // latest sync timestamp
    var sync_version : Nat; // sync version (number of syncs)
  };

  public func new() : History = {
    var latest_change_timestamp = 0;
    var total_num_changes = 0;
    var timestamp_nanos = 0;
    var sync_version = 0;
  };

  public type CanisterChangesResponse = {
    changes : [ExtendedChange.ExtendedChange];
    total_num_changes : Nat64;
    timestamp_nanos : Nat64;
    sync_version : Nat;
  };

  let ic = actor "aaaaa-aa" : IC.Management;

  public func sync(
    canister_id : Principal,
    history : History,
    historyIndex : Nat,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
    changes : StableBucketList.StableBucketList,
  ) : async* IC.CanisterInfoResponse {
    // no try-catch => async errors are passed through to the caller
    let info = await ic.canister_info({
      canister_id = canister_id;
      num_requested_changes = ?20;
    });
    let changes_size = info.recent_changes.size();
    var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;

    // Merge untracked changes with already saved ones
    for (change in info.recent_changes.vals()) {
      if (change.timestamp_nanos > history.latest_change_timestamp) {
        StableBucketList.append(
          changes,
          Nat64.fromNat(historyIndex),
          ExtendedChange.serializeExtendedChange({ change with change_index = cur_change_index }, principalsSet, hashesSet),
        );
        history.latest_change_timestamp := change.timestamp_nanos;
      };
      cur_change_index += 1;
    };

    history.total_num_changes := info.total_num_changes;
    history.timestamp_nanos := Prim.time();
    history.sync_version += 1;
    info;
  };

  public func canister_changes(
    history : History,
    historyIndex : Nat,
    principalsSet : StableOrderedSet.StableOrderedSet<Principal>,
    hashesSet : StableOrderedSet.StableOrderedSet<Blob>,
    changes : StableBucketList.StableBucketList,
  ) : CanisterChangesResponse = {

    changes = StableBucketList.values(changes, Nat64.fromNat(historyIndex))
    |> Iter.map<Blob, ?ExtendedChange.ExtendedChange>(_, func(b) = ExtendedChange.deserializeExtendedChange(b, principalsSet, hashesSet))
    |> Iter.filter<?ExtendedChange.ExtendedChange>(_, func(x) = Option.isSome(x))
    |> Iter.map<?ExtendedChange.ExtendedChange, ExtendedChange.ExtendedChange>(
      _,
      func(xopt) {
        let ?x = xopt else Prim.trap("Can never happen");
        x;
      },
    )
    |> Iter.toArray(_);

    total_num_changes = history.total_num_changes;
    timestamp_nanos = history.timestamp_nanos;
    sync_version = history.sync_version;
  };
};
