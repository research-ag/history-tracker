import Array "mo:base/Array";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Time "mo:base/Time";

import PT "mo:promtracker";

module {

  public type StableDataV1 = {
    buckets : [var Nat]; // Mutable array of hourly counters
    headIndex : Nat; // Points to the current hour's bucket
    lastRotation : Int; // Last time buckets were rotated
  };

  public func defaultStableDataV1() : StableDataV1 = {
    buckets = Array.init<Nat>(MONTH_HOURS, 0);
    headIndex = 0;
    lastRotation = Time.now();
  };

  // Time constants
  public let HOUR_NS = 3600_000_000_000; // 1 hour in nanoseconds
  public let DAY_HOURS = 24;
  public let WEEK_HOURS = 168; // 7 * 24
  public let MONTH_HOURS = 720; // 30 * 24

  public type TrackingStats = {
    new_24h : Nat;
    new_7d : Nat;
    new_30d : Nat;
  };

  public class Tracker(data : StableDataV1) {

    private var buckets : [var Nat] = data.buckets;
    private var headIndex = data.headIndex;
    private var lastRotation = data.lastRotation;

    public func inc() {
      rotateTrackingBuckets();
      buckets[headIndex] += 1;
    };

    public func getTrackingStats() : TrackingStats {
      rotateTrackingBuckets();
      {
        new_24h = sumBuckets(DAY_HOURS);
        new_7d = sumBuckets(WEEK_HOURS);
        new_30d = sumBuckets(MONTH_HOURS);
      };
    };

    public func registerMetrics(pt : PT.PromTracker) {
      ignore pt.addPullValue("tracked_24h", "", func() = sumBuckets(DAY_HOURS));
      ignore pt.addPullValue("tracked_7d", "", func() = sumBuckets(WEEK_HOURS));
      ignore pt.addPullValue("tracked_30d", "", func() = sumBuckets(MONTH_HOURS));
    };

    public func share() : StableDataV1 = {
      buckets;
      headIndex;
      lastRotation;
    };

    func getBucketIndex(hoursAgo : Nat) : Nat {
      // Calculate real index using circular buffer logic
      (headIndex + hoursAgo) % MONTH_HOURS;
    };

    func sumBuckets(hours : Nat) : Nat {
      var sum = 0;
      for (i in Iter.range(0, hours - 1)) {
        sum += buckets[getBucketIndex(i)];
      };
      sum;
    };

    func rotateTrackingBuckets() {
      let now = Time.now();
      let hours_passed = Int.abs(now - lastRotation) / HOUR_NS;

      if (hours_passed > 0) {
        // Clear only the new buckets we'll use
        let rotation_count = Nat.min(hours_passed, MONTH_HOURS);
        // Update head position
        for (i in Iter.range(0, rotation_count - 1)) {
          let newHead = (headIndex + (MONTH_HOURS - 1) : Nat) % MONTH_HOURS;
          buckets[newHead] := 0;
          headIndex := newHead;
        };
        lastRotation := now;
      };
    };

  };

};
