import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat16 "mo:base/Nat16";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Region "mo:base/Region";

/// This module implements an array of linked lists, fully stored in regions.
/// We name each linked list as "bucket" internally.
/// Caller code can append records to any bucket by it's index, no need to initialize it in any way
/// We store everything in two regions: `indexTable` and `data`. Both tables can grow.
/// Bucket indexes have to be >= 0 and < 2^24 (16_777_216)
/// The limit is hardcoded so index table cannot grow bigger than 402 mb (6144 pages)

/// By design, we expect caller code to use bucket indexes from zero and move forward.
/// Accessing big bucket index will immediately result in index table grow

/// INDEX TABLE REGION
/// Index table consist of 24-bytes records, one per bucket. A record for bucket N starts at offset 24*N

/// Item structure:
/// | Offset | Type  | Description                                                          |
/// |--------|-------|----------------------------------------------------------------------|
/// | 0      | Nat64 | Amount of items in the bucket                                        |
/// | 8      | Nat64 | A pointer in data region where first item of the given bucket starts |
/// | 16     | Nat64 | A pointer in data region where last item of the given bucket starts  |
/// Note that for empty bucket all values are equal to zero.

/// DATA REGION
/// Data table consists of 8 bytes header, followed by raw data, which contains records

/// Header structure:
/// | Offset | Type  | Description                                                                                                          |   |   |
/// |--------|-------|------------------------------------------------------------------|
/// | 0      | Nat64 | How much bytes are reserved by data, at the same time a pointer  |
/// |        |       | where we write a new record. Equals to 8 by default              |

