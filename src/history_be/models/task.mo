import Nat64 "mo:core/Nat64";

import PT "mo:promtracker";
import { Gauge; Tracker } "mo:promtracker";

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
    var metrics : ?{
      pullValuesRef : Nat;
      roundDurationGauge : Gauge.Gauge;
    };
  };
  public func newTask(state : TaskState, dataSource : RoundRobin.RoundRobinSource<Nat>) : Task = {
    alias = state.alias;
    dataSource;
    var roundsInterval = state.roundsInterval;
    var roundStart = state.roundStart;
    var lastRoundCompletedAt = state.lastRoundCompletedAt;
    var lastRoundDuration = state.lastRoundDuration;
    var metrics = null;
  };

  // sub-interface
  public type BufferTask = {
    alias : Text;
    dataSource : RoundRobin.RoundRobinBuffer<Nat>;
    var roundsInterval : Nat64;
    var roundStart : Nat64;
    var lastRoundCompletedAt : Nat64;
    var lastRoundDuration : Nat64;
    var metrics : ?{
      pullValuesRef : Nat;
      roundDurationGauge : Gauge.Gauge;
    };
  };

  public func newBufferTask(state : TaskState, dataSource : RoundRobin.RoundRobinBuffer<Nat>) : BufferTask = {
    alias = state.alias;
    dataSource;
    var roundsInterval = state.roundsInterval;
    var roundStart = state.roundStart;
    var lastRoundCompletedAt = state.lastRoundCompletedAt;
    var lastRoundDuration = state.lastRoundDuration;
    var metrics = null;
  };

  public func registerMetrics(task : Task.Task, pt : Tracker.Tracker, renderer : PT.Renderer) {
    let pullValuesRef = renderer.addValueRef(
      [
        PT.newValue("tracked_canisters_total", [], func() = task.dataSource.size()),
        PT.newValue("sync_pos", [], func() = task.dataSource.ctr()),
        PT.newValue("round", [], func() = task.dataSource.round()),
        PT.newValue("round_start", [], func() = task.roundStart |> Nat64.toNat(_)),
        PT.newValue("rounds_interval", [], func() = task.roundsInterval |> Nat64.toNat(_)),
        PT.newValue("last_round_completed_at", [], func() = task.lastRoundCompletedAt |> Nat64.toNat(_)),
        PT.newValue("last_round_duration", [], func() = task.lastRoundDuration |> Nat64.toNat(_)),
      ].bundle([("task", task.alias)])
    );
    let roundDurationGauge = pt.newGauge("round_duration", [("task", task.alias)], []);

    task.metrics := ?{ pullValuesRef; roundDurationGauge };
  };

  public func deregisterMetrics(task : Task.Task, renderer : PT.Renderer) {
    switch (task.metrics) {
      case (?{ pullValuesRef; roundDurationGauge }) {
        renderer.removeValue(pullValuesRef);
        roundDurationGauge.unregister();
        task.metrics := null;
      };
      case (_) {};
    };
  };

};
