import Array "mo:base/Array";
import Nat "mo:base/Nat";

import PT "mo:promtracker";

module {

  func concat(a : Text, b : Text) : Text {
    if (a == "") return b;
    if (b == "") return a;
    return a # "," # b;
  };

  public class DistributionPtValue(pt : PT.PromTracker, prefix : Text, labels : Text, bucketLimits : [Nat]) {
    let counters : [var Nat] = Array.init<Nat>(bucketLimits.size() + 1, 0);
    let values : [PT.PullValue] = Array.tabulate<PT.PullValue>(
      bucketLimits.size() + 1,
      func(i) {
        let lbl = if (i < bucketLimits.size()) {
          "le=\"" # Nat.toText(bucketLimits[i]) # "\"";
        } else {
          "le=\"+Inf\"";
        };
        pt.addPullValue(
          prefix,
          concat(labels, lbl),
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

    public func remove() {
      for (v in values.values()) {
        v.remove();
      };
    };

    private func getBucketIndex(entry : Nat) : Nat {
      for (i in bucketLimits.keys()) {
        if (entry <= bucketLimits[i]) {
          return i;
        };
      };
      bucketLimits.size();
    };

    public func addEntry(entry : Nat) {
      let bucket = getBucketIndex(entry);
      counters[bucket] += 1;
    };

    public func removeEntry(entry : Nat) {
      let bucket = getBucketIndex(entry);
      counters[bucket] -= 1;
    };

    public func updateEntry(oldEntryValue : Nat, newEntryValue : Nat) {
      let oldBucket = getBucketIndex(oldEntryValue);
      let newBucket = getBucketIndex(newEntryValue);
      if (oldBucket == newBucket) return;
      counters[oldBucket] -= 1;
      counters[newBucket] += 1;
    };

  };
};
