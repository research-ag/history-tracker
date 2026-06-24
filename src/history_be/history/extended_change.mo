import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";

import IC "ic";

/// A module containing canister change data type and operations on it
module ExtendedChange {

  /// A change record which we receive from IC and expose
  public type ExtendedChange = IC.CanisterChange and {
    change_index : Nat;
  };

  /// A change record which we store in the memory
  public type StableExtendedChange = {
    change_index : Nat;
    // IC.CanisterChange below  with mapped principals and module hashes to indexes (Nat)
    timestamp_nanos : Nat64;
    canister_version : Nat64;
    origin : ?{
      #from_user : {
        user_id_index : Nat;
      };
      #from_canister : {
        canister_id_index : Nat;
        canister_version : ?Nat64;
      };
    };
    details : ?{
      #creation : {
        controller_indexes : [Nat];
      };
      #code_deployment : {
        mode : IC.CanisterInstallMode;
        module_hash_index : Nat;
      };
      #controllers_change : {
        controller_indexes : [Nat];
      };
      #code_uninstall;
      #load_snapshot : {
        from_canister_id_index : ?Nat;
        canister_version : Nat64;
        snapshot_id : Blob;
        taken_at_timestamp : Nat64;
      };
      #rename_canister : {
        canister_id_index : Nat;
        total_num_changes : Nat64;
        requested_by_index : Nat;
        rename_to : {
          canister_id_index : Nat;
          version : Nat64;
          total_num_changes : Nat64;
        };
      };
    };
  };

  public func serializeExtendedChange(
    v : ExtendedChange,
    mapPrincipal : (Principal) -> Nat,
    mapHash : (Blob) -> Nat,
  ) : Blob {
    let change : StableExtendedChange = {
      v with
      origin = switch (v.origin) {
        case (null) null;
        case (?#from_user { user_id }) ?#from_user({
          user_id_index = mapPrincipal(user_id);
        });
        case (?#from_canister x) ?#from_canister({
          canister_id_index = mapPrincipal(x.canister_id);
          canister_version = x.canister_version;
        });
      };
      details = switch (v.details) {
        case (null) null;
        case (?#creation x) ?#creation({
          controller_indexes = Array.map(x.controllers, mapPrincipal);
        });
        case (?#controllers_change x) ?#controllers_change({
          controller_indexes = Array.map(x.controllers, mapPrincipal);
        });
        case (?#code_deployment x) ?#code_deployment({
          mode = x.mode;
          module_hash_index = mapHash(x.module_hash);
        });
        case (?#code_uninstall x) ?#code_uninstall(x);
        case (?#load_snapshot x) ?#load_snapshot({
          x with
          from_canister_id_index = switch (x.from_canister_id) {
            case (?p) ?mapPrincipal(p);
            case (null) null;
          };
        });
        case (?#rename_canister x) ?#rename_canister({
          canister_id_index = mapPrincipal(x.canister_id);
          requested_by_index = mapPrincipal(x.requested_by);
          total_num_changes = x.total_num_changes;
          rename_to = {
            canister_id_index = mapPrincipal(x.rename_to.canister_id);
            version = x.rename_to.version;
            total_num_changes = x.rename_to.total_num_changes;
          };
        });
      };
    };
    to_candid (change);
  };

  public func deserializeExtendedChange(
    raw : Blob,
    mapPrincipal : (Nat) -> Principal,
    mapHash : (Nat) -> Blob,
  ) : ?ExtendedChange {
    let ?v : ?StableExtendedChange = from_candid (raw) else return null;
    ?{
      v with
      origin = switch (v.origin) {
        case (null) null;
        case (?#from_user { user_id_index }) ?#from_user({
          user_id = mapPrincipal(user_id_index);
        });
        case (?#from_canister x) ?#from_canister({
          canister_id = mapPrincipal(x.canister_id_index);
          canister_version = x.canister_version;
        });
      };
      details = switch (v.details) {
        case (null) null;
        case (?#creation x) ?#creation({
          controllers = Array.map(x.controller_indexes, mapPrincipal);
        });
        case (?#controllers_change x) ?#controllers_change({
          controllers = Array.map(x.controller_indexes, mapPrincipal);
        });
        case (?#code_deployment x) ?#code_deployment({
          mode = x.mode;
          module_hash = mapHash(x.module_hash_index);
        });
        case (?#code_uninstall x) ?#code_uninstall(x);
        case (?#load_snapshot x) ?#load_snapshot({
          x with
          from_canister_id = switch (x.from_canister_id_index) {
            case (?p) ?mapPrincipal(p);
            case (null) null;
          };
        });
        case (?#rename_canister x) ?#rename_canister({
          canister_id = mapPrincipal(x.canister_id_index);
          total_num_changes = x.total_num_changes;
          requested_by = mapPrincipal(x.requested_by_index);
          rename_to = {
            canister_id = mapPrincipal(x.rename_to.canister_id_index);
            version = x.rename_to.version;
            total_num_changes = x.rename_to.total_num_changes;
          };
        });
      };
    };
  };

};
