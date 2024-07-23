import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";

module {
  type CanisterChange = {
    timestamp_nanos : Nat64;
    canister_version : Nat64;
    origin : CanisterChangeOrigin;
    details : CanisterChangeDetails;
  };

  type CanisterChangeDetails = {
    #creation : CreationRecord;
    #code_deployment : CodeDeploymentRecord;
    #controllers_change : CreationRecord;
    #code_uninstall;
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

  type CanisterInstallMode = {
    #reinstall;
    #upgrade;
    #install;
  };

  type CreationRecord = {
    controllers : [Principal];
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
    canister_info : CanisterInfoRequest -> async CanisterInfoResponse;
  };
};
