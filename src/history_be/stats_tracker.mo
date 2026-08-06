import VarArray "mo:core/VarArray";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Time "mo:core/Time";

import PT "mo:promtracker";

module {

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

  public type StatsTracker = {
    buckets : [var Nat]; // Hourly counters
    var headIndex : Nat; // Points to the current hour's bucket
    var lastRotation : Int; // Last time buckets were rotated
  };

  public func new() : StatsTracker = {
    buckets = VarArray.repeat<Nat>(0, MONTH_HOURS);
    var headIndex = 0;
    var lastRotation = Time.now();
  };

  public func inc(self : StatsTracker) {
    rotateTrackingBuckets(self);
    self.buckets[self.headIndex] += 1;
  };

  public func getTrackingStats(self : StatsTracker) : TrackingStats {
    rotateTrackingBuckets(self);
    {
      new_24h = sumBuckets(self, DAY_HOURS);
      new_7d = sumBuckets(self, WEEK_HOURS);
      new_30d = sumBuckets(self, MONTH_HOURS);
    };
  };

  public func registerMetrics(self : StatsTracker, renderer : PT.Renderer) {
    renderer.addValue(
      [
        PT.newValue("tracked_24h", [], func() = getTrackingStats(self).new_24h),
        PT.newValue("tracked_7d", [], func() = getTrackingStats(self).new_7d),
        PT.newValue("tracked_30d", [], func() = getTrackingStats(self).new_30d),
      ].bundle([])
    );
  };

  func getBucketIndex(self : StatsTracker, hoursAgo : Nat) : Nat {
    // Calculate real index using circular buffer logic
    (self.headIndex + hoursAgo) % MONTH_HOURS;
  };

  func sumBuckets(self : StatsTracker, hours : Nat) : Nat {
    var sum = 0;
    for (i in Nat.range(0, hours)) {
      sum += self.buckets[getBucketIndex(self, i)];
    };
    sum;
  };

  func rotateTrackingBuckets(self : StatsTracker) {
    let now = Time.now();
    let hours_passed = Int.abs(now - self.lastRotation) / HOUR_NS;

    if (hours_passed > 0) {
      // Clear only the new buckets we'll use
      let rotation_count = Nat.min(hours_passed, MONTH_HOURS);
      // Update head position
      for (i in Nat.range(0, rotation_count)) {
        let newHead = (self.headIndex + (MONTH_HOURS - 1) : Nat) % MONTH_HOURS;
        self.buckets[newHead] := 0;
        self.headIndex := newHead;
      };
      self.lastRotation := now;
    };
  };

};