/// Data record structure:
/// | Offset | Type  | Description                                                                 |
/// |--------|-------|-----------------------------------------------------------------------------|
/// | 0      | Nat16 | A size of blob with actual record data                                      |
/// | 2      | Nat64 | A pointer in data region where previous item of the given bucket is located |
/// | 10     | Nat64 | A pointer in data region where next item of the given bucket is located     |
/// | 18     | Blob  | An actual record data                                                       |
module {

  public type StableBucketList = {
    indexTable : Region;
    data : Region;
  };

  public type TypedStableBucketListOps<T> = {
    serialize : (T) -> Blob;
    deserialize : (Blob) -> ?T;
  };

  public let blobOps : TypedStableBucketListOps<Blob> = {
    serialize = func x = x;
    deserialize = func x = ?x;
  };

  type Record<T> = { prevPtr : Nat64; nextPtr : Nat64; data : ?T };

  public func new() : StableBucketList {
    let list = {
      indexTable = Region.new();
      data = Region.new();
    };
    ignore Region.grow(list.indexTable, 1);
    ignore Region.grow(list.data, 2);

    _storeDataTailPtr(list, DATA_HEADER_SIZE);
    list;
  };

  public func size(l : StableBucketList, bucketIndex : Nat64) : Nat64 = _loadListLength(l, bucketIndex);

  public func totalSize(l : StableBucketList) : Nat {
    let tailPtr = _loadDataTailPtr(l);
    var totalRecords = 0;
    var ptr = DATA_HEADER_SIZE;
    while (ptr < tailPtr) {
      ptr += 18 + Region.loadNat16(l.data, ptr) |> Nat64.fromNat(Nat16.toNat(_));
      totalRecords += 1;
    };
    totalRecords;
  };

  public func append<T>(l : StableBucketList, bucketIndex : Nat64, data : T, ops : TypedStableBucketListOps<T>) {
    if (bucketIndex > MAX_BUCKET_INDEX) {
      Prim.trap("Bucket index is too high");
    };
    let freeSpace = 65536 * Region.size(l.data) - _loadDataTailPtr(l);
    if (freeSpace <= MAX_RECORD_SIZE and Region.grow(l.data, 2) == 0xFFFF_FFFF_FFFF_FFFF) {
      Prim.trap("Out of memory");
    };
    let lastItemPtr = _loadLastRecordPtr(l, bucketIndex);
    let newItemPtr = _appendRecord<T>(l, { nextPtr = 0; prevPtr = lastItemPtr; data = ?data }, ops);
    if (lastItemPtr == 0) {
      // the bucket was empty before this insertion
      _storeFirstRecordPtr(l, bucketIndex, newItemPtr);
    } else {
      _storeNextPtr(l, lastItemPtr, newItemPtr);
    };
    _storeLastRecordPtr(l, bucketIndex, newItemPtr);
    _storeListLength(l, bucketIndex, _loadListLength(l, bucketIndex) + 1);
  };

  public func values<T>(l : StableBucketList, bucketIndex : Nat64, ops : TypedStableBucketListOps<T>) : Iter.Iter<?T> {
    var ptr = _loadFirstRecordPtr(l, bucketIndex);
    {
      next = func() : ??T {
        if (ptr == 0) return null;
        let { nextPtr; data } = _loadRecord(l, ptr, ops);
        ptr := nextPtr;
        ?data;
      };
    };
  };

  public func valuesRev<T>(l : StableBucketList, bucketIndex : Nat64, ops : TypedStableBucketListOps<T>) : Iter.Iter<?T> {
    var ptr = _loadLastRecordPtr(l, bucketIndex);
    {
      next = func() : ??T {
        if (ptr == 0) return null;
        let { prevPtr; data } = _loadRecord(l, ptr, ops);
        ptr := prevPtr;
        ?data;
      };
    };
  };

  public func memoryStats(l : StableBucketList) : {
    pages : { indexTable : Nat64; data : Nat64 };
    bytesUsed : Nat64;
  } = {
    pages = {
      indexTable = Region.size(l.indexTable);
      data = Region.size(l.data);
    };
    bytesUsed = _loadDataTailPtr(l);
  };

  // ======================== INTERNAL PRIVATE FUNCTIONALITY ========================
  private let MAX_BUCKET_INDEX : Nat64 = 16_777_215; // 2^24 - 1
  private let DATA_HEADER_SIZE : Nat64 = 8; // Nat64 tail pointer: the pointer where we allowed to write next entry
  private let MAX_RECORD_SIZE : Nat64 = 65553; // (2^16 - 1) (max blob size) + 18 (record header size)

  private func _wrapIndexRead(l : StableBucketList, bucketIndex : Nat64, readFunc : () -> Nat64) : Nat64 {
    if (65536 * Region.size(l.indexTable) >= (bucketIndex + 1) * 24) {
      readFunc();
    } else {
      0;
    };
  };

  private func _wrapIndexWrite(l : StableBucketList, bucketIndex : Nat64, writeFunc : () -> ()) {
    func int(l : StableBucketList, bucketIndex : Nat64, writeFunc : () -> (), growRegion : Bool) {
      let actualSize = 65536 * Region.size(l.indexTable);
      let minRequiredSize = (bucketIndex + 1) * 24;
      if (actualSize >= minRequiredSize) {
        writeFunc();
      } else if (growRegion) {
        ignore Region.grow(l.indexTable, (minRequiredSize - actualSize) / 65536 + 1);
        int(l, bucketIndex, writeFunc, false);
      } else {
        Prim.trap("Out of memory while writing to index table");
      };
    };
    int(l, bucketIndex, writeFunc, true);
  };

  private func _loadListLength(l : StableBucketList, bucketIndex : Nat64) : Nat64 = (func() : Nat64 = Region.loadNat64(l.indexTable, bucketIndex * 3 * 8)) |> _wrapIndexRead(l, bucketIndex, _);
  private func _storeListLength(l : StableBucketList, bucketIndex : Nat64, v : Nat64) = (func() = Region.storeNat64(l.indexTable, bucketIndex * 3 * 8, v)) |> _wrapIndexWrite(l, bucketIndex, _);

  private func _loadFirstRecordPtr(l : StableBucketList, bucketIndex : Nat64) : Nat64 = (func() : Nat64 = Region.loadNat64(l.indexTable, (bucketIndex * 3 + 1) * 8)) |> _wrapIndexRead(l, bucketIndex, _);
  private func _storeFirstRecordPtr(l : StableBucketList, bucketIndex : Nat64, v : Nat64) = (func() = Region.storeNat64(l.indexTable, (bucketIndex * 3 + 1) * 8, v)) |> _wrapIndexWrite(l, bucketIndex, _);

  private func _loadLastRecordPtr(l : StableBucketList, bucketIndex : Nat64) : Nat64 = (func() : Nat64 = Region.loadNat64(l.indexTable, (bucketIndex * 3 + 2) * 8)) |> _wrapIndexRead(l, bucketIndex, _);
  private func _storeLastRecordPtr(l : StableBucketList, bucketIndex : Nat64, v : Nat64) = (func() = Region.storeNat64(l.indexTable, (bucketIndex * 3 + 2) * 8, v)) |> _wrapIndexWrite(l, bucketIndex, _);

  private func _loadDataTailPtr(l : StableBucketList) : Nat64 = Region.loadNat64(l.data, 0);
  private func _storeDataTailPtr(l : StableBucketList, v : Nat64) = Region.storeNat64(l.data, 0, v);

  private func _loadRecord<T>(l : StableBucketList, pointer : Nat64, ops : TypedStableBucketListOps<T>) : Record<T> {
    let size = Region.loadNat16(l.data, pointer);
    let prevPtr = Region.loadNat64(l.data, pointer + 2);
    let nextPtr = Region.loadNat64(l.data, pointer + 10);
    let raw = Region.loadBlob(l.data, pointer + 18, Nat16.toNat(size));
    { data = ops.deserialize(raw); prevPtr; nextPtr };
  };

  private func _appendRecord<T>(l : StableBucketList, record : Record<T>, ops : TypedStableBucketListOps<T>) : Nat64 {
    let raw : Blob = switch (record.data) {
      case (?data) { ops.serialize(data) };
      case (null) { "" };
    };
    let pointer = _loadDataTailPtr(l);
    Region.storeNat16(l.data, pointer, Nat16.fromNat(raw.size()));
    Region.storeNat64(l.data, pointer + 2, record.prevPtr);
    Region.storeNat64(l.data, pointer + 10, record.nextPtr);
    Region.storeBlob(l.data, pointer + 18, raw);
    _storeDataTailPtr(l, pointer + Nat64.fromNat(raw.size()) + 18);
    pointer;
  };

  private func _loadPrevPtr(l : StableBucketList, recordPointer : Nat64) : Nat64 = Region.loadNat64(l.data, recordPointer + 2);
  private func _storePrevPtr(l : StableBucketList, recordPointer : Nat64, prevPtr : Nat64) = Region.storeNat64(l.data, recordPointer + 2, prevPtr);

  private func _loadNextPtr(l : StableBucketList, recordPointer : Nat64) : Nat64 = Region.loadNat64(l.data, recordPointer + 10);
  private func _storeNextPtr(l : StableBucketList, recordPointer : Nat64, nextPtr : Nat64) = Region.storeNat64(l.data, recordPointer + 10, nextPtr);
  // ======================== INTERNAL PRIVATE FUNCTIONALITY ========================

};
