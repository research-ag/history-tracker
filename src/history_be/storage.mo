import Iter "mo:new-base/Iter";
import List "mo:new-base/List";
import Map "mo:new-base/pure/Map";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Prim "mo:prim";
import Region "mo:base/Region";

import StableLogLists "mo:stable-log-lists";
import Enumeration "mo:stable-trie/Enumeration";
import PT "mo:promtracker";

import StableOrderedSet "models/stable_ordered_set";
import History "history";
import Metadata "history/metadata";
import ExtendedChange "history/extended_change";
import IC "history/ic";

import PB "utils/principal_blob";

module {

  public type StableDataV1 = {
    // A list of history entries
    historyStorage : List.List<History.History>;
    // Changes lists. List index == history index in the storage
    changes : StableLogLists.StableLogLists;
    // Maps the canister id to the history instance index in the storage.
    storageMap : ?Enumeration.StableData;
    // Global storage of principals, which are presented in changes list. In the records we store only index of the entry in the ordered set
    principalsSet : ?Enumeration.StableData;
    // Global storage of module hashes, which are presented in changes list. In the history items we store only index of the entry in the ordered set
    hashesSet : ?Enumeration.StableData;
    // A storage for metadata
    metadataMap : Map.Map<Nat, Metadata.Metadata>;
  };

  public func defaultStableDataV1() : StableDataV1 = {
    historyStorage = List.empty();
    changes = StableLogLists.new();
    storageMap = null;
    principalsSet = null;
    hashesSet = null;
    metadataMap = Map.empty();
  };

  public class Storage(data : StableDataV1) {

    private let historyStorage = data.historyStorage;
    private let changes = data.changes;
    private var storageMap : StableOrderedSet.StableOrderedSet<Principal> = StableOrderedSet.StableOrderedSet<Principal>(32, PB.toBlob, PB.toPrincipal);
    private var principalsSet : StableOrderedSet.StableOrderedSet<Principal> = StableOrderedSet.StableOrderedSet<Principal>(32, PB.toBlob, PB.toPrincipal);
    private var hashesSet : StableOrderedSet.StableOrderedSet<Blob> = StableOrderedSet.StableOrderedSet<Blob>(32, func x = x, func x = ?x);
    private var metadataMap : Map.Map<Nat, Metadata.Metadata> = data.metadataMap;

    switch (data.storageMap) {
      case (?d) storageMap.unshare(d);
      case (null) {};
    };
    switch (data.principalsSet) {
      case (?d) principalsSet.unshare(d);
      case (null) {};
    };
    switch (data.hashesSet) {
      case (?d) hashesSet.unshare(d);
      case (null) {};
    };

    public func size() : Nat = List.size(historyStorage);

    public func isCanisterTracked(canisterId : Principal) : Bool = storageMap.has(canisterId);

    public func canisterId(canisterIdx : Nat) : ?Principal = storageMap.get(canisterIdx);
    public func canisterIndex(canisterId : Principal) : ?Nat = storageMap.indexOf(canisterId);

    public func get(canisterIdx : Nat) : History.History = List.get(historyStorage, canisterIdx);

    public func insertCanister(canisterId : Principal, history : History.History) : Nat {
      let id = List.size(historyStorage);
      let (mapIndex, added) = storageMap.put(canisterId);
      if (not added) {
        Prim.trap("Error while inserting canister to storage: already exists");
      };
      if (mapIndex != id) {
        Prim.trap("Error while inserting canister to storage: map index is " # debug_show mapIndex # " while expected " # debug_show id);
      };
      while (changes.listsAmount <= id) {
        ignore StableLogLists.allocateList(changes);
      };
      List.add(historyStorage, history);
      id;
    };

    public func readChanges(canisterIdx : Nat) : [ExtendedChange.ExtendedChange] {
      StableLogLists.values(changes, canisterIdx)
      |> Iter.map<Blob, ?ExtendedChange.ExtendedChange>(
        _,
        func(b) = ExtendedChange.deserializeExtendedChange(
          b,
          func(index : Nat) : Principal {
            let ?p = principalsSet.get(index) else Prim.trap("mapPrincipal failed!");
            p;
          },
          func(index : Nat) : Blob {
            let ?p = hashesSet.get(index) else Prim.trap("mapHash failed!");
            p;
          },
        ),
      )
      |> Iter.filter<?ExtendedChange.ExtendedChange>(
        _,
        func(x) {
          if (Option.isNull(x)) {
            Prim.debugPrint("[WARN] Could not deserialize history item in list #" # (debug_show canisterIdx));
            return false;
          };
          true;
        },
      )
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
      canisterIdx : Nat,
      latestChangeTimestamp : Nat64,
      info : IC.CanisterInfoResponse,
    ) : Nat64 {
      var ret : Nat64 = latestChangeTimestamp;
      let changes_size = info.recent_changes.size();
      var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;
      for (change in info.recent_changes.vals()) {
        if (change.timestamp_nanos > latestChangeTimestamp) {
          StableLogLists.append(
            changes,
            canisterIdx,
            ExtendedChange.serializeExtendedChange(
              { change with change_index = cur_change_index },
              func(p : Principal) : Nat {
                let (idx, _) = principalsSet.put(p);
                idx;
              },
              func(hash : Blob) : Nat {
                let (idx, _) = hashesSet.put(hash);
                idx;
              },
            ),
          );
          ret := change.timestamp_nanos;
        };
        cur_change_index += 1;
      };
      ret;
    };

    public func readMetadata(canisterIdx : Nat) : ?Metadata.Metadata = Map.get(metadataMap, Nat.compare, canisterIdx);

    public func updateMetadata(canisterIdx : Nat, name : ?Text, description : ?Text) : () {
      let metadata = switch (Map.get(metadataMap, Nat.compare, canisterIdx)) {
        case (?md) md;
        case (null) {
          let md = Metadata.new();
          metadataMap := Map.add(metadataMap, Nat.compare, canisterIdx, md);
          md;
        };
      };
      switch (name) {
        case null {};
        case (?value) metadata.name := value;
      };
      switch (description) {
        case null {};
        case (?value) metadata.description := value;
      };
      metadata.latest_update_timestamp := Prim.time();
    };

    public func registerMetrics(pt : PT.PromTracker) {
      func getEnumerationPagesAllocated(data : Enumeration.StableData) : Nat {
        Nat64.toNat(Region.size(data.nodes.region) + Region.size(data.leaves.region));
      };

      ignore pt.addPullValue("stable_records_total", "structure=\"changes_lists\"", func() = StableLogLists.totalSize(changes));
      ignore pt.addPullValue("stable_pages_allocated", "structure=\"changes_lists\"", func() = Nat64.toNat(Region.size(changes.data) + Region.size(changes.indexTable)));

      ignore pt.addPullValue("stable_records_total", "structure=\"storage_map\"", func() = storageMap.size());
      ignore pt.addPullValue("stable_pages_allocated", "structure=\"storage_map\"", func() = getEnumerationPagesAllocated(storageMap.share()));

      ignore pt.addPullValue("stable_records_total", "structure=\"principals_set\"", func() = principalsSet.size());
      ignore pt.addPullValue("stable_pages_allocated", "structure=\"principals_set\"", func() = getEnumerationPagesAllocated(principalsSet.share()));

      ignore pt.addPullValue("stable_records_total", "structure=\"hashes_set\"", func() = hashesSet.size());
      ignore pt.addPullValue("stable_pages_allocated", "structure=\"hashes_set\"", func() = getEnumerationPagesAllocated(hashesSet.share()));

    };

    public func share() : StableDataV1 = {
      historyStorage;
      changes;
      storageMap = ?storageMap.share();
      principalsSet = ?principalsSet.share();
      hashesSet = ?hashesSet.share();
      metadataMap;
    };

  };

};
