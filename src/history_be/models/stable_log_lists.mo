import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat16 "mo:base/Nat16";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Region "mo:base/Region";

/// This module implements an array of linked lists, fully stored in memory regions.
/// All data is managed using two growable regions: `indexTable` and `data`.

/// To use a list, client code must first allocate it using `allocateList`.
/// Each list is identified by a unique index — a consecutive natural number starting from 0.

/// --- INDEX TABLE REGION ---
/// The index table stores metadata for each list. Each record is 24 bytes long,
/// and the record for list `N` starts at offset `24 * N`.

/// Index table record structure:
/// | Offset | Type  | Description                                                          |
/// |--------|-------|----------------------------------------------------------------------|
/// | 0      | Nat64 | Number of items in the list                                          |
/// | 8      | Nat64 | Pointer (offset in `data`) to the first item in the list (0 if none) |
/// | 16     | Nat64 | Pointer (offset in `data`) to the last item in the list (0 if none)  |

/// --- DATA REGION ---
/// The data region stores the actual list items.
/// It begins with a single reserved byte so that pointer value `0` can be used as a null pointer.

/// Each item is stored as a record with the following structure:
/// | Offset | Type  | Description                                          |
/// |--------|-------|------------------------------------------------------|
/// | 0      | Nat64 | Pointer to the previous item in the list (0 if none) |
/// | 8      | Nat64 | Pointer to the next item in the list (0 if none)     |
/// | 16     | Nat16 | Size of the data blob                                |
/// | 18     | Blob  | Actual item data                                     |

