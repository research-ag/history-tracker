import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Prim "mo:prim";

import IC "ic";

module History {

  public type History = {
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var timestamp_nanos : Nat64; // latest sync timestamp
    var sync_version : Nat; // sync version (number of syncs)
  };

  public func new() : History = {
    var latest_change_timestamp = 0;
    var total_num_changes = 0;
    var timestamp_nanos = 0;
    var sync_version = 0;
  };

  let ic = actor "aaaaa-aa" : IC.Management;

  public func sync(canister_id : Principal, history : History) : async* IC.CanisterInfoResponse {
    // no try-catch => async errors are passed through to the caller
    let info = await ic.canister_info({
      canister_id = canister_id;
      num_requested_changes = ?20;
    });
    history.total_num_changes := info.total_num_changes;
    history.timestamp_nanos := Prim.time();
    history.sync_version += 1;
    info;
  };
};
