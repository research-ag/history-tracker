import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Iter "mo:base/Iter";
import Deque "mo:base/Deque";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Timer "mo:base/Timer";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Error "mo:base/Error";
import Vector "mo:vector/Class";
import Vec "mo:vector";
import PT "mo:promtracker";

import Http "tiny_http";
import CanisterHistory "CanisterHistory";

actor class HistoryTracker() = self {

  module Errors {
    public type Track = {
      #AlreadyTracked : { message : Text };
    };

    public type UpdateMetadata = {
      #CanisterNotTracked : { message : Text };
    };
  };

  let pt = PT.PromTracker("", 65);
  pt.addSystemValues();

  /// Number of canisters that are synchronized per iteration.
  let canisters_num_to_sync = 5;

  type StableData = (
    PT.StableData, // pt
    [CanisterHistory.StableData], // history_storage
    RBTree.Tree<Principal, Nat>, // history_storage_map
    Deque.Deque<Nat>, // sync_queue
  );

  /// Converts the history storage to stable type.
  func convert_hs_to_stable(data : Vector.Vector<CanisterHistory.CanisterHistory>) : [CanisterHistory.StableData] {
    data.vals()
    |> Iter.map<CanisterHistory.CanisterHistory, CanisterHistory.StableData>(_, func(v) = v.share())
    |> Iter.toArray(_);
  };

  /// Storage for all the canister histories.
  let history_storage = Vector.Vector<CanisterHistory.CanisterHistory>();

  /// Maps the canister id to the history instance index in the storage.
  let history_storage_map = RBTree.RBTree<Principal, Nat>(Principal.compare);

  /// Contains indexes of the canister histories in the order in which they will sync.
  var sync_queue = Deque.empty<Nat>();

  let start_time = Time.now();

  func uptime() : Nat {
    let end_time = Time.now();
    let duration : ?Nat = Nat.fromText(Int.toText(end_time - start_time));

    switch (duration) {
      case (?x) { x / 1_000_000_000 };
      case null {
        Debug.trap("Internal error");
      };
    };
  };

  ignore pt.addPullValue("tracked_canisters_total", "", func() = history_storage.size());
  let syncAttempts = pt.addCounter("sync_attempts_total", "", true);
  let syncSuccess = pt.addCounter("sync_success_total", "", true);
  let syncFailure = pt.addCounter("sync_failure_total", "", true);
  let syncDuration = pt.addGauge("canister_sync_duration_seconds", "", #both, [], true);
  let changesPerSync = pt.addGauge("canister_changes_per_sync", "", #both, [], true);
  ignore pt.addPullValue("canisters_synced_per_minute", "", func() = canisters_num_to_sync);
  let metadataUpdates = pt.addCounter("metadata_update_total", "", true);
  let unauthorizedMetadataUpdates = pt.addCounter("unauthorized_metadata_update_total", "", true);
  ignore pt.addPullValue("uptime_seconds", "", uptime);

  stable var stable_data : StableData = (pt.share(), convert_hs_to_stable(history_storage), history_storage_map.share(), sync_queue);

  public query func tracked_canisters_total() : async Nat {
    history_storage.size();
  };

  public query func is_canister_tracked(canister_id : Principal) : async Bool {
    history_storage_map.get(canister_id) != null;
  };

  public func track(canister_id : Principal) : async Result.Result<(), Errors.Track> {
    if (history_storage_map.get(canister_id) != null) return #err(#AlreadyTracked({ message = "The canister is already tracked." }));
    let new_canister_history = CanisterHistory.CanisterHistory(canister_id);
    ignore await* new_canister_history.sync();
    history_storage.add(new_canister_history);
    let last_index : Nat = history_storage.size() - 1;
    history_storage_map.put(canister_id, last_index);
    sync_queue := Deque.pushBack(sync_queue, last_index);
    #ok();
  };

  public query func canister_changes(canister_id : Principal) : async ?CanisterHistory.CanisterChangesResponse {
    switch (history_storage_map.get(canister_id)) {
      case (null) null;
      case (?index) {
        let history = history_storage.get(index);
        ?history.canister_changes();
      };
    };
  };

  public query func canister_state(canister_id : Principal) : async ?CanisterHistory.CanisterStateResponse {
    switch (history_storage_map.get(canister_id)) {
      case (null) null;
      case (?index) {
        let history = history_storage.get(index);
        ?history.canister_state();
      };
    };
  };

  public query func metadata(canister_id : Principal) : async ?CanisterHistory.SharedCanisterMetadata {
    switch (history_storage_map.get(canister_id)) {
      case (null) null;
      case (?index) {
        let history = history_storage.get(index);
        ?history.metadata();
      };
    };
  };

  public shared ({ caller }) func update_metadata(canister_id : Principal, name : ?Text, description : ?Text) : async Result.Result<(), Errors.UpdateMetadata> {
    switch (history_storage_map.get(canister_id)) {
      case (null) return #err(#CanisterNotTracked({ message = "The canister is not tracked." }));
      case (?index) {
        let history = history_storage.get(index);
        let result = await* history.update_metadata(caller, name, description);
        switch (result) {
          case true {
            metadataUpdates.add(1);
            #ok();
          };
          case false {
            unauthorizedMetadataUpdates.add(1);
            throw Error.reject("Access denied.");
          };
        };
      };
    };
  };

  func trigger_sync() : async* () {
    var ctr = 0;
    let sync_num = Nat.min(canisters_num_to_sync, history_storage.size());
    while (ctr < sync_num) {
      let (index, queue_after_pop) = switch (Deque.popFront(sync_queue)) {
        case (?v) v;
        case (null) Debug.trap("Internal error.");
      };
      sync_queue := queue_after_pop;
      let history = history_storage.get(index);
      try {
        ignore async {
          let start_time = Time.now();
          syncAttempts.add(1);
          try {
            let result = await* history.sync();

            let end_time = Time.now();
            let duration : ?Nat = Nat.fromText(Int.toText(end_time - start_time));

            switch (duration) {
              case (?x) { syncDuration.update((x) / 1_000_000_000) };
              case null {};
            };

            switch (result) {
              case (?changes_size) {
                syncSuccess.add(1);
                changesPerSync.update(changes_size);
              };
              case null { syncFailure.add(1) };
            };
          } catch (_) {
            syncFailure.add(1);
          };
        };
      } catch (_) {};
      sync_queue := Deque.pushBack(sync_queue, index);
      ctr += 1;
    };
  };

  ignore Timer.recurringTimer<system>(
    #seconds 60,
    func() : async () { await* trigger_sync() },
  );

  system func preupgrade() {
    stable_data := (pt.share(), convert_hs_to_stable(history_storage), history_storage_map.share(), sync_queue);
  };

  system func postupgrade() {
    pt.unshare(stable_data.0);

    history_storage.unshare(
      (stable_data.1)
      |> Iter.fromArray(_)
      |> Iter.map<CanisterHistory.StableData, CanisterHistory.CanisterHistory>(
        _,
        func(v) = CanisterHistory.fromStableData(v),
      )
      |> Vec.fromIter(_)
    );

    history_storage_map.unshare(stable_data.2);
    sync_queue := stable_data.3;
  };

  public query func http_request(req : Http.Request) : async Http.Response {
    let ?path = Text.split(req.url, #char '?').next() else return Http.render400();
    let labels = "canister=\"" # PT.shortName(self) # "\"";
    switch (req.method, path) {
      case ("GET", "/metrics") Http.renderPlainText(pt.renderExposition(labels));
      case (_) Http.render400();
    };
  };
};
