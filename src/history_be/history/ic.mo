import Principal "mo:core/Principal";
import Nat64 "mo:core/Nat64";

module {
  public type CanisterChange = {
    timestamp_nanos : Nat64;
    canister_version : Nat64;
    origin : ?CanisterChangeOrigin;
    details : ?CanisterChangeDetails;
  };

  type CanisterChangeDetails = {
    #creation : {
      controllers : [Principal];
    };
    #code_deployment : CodeDeploymentRecord;
    #controllers_change : {
      controllers : [Principal];
    };
    #code_uninstall;
    #load_snapshot : SnapshotRecord;
    #rename_canister : {
      canister_id : Principal;
      total_num_changes : Nat64;
      rename_to : {
        canister_id : Principal;
        version : Nat64;
        total_num_changes : Nat64;
      };
      requested_by : Principal;
    };
  };

  type CanisterChangeOrigin = {
    #from_user : {
      user_id : Principal;
    };
    #from_canister : {
      canister_id : Principal;
      canister_version : ?Nat64;
    };
  };

  type CodeDeploymentRecord = {
    mode : CanisterInstallMode;
    module_hash : Blob;
  };

  public type CanisterInstallMode = {
    #reinstall;
    #upgrade;
    #install;
  };

  public type SnapshotRecord = {
    from_canister_id : ?Principal;
    canister_version : Nat64;
    snapshot_id : Blob;
    taken_at_timestamp : Nat64;
  };

  public type CanisterInfoRequest = {
    canister_id : Principal;
    num_requested_changes : ?Nat64;
  };

  public type CanisterInfoResponse = {
    total_num_changes : Nat64;
    recent_changes : [CanisterChange];
    module_hash : ?[Nat8];
    controllers : [Principal];
  };

  public type Management = actor {
    canister_info : query CanisterInfoRequest -> async CanisterInfoResponse;
  };
};
