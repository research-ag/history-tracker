import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";

import PT "mo:promtracker";

module {

  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  public class DistributionPtValue(pt : PT.PromTracker, prefix : Text, labels : Text) {

    var counters : [var Nat] = [var];
    var values : [PT.PullValue] = [];

    public func remove() {
      for (v in values.values()) {
        v.remove();
      };
      values := [];
      counters := [var];
    };

    func getBucketIndex_(entry : Nat) : Nat {
      if (entry == 0) return 0;
      var x : Nat64 = Nat64.fromNat(entry) - 1;
      x |= x >> 1;
      x |= x >> 2;
      x |= x >> 4;
      x |= x >> 8;
      x |= x >> 16;
      x |= x >> 32;
      x += 1;
      var bucketIndex : Nat = 0;
      while (x > 0) {
        x >>= 1;
        bucketIndex += 1;
      };
      bucketIndex;
    };

    func allocateBucketFor_(entry : Nat) : Nat {
      let bucket = getBucketIndex_(entry);
      if (counters.size() < bucket + 1) {
        counters := Array.tabulateVar<Nat>(
          bucket + 1,
          func(i) {
            if (i < counters.size()) return counters[i];
            0;
          },
        );
        values := Array.tabulate<PT.PullValue>(
          bucket + 1,
          func(i) {
            if (i < values.size()) return values[i];
            var pow2 : Nat64 = 0;
            if (i > 0) {
              pow2 := 1 << Nat64.fromNat(i - 1);
            };
            pt.addPullValue(
              prefix,
              concat(labels, "le=\"" # Nat64.toText(pow2) # "\""),
              func() {
                var res = 0;
                var j = 0;
                while (j <= i) {
                  res += counters[j];
                  j += 1;
                };
                res;
              },
            );
          },
        );
      };
      bucket;
    };

    public func addEntry(entry : Nat) {
      let bucket = allocateBucketFor_(entry);
      counters[bucket] += 1;
    };

    public func removeEntry(entry : Nat) {
      let bucket = allocateBucketFor_(entry);
      counters[bucket] -= 1;
    };

    public func updateEntry(oldEntryValue : Nat, newEntryValue : Nat) {
      let oldBucket = allocateBucketFor_(oldEntryValue);
      let newBucket = allocateBucketFor_(newEntryValue);
      if (oldBucket == newBucket) return;
      counters[oldBucket] -= 1;
      counters[newBucket] += 1;
    };

  };
};
