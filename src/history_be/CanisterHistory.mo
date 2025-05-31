import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import List "mo:new-base/List";
import Prim "mo:prim";

import IC "ic";

module {
  type ExtendedChange = IC.CanisterChange and {
    change_index : Nat;
  };

  public type Metadata = {
    name : Text;
    description : Text;
    latest_update_timestamp : Nat64;
  };

  public type History = {
    changes : List.List<ExtendedChange>; // all tracked changes
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var timestamp_nanos : Nat64; // latest sync timestamp
    var sync_version : Nat; // sync version (number of syncs)
    var metadata : {
      var name : Text;
      var description : Text;
      var latest_update_timestamp : Nat64;
    };
    canister_id : Principal;
  };

  public type CanisterChangesResponse = {
    changes : [ExtendedChange];
    total_num_changes : Nat64;
    timestamp_nanos : Nat64;
    sync_version : Nat;
  };

  public func new(canister_id : Principal) : History = {
    changes = List.empty<ExtendedChange>();
    var latest_change_timestamp = 0;
    var total_num_changes = 0;
    var timestamp_nanos = 0;
    var sync_version = 0;
    var metadata = {
      var name = "";
      var description = "";
      var latest_update_timestamp = 0;
    };
    canister_id;
  };

  let ic = actor "aaaaa-aa" : IC.Management;
  public class API(state : History) {

    public func sync() : async* Bool {
      // no try-catch => async errors are passed through to the caller
      let info = await ic.canister_info(sync_call_arg());
      sync_call_process_response(info);
      true;
    };

    public func sync_call_arg() : IC.CanisterInfoRequest = {
      canister_id = state.canister_id;
      num_requested_changes = ?20;
    };

    public func sync_call_process_response(info : IC.CanisterInfoResponse) {
      let changes_size = info.recent_changes.size();
      var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;

      // Merge untracked changes with already saved ones
      for (change in info.recent_changes.vals()) {
        if (change.timestamp_nanos > state.latest_change_timestamp) {
          List.add(
            state.changes,
            {
              change with
              change_index = cur_change_index;
            },
          );
          state.latest_change_timestamp := change.timestamp_nanos;
        };
        cur_change_index += 1;
      };

      state.total_num_changes := info.total_num_changes;
      state.timestamp_nanos := Prim.time();
      state.sync_version += 1;
    };

    public func canister_changes() : CanisterChangesResponse = {
      changes = List.toArray(state.changes);
      total_num_changes = state.total_num_changes;
      timestamp_nanos = state.timestamp_nanos;
      sync_version = state.sync_version;
    };

    public func metadata() : Metadata {
      {
        name = state.metadata.name;
        description = state.metadata.description;
        latest_update_timestamp = state.metadata.latest_update_timestamp;
      };
    };

    public func update_metadata(caller : Principal, name : ?Text, description : ?Text) : async* Bool {
      if (not Principal.isController(caller)) return false;

      switch (name) {
        case null {};
        case (?value) {
          state.metadata.name := value;
        };
      };

      switch (description) {
        case null {};
        case (?value) {
          state.metadata.description := value;
        };
      };

      state.metadata.latest_update_timestamp := Prim.time();
      return true;
    };
  };
};
