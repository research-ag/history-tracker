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

};
