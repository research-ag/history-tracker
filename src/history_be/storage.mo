import Array "mo:core/Array";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Map "mo:core/pure/Map";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import Option "mo:core/Option";
import Prim "mo:prim";
import Principal "mo:core/Principal";
import Region "mo:core/Region";

import LogLists "mo:stable-log-lists";
import Enumeration "mo:stable-trie/Enumeration";
import PT "mo:promtracker";
import { Heatmap } "mo:promtracker";

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
    changes : LogLists.LogLists;
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
    changes = LogLists.new();
    storageMap = null;
    principalsSet = null;
    hashesSet = null;
    metadataMap = Map.empty();
  };

  public class Storage(data : StableDataV1, changesAmountDistribution: Heatmap.Heatmap) {

    private let historyStorage = data.historyStorage;
    private let changes = data.changes;
    private let storageMap : StableOrderedSet.StableOrderedSet<Principal> = StableOrderedSet.StableOrderedSet<Principal>(10, Principal.toBlob, func x = ?Principal.fromBlob(x));
    private let principalsSet : StableOrderedSet.StableOrderedSet<Principal> = StableOrderedSet.StableOrderedSet<Principal>(30, PB.toBlob, PB.toPrincipal);
    private let hashesSet : StableOrderedSet.StableOrderedSet<Blob> = StableOrderedSet.StableOrderedSet<Blob>(32, func x = x, func x = ?x);
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
    public func trackedCanisters(limit : Nat, skip : Nat) : [Principal] {
      storageMap.values() |> Iter.drop(_, skip) |> Iter.take(_, limit) |> Iter.toArray(_);
    };

    public func canisterId(canisterIdx : Nat) : ?Principal = storageMap.get(canisterIdx);
    public func canisterIndex(canisterId : Principal) : ?Nat = storageMap.indexOf(canisterId);

    public func get(canisterIdx : Nat) : History.History {
      let ?item = List.get(historyStorage, canisterIdx) else Prim.trap("");
      item;
    };

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
        ignore LogLists.createList(changes);
      };
      List.add(historyStorage, history);
      changesAmountDistribution.add(0);
      id;
    };

    public func readChanges(canisterIdx : Nat) : [ExtendedChange.ExtendedChange] {
      LogLists.values(changes, canisterIdx)
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
      var recentChanges = info.recent_changes;
      // if there was "rename" change, we cannot rely on total_num_changes anymore
      // the solution is to filter out all of the events before last rename entry
      var i : Nat = recentChanges.size();
      label L while (i > 0) {
        i -= 1;
        switch (recentChanges[i].details) {
          case (?#rename_canister _) break L;
          case (_) {};
        };
      };
      if (i > 0) {
        recentChanges := Array.tabulate<IC.CanisterChange>(recentChanges.size() - i, func(n) = recentChanges[n + i]);
      };

      var ret : Nat64 = latestChangeTimestamp;
      let changes_size = recentChanges.size();
      if (changes_size > Nat64.toNat(info.total_num_changes)) {
        Prim.trap("Error while appending changes: recent changes size is " # debug_show changes_size # " while total_num_changes is " # debug_show info.total_num_changes # ". Canister id: " # debug_show (storageMap.get(canisterIdx)));
      };
      var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;
      let oldChangesAmount = LogLists.size(changes, canisterIdx);
      for (change in recentChanges.vals()) {
        if (change.timestamp_nanos > latestChangeTimestamp) {
          LogLists.append(
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
      changesAmountDistribution.update(oldChangesAmount, LogLists.size(changes, canisterIdx));
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

    public func registerMetrics(renderer : PT.Renderer) {
      func getEnumerationPagesAllocated(data : Enumeration.StableData) : Nat {
        Nat64.toNat(Region.size(data.nodes.region) + Region.size(data.leaves.region));
      };

      renderer.addValue(
        [
          PT.newValue("stable_records_total", [], func() = LogLists.totalSize(changes)),
          PT.newValue("stable_pages_allocated", [], func() = Nat64.toNat(Region.size(changes.data) + Region.size(changes.indexTable))),
        ].bundle([("structure", "changes_lists")])
      );

      renderer.addValue(
        [
          PT.newValue("stable_records_total", [], func() = storageMap.size()),
          PT.newValue("stable_pages_allocated", [], func() = getEnumerationPagesAllocated(storageMap.share())),
          PT.newValue("stable_map_byte_size", [], func() = storageMap.memoryStats().byte_size),
          PT.newValue("stable_map_leaf_count", [], func() = storageMap.memoryStats().leaf_count),
          PT.newValue("stable_map_node_count", [], func() = storageMap.memoryStats().node_count),
        ].bundle([("structure", "storage_map")])
      );

      renderer.addValue(
        [
          PT.newValue("stable_records_total", [], func() = principalsSet.size()),
          PT.newValue("stable_pages_allocated", [], func() = getEnumerationPagesAllocated(principalsSet.share())),
          PT.newValue("stable_map_byte_size", [], func() = principalsSet.memoryStats().byte_size),
          PT.newValue("stable_map_leaf_count", [], func() = principalsSet.memoryStats().leaf_count),
          PT.newValue("stable_map_node_count", [], func() = principalsSet.memoryStats().node_count),
        ].bundle([("structure", "principals_set")])
      );

      renderer.addValue(
        [
          PT.newValue("stable_records_total", [], func() = hashesSet.size()),
          PT.newValue("stable_pages_allocated", [], func() = getEnumerationPagesAllocated(hashesSet.share())),
          PT.newValue("stable_map_byte_size", [], func() = hashesSet.memoryStats().byte_size),
          PT.newValue("stable_map_leaf_count", [], func() = hashesSet.memoryStats().leaf_count),
          PT.newValue("stable_map_node_count", [], func() = hashesSet.memoryStats().node_count),
        ].bundle([("structure", "hashes_set")])
      );
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
