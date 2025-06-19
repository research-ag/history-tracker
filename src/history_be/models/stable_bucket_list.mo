import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat16 "mo:base/Nat16";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Region "mo:base/Region";

/// This module implements an array of linked lists, fully stored in regions.
/// We name each linked list as "bucket" internally.
/// We store everything in two regions: `indexTable` and `data`. Both tables can grow.
/// Bucket indexes have to be >= 0 and < 2^24 (16_777_216)
/// The limit is hardcoded so index table cannot grow bigger than 402 mb (6144 pages)

/// Client code needs to allocate bucket before appending anything to it

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
/// Data table consists of 1 reserved byte, followed by records data.
/// First byte is reserved so pointer which equals to 0 is a null pointer

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
    var dataLength : Nat64;
    var bucketsAllocated : Nat64;
    var totalRecords : Nat64;
  };

  type Record = { prevPtr : Nat64; nextPtr : Nat64; data : Blob };

  public func new() : StableBucketList {
    let list : StableBucketList = {
      indexTable = Region.new();
      data = Region.new();
      var dataLength = 1;
      var bucketsAllocated = 0;
      var totalRecords = 0;
    };
    ignore Region.grow(list.indexTable, 1);
    ignore Region.grow(list.data, 2);
    list;
  };

  public func size(l : StableBucketList, bucketIndex : Nat64) : Nat64 = _loadListLength(l, bucketIndex);

  public func totalSize(l : StableBucketList) : Nat64 = l.totalRecords;

  public func allocateBucket(l : StableBucketList) : Nat64 {
    if (l.bucketsAllocated >= MAX_BUCKET_INDEX) {
      Prim.trap("Max buckets amount is reached");
    };
    let newBucketIndex = l.bucketsAllocated;
    if (65536 * Region.size(l.indexTable) < (newBucketIndex + 1) * 24 and Region.grow(l.indexTable, 1) == 0xFFFF_FFFF_FFFF_FFFF) {
      Prim.trap("Out of memory");
    };
    l.bucketsAllocated += 1;
    newBucketIndex;
  };

  public func append(l : StableBucketList, bucketIndex : Nat64, data : Blob) {
    if (bucketIndex >= l.bucketsAllocated) {
      Prim.trap("Cannot append record to bucket #" # debug_show bucketIndex # ". Bucket was not allocated");
    };
    let lastItemPtr = _loadLastRecordPtr(l, bucketIndex);
    let newItemPtr = _appendRecord(l, { nextPtr = 0; prevPtr = lastItemPtr; data });
    if (lastItemPtr == 0) {
      // the bucket was empty before this insertion
      _storeFirstRecordPtr(l, bucketIndex, newItemPtr);
    } else {
      _storeNextPtr(l, lastItemPtr, newItemPtr);
    };
    _storeLastRecordPtr(l, bucketIndex, newItemPtr);
    _storeListLength(l, bucketIndex, _loadListLength(l, bucketIndex) + 1);
    l.totalRecords += 1;
  };

  public func values(l : StableBucketList, bucketIndex : Nat64) : Iter.Iter<Blob> {
    if (bucketIndex >= l.bucketsAllocated) {
      Prim.trap("Cannot retrieve values of bucket #" # debug_show bucketIndex # ". Bucket was not allocated");
    };
    var ptr = _loadFirstRecordPtr(l, bucketIndex);
    {
      next = func() : ?Blob {
        if (ptr == 0) return null;
        let { nextPtr; data } = _loadRecord(l, ptr);
        ptr := nextPtr;
        ?data;
      };
    };
  };

  public func valuesRev(l : StableBucketList, bucketIndex : Nat64) : Iter.Iter<Blob> {
    if (bucketIndex >= l.bucketsAllocated) {
      Prim.trap("Cannot retrieve valuesRev of bucket #" # debug_show bucketIndex # ". Bucket was not allocated");
    };
    var ptr = _loadLastRecordPtr(l, bucketIndex);
    {
      next = func() : ?Blob {
        if (ptr == 0) return null;
        let { prevPtr; data } = _loadRecord(l, ptr);
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
    bytesUsed = l.dataLength;
  };

  // ======================== INTERNAL PRIVATE FUNCTIONALITY ========================
  private let MAX_BUCKET_INDEX : Nat64 = 16_777_215; // 2^24 - 1

  private func _loadListLength(l : StableBucketList, bucketIndex : Nat64) : Nat64 = Region.loadNat64(l.indexTable, bucketIndex * 3 * 8);
  private func _storeListLength(l : StableBucketList, bucketIndex : Nat64, v : Nat64) = Region.storeNat64(l.indexTable, bucketIndex * 3 * 8, v);

  private func _loadFirstRecordPtr(l : StableBucketList, bucketIndex : Nat64) : Nat64 = Region.loadNat64(l.indexTable, (bucketIndex * 3 + 1) * 8);
  private func _storeFirstRecordPtr(l : StableBucketList, bucketIndex : Nat64, v : Nat64) = Region.storeNat64(l.indexTable, (bucketIndex * 3 + 1) * 8, v);

  private func _loadLastRecordPtr(l : StableBucketList, bucketIndex : Nat64) : Nat64 = Region.loadNat64(l.indexTable, (bucketIndex * 3 + 2) * 8);
  private func _storeLastRecordPtr(l : StableBucketList, bucketIndex : Nat64, v : Nat64) = Region.storeNat64(l.indexTable, (bucketIndex * 3 + 2) * 8, v);

  private func _loadRecord(l : StableBucketList, pointer : Nat64) : Record {
    let size = Region.loadNat16(l.data, pointer);
    let prevPtr = Region.loadNat64(l.data, pointer + 2);
    let nextPtr = Region.loadNat64(l.data, pointer + 10);
    let data = Region.loadBlob(l.data, pointer + 18, Nat16.toNat(size));
    { data; prevPtr; nextPtr };
  };

  private func _appendRecord(l : StableBucketList, record : Record) : Nat64 {
    let recordSize : Nat64 = Nat64.fromNat(record.data.size()) + 18;
    let pointer = l.dataLength;
    if (65536 * Region.size(l.data) - pointer < recordSize and Region.grow(l.data, 2) == 0xFFFF_FFFF_FFFF_FFFF) {
      Prim.trap("Out of memory");
    };
    Region.storeNat16(l.data, pointer, Nat16.fromNat(record.data.size()));
    Region.storeNat64(l.data, pointer + 2, record.prevPtr);
    Region.storeNat64(l.data, pointer + 10, record.nextPtr);
    Region.storeBlob(l.data, pointer + 18, record.data);
    l.dataLength += recordSize;
    pointer;
  };

  private func _loadPrevPtr(l : StableBucketList, recordPointer : Nat64) : Nat64 = Region.loadNat64(l.data, recordPointer + 2);
  private func _storePrevPtr(l : StableBucketList, recordPointer : Nat64, prevPtr : Nat64) = Region.storeNat64(l.data, recordPointer + 2, prevPtr);

  private func _loadNextPtr(l : StableBucketList, recordPointer : Nat64) : Nat64 = Region.loadNat64(l.data, recordPointer + 10);
  private func _storeNextPtr(l : StableBucketList, recordPointer : Nat64, nextPtr : Nat64) = Region.storeNat64(l.data, recordPointer + 10, nextPtr);
  // ======================== INTERNAL PRIVATE FUNCTIONALITY ========================

};