module {

  public type StableLogLists = {
    indexTable : Region;
    data : Region;
    var dataLength : Nat;
    var listsAmount : Nat;
    var totalRecords : Nat;
  };

  type Record = { prevPtr : Nat64; nextPtr : Nat64; data : Blob };

  public func new() : StableLogLists = {
    indexTable = Region.new();
    data = Region.new();
    var dataLength = 1;
    var listsAmount = 0;
    var totalRecords = 0;
  };

  public func size(l : StableLogLists, listIndex : Nat) : Nat = loadListLength_(l, listIndex) |> Nat64.toNat(_);

  public func totalSize(l : StableLogLists) : Nat = l.totalRecords;

  public func allocateList(l : StableLogLists) : Nat {
    let newlistIndex = l.listsAmount;
    if (65536 * Region.size(l.indexTable) < (Nat64.fromNat(newlistIndex) + 1) * 24 and Region.grow(l.indexTable, 1) == 0xFFFF_FFFF_FFFF_FFFF) {
      Prim.trap("Out of memory");
    };
    l.listsAmount += 1;
    newlistIndex;
  };

  public func append(l : StableLogLists, listIndex : Nat, data : Blob) {
    if (listIndex >= l.listsAmount) {
      Prim.trap("Cannot append record to list #" # debug_show listIndex # ". List was not allocated");
    };
    let lastItemPtr = loadLastRecordPtr_(l, listIndex);
    let newItemPtr = appendRecord_(l, { nextPtr = 0; prevPtr = lastItemPtr; data });
    if (lastItemPtr > 0) {
      storeNextPtr_(l, lastItemPtr, newItemPtr);
    } else {
      storeFirstRecordPtr_(l, listIndex, newItemPtr);
    };
    storeLastRecordPtr_(l, listIndex, newItemPtr);
    storeListLength_(l, listIndex, loadListLength_(l, listIndex) + 1);
    l.totalRecords += 1;
  };

  public func values(l : StableLogLists, listIndex : Nat) : Iter.Iter<Blob> {
    if (listIndex >= l.listsAmount) {
      Prim.trap("Cannot retrieve values of list #" # debug_show listIndex # ". List was not allocated");
    };
    var ptr = loadFirstRecordPtr_(l, listIndex);
    {
      next = func() : ?Blob {
        if (ptr == 0) return null;
        let { nextPtr; data } = loadRecord_(l, ptr);
        ptr := nextPtr;
        ?data;
      };
    };
  };

  public func valuesRev(l : StableLogLists, listIndex : Nat) : Iter.Iter<Blob> {
    if (listIndex >= l.listsAmount) {
      Prim.trap("Cannot retrieve valuesRev of list #" # debug_show listIndex # ". List was not allocated");
    };
    var ptr = loadLastRecordPtr_(l, listIndex);
    {
      next = func() : ?Blob {
        if (ptr == 0) return null;
        let { prevPtr; data } = loadRecord_(l, ptr);
        ptr := prevPtr;
        ?data;
      };
    };
  };

  public func memoryStats(l : StableLogLists) : {
    pages : { indexTable : Nat; data : Nat };
    bytesUsed : Nat;
    totalRecords : Nat;
  } = {
    pages = {
      indexTable = Region.size(l.indexTable) |> Nat64.toNat(_);
      data = Region.size(l.data) |> Nat64.toNat(_);
    };
    bytesUsed = l.dataLength;
    totalRecords = l.totalRecords;
  };

  // ======================== INTERNAL PRIVATE FUNCTIONALITY ========================
  private func loadListLength_(l : StableLogLists, listIndex : Nat) : Nat64 = Region.loadNat64(l.indexTable, Nat64.fromNat(listIndex) * 3 * 8);
  private func storeListLength_(l : StableLogLists, listIndex : Nat, v : Nat64) = Region.storeNat64(l.indexTable, Nat64.fromNat(listIndex) * 3 * 8, v);

  private func loadFirstRecordPtr_(l : StableLogLists, listIndex : Nat) : Nat64 = Region.loadNat64(l.indexTable, (Nat64.fromNat(listIndex) * 3 + 1) * 8);
  private func storeFirstRecordPtr_(l : StableLogLists, listIndex : Nat, v : Nat64) = Region.storeNat64(l.indexTable, (Nat64.fromNat(listIndex) * 3 + 1) * 8, v);

  private func loadLastRecordPtr_(l : StableLogLists, listIndex : Nat) : Nat64 = Region.loadNat64(l.indexTable, (Nat64.fromNat(listIndex) * 3 + 2) * 8);
  private func storeLastRecordPtr_(l : StableLogLists, listIndex : Nat, v : Nat64) = Region.storeNat64(l.indexTable, (Nat64.fromNat(listIndex) * 3 + 2) * 8, v);

  private func loadRecord_(l : StableLogLists, pointer : Nat64) : Record {
    let prevPtr = Region.loadNat64(l.data, pointer);
    let nextPtr = Region.loadNat64(l.data, pointer + 8);
    let size = Region.loadNat16(l.data, pointer + 16);
    let data = Region.loadBlob(l.data, pointer + 18, Nat16.toNat(size));
    { data; prevPtr; nextPtr };
  };

  private func appendRecord_(l : StableLogLists, record : Record) : Nat64 {
    let recordSize = record.data.size() + 18;
    let pointer = Nat64.fromNat(l.dataLength);
    if (65536 * Region.size(l.data) < (Nat64.fromNat(recordSize) + pointer) and Region.grow(l.data, 2) == 0xFFFF_FFFF_FFFF_FFFF) {
      Prim.trap("Out of memory");
    };
    Region.storeNat64(l.data, pointer, record.prevPtr);
    Region.storeNat64(l.data, pointer + 8, record.nextPtr);
    Region.storeNat16(l.data, pointer + 16, Nat16.fromNat(record.data.size()));
    Region.storeBlob(l.data, pointer + 18, record.data);
    l.dataLength += recordSize;
    pointer;
  };

  private func storeNextPtr_(l : StableLogLists, recordPointer : Nat64, nextPtr : Nat64) = Region.storeNat64(l.data, recordPointer + 8, nextPtr);
  // ======================== INTERNAL PRIVATE FUNCTIONALITY ========================

};
