import Array "mo:core/Array";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Map "mo:core/Map";
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

import History "history";
import Metadata "history/metadata";
import ExtendedChange "history/extended_change";
import IC "history/ic";

import PB "utils/principal_blob";

module {

  public type Storage = {
    // A list of history entries
    historyStorage : List.List<History.History>;
    // Changes lists. List index == history index in the storage
    changes : LogLists.LogLists;
    // Maps the canister id to the history instance index in the storage.
    storageMap : Enumeration.Enumeration;
    // Global storage of principals, which are presented in changes list. In the records we store only index of the entry in the ordered set
    principalsSet : Enumeration.Enumeration;
    // Global storage of module hashes, which are presented in changes list. In the history items we store only index of the entry in the ordered set
    hashesSet : Enumeration.Enumeration;
    // A storage for metadata
    metadataMap : Map.Map<Nat, Metadata.Metadata>;

    changesAmountDistribution : Heatmap.Heatmap;
  };

  public func empty(changesAmountDistribution : Heatmap.Heatmap) : Storage = {
    historyStorage = List.empty();
    changes = LogLists.new();
    storageMap = Enumeration.empty({
      aridity = 4;
      key_size = 10;
      pointer_size = 4;
      root_aridity = ?(4 ** 6);
      value_size = 0;
    });
    principalsSet = Enumeration.empty({
      aridity = 4;
      key_size = 30;
      pointer_size = 4;
      root_aridity = ?(4 ** 6);
      value_size = 0;
    });
    hashesSet = Enumeration.empty({
      aridity = 4;
      key_size = 32;
      pointer_size = 4;
      root_aridity = ?(4 ** 6);
      value_size = 0;
    });
    metadataMap = Map.empty<Nat, Metadata.Metadata>();
    changesAmountDistribution;
  };

  public func size(self : Storage) : Nat = List.size(self.historyStorage);

  public func isCanisterTracked(self : Storage, canisterId : Principal) : Bool = self.storageMap.containsKey(canisterId.toBlob());
  public func trackedCanisters(self : Storage, limit : Nat, skip : Nat) : [Principal] {
    self.storageMap.sliceToArray(
      Nat.min(skip, self.storageMap.size()),
      Nat.min(skip + limit, self.storageMap.size()),
    ).map<(Blob, Blob), Principal>(func(key : Blob, _) = Principal.fromBlob(key));
  };

  public func canisterId(self : Storage, canisterIdx : Nat) : ?Principal = switch (self.storageMap.get(canisterIdx)) {
    case (?(key, _)) ?Principal.fromBlob(key);
    case (null) null;
  };
  public func canisterIndex(self : Storage, canisterId : Principal) : ?Nat = switch (self.storageMap.lookup(canisterId.toBlob())) {
    case (?(key, idx)) ?idx;
    case (null) null;
  };

  public func get(self : Storage, canisterIdx : Nat) : History.History {
    let ?item = List.get(self.historyStorage, canisterIdx) else Prim.trap("");
    item;
  };

  public func insertCanister(self : Storage, canisterId : Principal, history : History.History) : Nat {
    let id = List.size(self.historyStorage);
    let (oldValue, mapIndex) = self.storageMap.lookupOrAdd(canisterId.toBlob(), "");
    if (Option.isSome(oldValue)) {
      Prim.trap("Error while inserting canister to storage: already exists");
    };
    if (mapIndex != id) {
      Prim.trap("Error while inserting canister to storage: map index is " # debug_show mapIndex # " while expected " # debug_show id);
    };
    while (self.changes.listsAmount <= id) {
      ignore LogLists.createList(self.changes);
    };
    List.add(self.historyStorage, history);
    self.changesAmountDistribution.add(0);
    id;
  };

  public func readChanges(self : Storage, canisterIdx : Nat) : [ExtendedChange.ExtendedChange] {
    LogLists.values(self.changes, canisterIdx)
    |> Iter.map<Blob, ?ExtendedChange.ExtendedChange>(
      _,
      func(b) = ExtendedChange.deserializeExtendedChange(
        b,
        func(index : Nat) : Principal {
          let (k, _) = self.principalsSet.at(index);
          let ?p = PB.toPrincipal(k) else Prim.trap("mapPrincipal failed!");
          p;
        },
        func(index : Nat) : Blob {
          let (k, _) = self.hashesSet.at(index);
          k;
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
    self : Storage,
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
      Prim.trap("Error while appending changes: recent changes size is " # debug_show changes_size # " while total_num_changes is " # debug_show info.total_num_changes # ". Canister id: " # debug_show (self.storageMap.get(canisterIdx)));
    };
    var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;
    let oldChangesAmount = LogLists.size(self.changes, canisterIdx);
    for (change in recentChanges.vals()) {
      if (change.timestamp_nanos > latestChangeTimestamp) {
        LogLists.append(
          self.changes,
          canisterIdx,
          ExtendedChange.serializeExtendedChange(
            { change with change_index = cur_change_index },
            func(p : Principal) : Nat {
              let (_, idx) = self.principalsSet.lookupOrAdd(PB.toBlob(p), "");
              idx;
            },
            func(hash : Blob) : Nat {
              let (_, idx) = self.hashesSet.lookupOrAdd(hash, "");
              idx;
            },
          ),
        );
        ret := change.timestamp_nanos;
      };
      cur_change_index += 1;
    };
    self.changesAmountDistribution.update(oldChangesAmount, LogLists.size(self.changes, canisterIdx));
    ret;
  };

  public func readMetadata(self : Storage, canisterIdx : Nat) : ?Metadata.Metadata = self.metadataMap.get(canisterIdx);

  public func updateMetadata(self : Storage, canisterIdx : Nat, name : ?Text, description : ?Text) : () {
    let metadata = switch (self.metadataMap.get(canisterIdx)) {
      case (?md) md;
      case (null) {
        let md = Metadata.new();
        self.metadataMap.add(canisterIdx, md);
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

  public func registerMetrics(self : Storage, renderer : PT.Renderer) {

    func getEnumerationPagesAllocated(data : Enumeration.Enumeration) : Nat {
      Nat64.toNat(Region.size(data.nodes_region) + Region.size(data.leaves_region));
    };

    renderer.addValue(
      [
        PT.newValue("stable_records_total", [], func() = LogLists.totalSize(self.changes)),
        PT.newValue("stable_pages_allocated", [], func() = Nat64.toNat(Region.size(self.changes.data) + Region.size(self.changes.indexTable))),
      ].bundle([("structure", "changes_lists")])
    );

    renderer.addValue(
      [
        PT.newValue("stable_records_total", [], func() = self.storageMap.size()),
        PT.newValue("stable_pages_allocated", [], func() = getEnumerationPagesAllocated(self.storageMap)),
        PT.newValue("stable_map_byte_size", [], func() = self.storageMap.memoryStats().byte_size),
        PT.newValue("stable_map_leaf_count", [], func() = self.storageMap.memoryStats().used_leaf_count),
        PT.newValue("stable_map_node_count", [], func() = self.storageMap.memoryStats().used_node_count),
      ].bundle([("structure", "storage_map")])
    );

    renderer.addValue(
      [
        PT.newValue("stable_records_total", [], func() = self.principalsSet.size()),
        PT.newValue("stable_pages_allocated", [], func() = getEnumerationPagesAllocated(self.principalsSet)),
        PT.newValue("stable_map_byte_size", [], func() = self.principalsSet.memoryStats().byte_size),
        PT.newValue("stable_map_leaf_count", [], func() = self.principalsSet.memoryStats().used_leaf_count),
        PT.newValue("stable_map_node_count", [], func() = self.principalsSet.memoryStats().used_node_count),
      ].bundle([("structure", "principals_set")])
    );

    renderer.addValue(
      [
        PT.newValue("stable_records_total", [], func() = self.hashesSet.size()),
        PT.newValue("stable_pages_allocated", [], func() = getEnumerationPagesAllocated(self.hashesSet)),
        PT.newValue("stable_map_byte_size", [], func() = self.hashesSet.memoryStats().byte_size),
        PT.newValue("stable_map_leaf_count", [], func() = self.hashesSet.memoryStats().used_leaf_count),
        PT.newValue("stable_map_node_count", [], func() = self.hashesSet.memoryStats().used_node_count),
      ].bundle([("structure", "hashes_set")])
    );
  };

};
