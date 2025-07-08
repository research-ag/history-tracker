import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Prim "mo:prim";
import R "mo:base/Result";

import IC "ic";

module History {

  public type History = {
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var timestamp_nanos : Nat64; // latest sync timestamp
    var sync_version : Nat; // sync version (number of syncs)
    var is_deleted : Bool; // set to true if we received #destination_invalid. Skip synchronizing once set
  };

  public type TrackError = {
    #AlreadyTracked : { message : Text };
    #DoesNotExist : { message : Text };
    #Busy : { message : Text };
    #Unexpected : { message : Text };
  };

  public func track_error(e : Error.Error) : TrackError {
    switch (Error.code(e)) {
      case (#destination_invalid) return #DoesNotExist({
        message = "The canister does not exist.";
      });
      case (#system_transient or #system_unknown) return #Busy({
        message = "The system is busy. Try again.";
      });
      case (_) return #Unexpected({
        message = "An unexpected error was encountered: " # Error.message(e);
      });
    };
  };

  public func new() : History = {
    var latest_change_timestamp = 0;
    var total_num_changes = 0;
    var timestamp_nanos = 0;
    var sync_version = 0;
    var is_deleted = false;
  };

  let ic = actor "aaaaa-aa" : IC.Management;

  public func sync(canister_id : Principal, history : History) : async* R.Result<IC.CanisterInfoResponse, TrackError> {
    try {
      let info = await ic.canister_info({
        canister_id = canister_id;
        num_requested_changes = ?20;
      });
      history.total_num_changes := info.total_num_changes;
      history.timestamp_nanos := Prim.time();
      history.sync_version += 1;
      #ok(info);
    } catch (e) {
      switch (Error.code(e)) {
        case (#destination_invalid) history.is_deleted := true;
        case (_) {};
      };
      #err(track_error(e));
    };
  };
};
