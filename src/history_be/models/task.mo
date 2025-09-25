import Nat64 "mo:base/Nat64";

import PT "mo:promtracker";

import RoundRobin "../utils/round_robin";

module Task {
  public type TaskState = {
    alias : Text;
    var roundsInterval : Nat64;
    var roundStart : Nat64;
    var lastRoundCompletedAt : Nat64;
    var lastRoundDuration : Nat64;
  };

  // common interface
  public type Task = {
    alias : Text;
    dataSource : RoundRobin.RoundRobinSource<Nat>;
    var roundsInterval : Nat64;
    var roundStart : Nat64;
    var lastRoundCompletedAt : Nat64;
    var lastRoundDuration : Nat64;
    metrics : {
      var roundDurationGauge : ?PT.GaugeValue;
    };
  };
  public func newTask(state : TaskState, dataSource : RoundRobin.RoundRobinSource<Nat>) : Task = {
    alias = state.alias;
    dataSource;
    var roundsInterval = state.roundsInterval;
    var roundStart = state.roundStart;
    var lastRoundCompletedAt = state.lastRoundCompletedAt;
    var lastRoundDuration = state.lastRoundDuration;
    metrics = {
      var roundDurationGauge = null;
    };
  };

  // sub-interface
  public type BufferTask = {
    alias : Text;
    dataSource : RoundRobin.RoundRobinBuffer<Nat>;
    var roundsInterval : Nat64;
    var roundStart : Nat64;
    var lastRoundCompletedAt : Nat64;
    var lastRoundDuration : Nat64;
    metrics : {
      var roundDurationGauge : ?PT.GaugeValue;
    };
  };

  public func newBufferTask(state : TaskState, dataSource : RoundRobin.RoundRobinBuffer<Nat>) : BufferTask = {
    alias = state.alias;
    dataSource;
    var roundsInterval = state.roundsInterval;
    var roundStart = state.roundStart;
    var lastRoundCompletedAt = state.lastRoundCompletedAt;
    var lastRoundDuration = state.lastRoundDuration;
    metrics = {
      var roundDurationGauge = null;
    };
  };

  public func registerMetrics(pt : PT.PromTracker, task : Task.Task) {
    let lbl = "task=\"" # task.alias # "\"";
    ignore pt.addPullValue("tracked_canisters_total", lbl, func() = task.dataSource.size());
    ignore pt.addPullValue("sync_pos", lbl, func() = task.dataSource.ctr());
    ignore pt.addPullValue("round", lbl, func() = task.dataSource.round());
    ignore pt.addPullValue("round_start", lbl, func() = task.roundStart |> Nat64.toNat(_));
    ignore pt.addPullValue("rounds_interval", lbl, func() = task.roundsInterval |> Nat64.toNat(_));
    ignore pt.addPullValue("last_round_completed_at", lbl, func() = task.lastRoundCompletedAt |> Nat64.toNat(_));
    ignore pt.addPullValue("last_round_duration", lbl, func() = task.lastRoundDuration |> Nat64.toNat(_));
    task.metrics.roundDurationGauge := ?pt.addGauge("round_duration", lbl, #both, [0], false);
  };

  public func deregisterMetrics(pt : PT.PromTracker, task : Task.Task) {
    let lbl = "task=\"" # task.alias # "\"";
    pt.removeValue("tracked_canisters_total", lbl);
    pt.removeValue("sync_pos", lbl);
    pt.removeValue("round", lbl);
    pt.removeValue("round_start", lbl);
    pt.removeValue("rounds_interval", lbl);
    pt.removeValue("last_round_completed_at", lbl);
    pt.removeValue("last_round_duration", lbl);
    pt.removeValue("round_duration", lbl);
  };

};
