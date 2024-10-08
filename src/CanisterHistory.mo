import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Prim "mo:prim";

import IC "ic"

module {
  // For changes stored in our canister
  type ExtendedChange = IC.CanisterChange and {
    change_index : Nat;
  };

  // For public view of changes
  type PublicChange = ExtendedChange and {
    build_instructions : Text;
  };

  type ModuleHashMetadata = {
    build_instructions : Text;
  };

  type CanisterMetadata = {
    var name : Text;
    var description : Text;
    var latest_update_timestamp : Nat64;
    module_hash_metadata : RBTree.RBTree<[Nat8], ModuleHashMetadata>;
    module_hash_index : RBTree.RBTree<Nat64, [Nat8]>; // for sorting optimization
  };

  type InternalState = {
    changes : RBTree.RBTree<Nat, ExtendedChange>; // all tracked changes
    var latest_change_timestamp : Nat64; // latest tracked change timestamp
    var total_num_changes : Nat64; // total number of changes
    var module_hash : ?[Nat8]; // current module hash
    var controllers : [Principal]; // current controllers
    var timestamp_nanos : Nat64; // latest sync timestamp
    var sync_version : Nat; // sync version (nubmer of syncs)
    var metadata : CanisterMetadata;
  };

  public type StableCanisterMetadata = {
    name : Text;
    description : Text;
    latest_update_timestamp : Nat64;
    module_hash_metadata : RBTree.Tree<[Nat8], ModuleHashMetadata>;
    module_hash_index : RBTree.Tree<Nat64, [Nat8]>;
  };

  public type StableData = {
    changes : RBTree.Tree<Nat, ExtendedChange>;
    latest_change_timestamp : Nat64;
    total_num_changes : Nat64;
    module_hash : ?[Nat8];
    controllers : [Principal];
    timestamp_nanos : Nat64;
    sync_version : Nat;
    metadata : StableCanisterMetadata;
    // * for remembering associated canister id
    canister_id : Principal;
  };

  public type CanisterChangesResponse = {
    changes : [PublicChange];
    total_num_changes : Nat64;
    timestamp_nanos : Nat64;
    sync_version : Nat;
  };

  public type CanisterStateResponse = {
    module_hash : ?[Nat8];
    controllers : [Principal];
    timestamp_nanos : Nat64;
    sync_version : Nat;
  };

  public type PublicModuleHashMetadata = {
    module_hash : [Nat8];
    first_found_timestamp : Nat64;
  } and ModuleHashMetadata;

  public type CanisterMetadataResponse = {
    name : Text;
    description : Text;
    latest_update_timestamp : Nat64;
    module_hash_metadata : [PublicModuleHashMetadata];
  };

  public type UpdateModuleHashMetadataPayload = {
    module_hash : [Nat8];
    build_instructions : Text;
  };

  public func fromStableData(data : StableData) : CanisterHistory {
    let history = CanisterHistory(data.canister_id);
    history.unshare(data);
    history;
  };

  public class CanisterHistory(canister_id : Principal) {

    let internal_state : InternalState = {
      changes = RBTree.RBTree<Nat, ExtendedChange>(Nat.compare);
      var latest_change_timestamp = 0;
      var total_num_changes = 0;
      var module_hash = null;
      var controllers = [];
      var timestamp_nanos = 0;
      var sync_version = 0;
      var metadata = {
        var name = "";
        var description = "";
        var latest_update_timestamp = 0;
        module_hash_metadata = RBTree.RBTree<[Nat8], ModuleHashMetadata>(func(a : [Nat8], b : [Nat8]) = #equal);
        module_hash_index = RBTree.RBTree<Nat64, [Nat8]>(Nat64.compare);
      };
    };

    let ic = actor "aaaaa-aa" : IC.Management;

    var sync_ongoing = false;

    public func sync() : async* () {
      if (sync_ongoing) throw Error.reject("Synchronization is already in progress.");

      sync_ongoing := true;

      let info = await ic.canister_info({
        canister_id;
        num_requested_changes = ?Nat64.fromNat(20);
      });

      let changes_size = info.recent_changes.size();
      var cur_change_index : Nat = Nat64.toNat(info.total_num_changes) - changes_size + 1;

      // Merge untracked changes with already saved ones
      for (change in Iter.fromArray(info.recent_changes)) {
        if (change.timestamp_nanos > internal_state.latest_change_timestamp) {
          // Insert new change to history
          internal_state.changes.put(
            cur_change_index,
            {
              change with
              change_index = cur_change_index;
            },
          );
          internal_state.latest_change_timestamp := change.timestamp_nanos;

          // Insert new metadata item if the module hash is new
          // (only applicable for deployment changes)
          switch (change.details) {
            case (#code_deployment(r)) {
              let module_hash = Blob.toArray(r.module_hash);
              let metadata = internal_state.metadata.module_hash_metadata;
              let index = internal_state.metadata.module_hash_index;
              switch (metadata.get(module_hash)) {
                case (null) {
                  metadata.put(module_hash, { build_instructions = "" });
                  index.put(change.timestamp_nanos, module_hash);
                };
                case (?_) {};
              };
            };
            case (_) {};
          };
        };
        cur_change_index += 1;
      };

      internal_state.total_num_changes := info.total_num_changes;
      internal_state.module_hash := info.module_hash;
      internal_state.controllers := info.controllers;
      internal_state.timestamp_nanos := Prim.time();
      internal_state.sync_version += 1;

      sync_ongoing := false;
    };

    public func canister_changes() : CanisterChangesResponse {
      internal_state.changes.entries()
      |> Iter.map<(Nat, ExtendedChange), PublicChange>(
        _,
        func((_, extended_change)) = {
          extended_change with
          build_instructions = switch (extended_change.details) {
            case (#code_deployment(r)) {
              let module_hash = Blob.toArray(r.module_hash);
              let metadata = internal_state.metadata.module_hash_metadata;
              switch (metadata.get(module_hash)) {
                case (null) {
                  // TODO: Reconsider the logic (when the times comes).
                  //
                  // ***
                  //
                  // It's expected that such a case is impossible.
                  // Therefore, it's quite logical for us to throw trap here.
                  //
                  // However, it should be taken into account that there are canisters that
                  // started to be tracked before the implementation of the module hash metadata.
                  // So there could potentially be module hashes without a corresponding
                  // metadata record created (they are created during synchronization
                  // when new module hashes are found).
                  //
                  // Potential solutions: 
                  // 1) Wipe state; // I think this one because anyway it should be reinstalled.
                  // 2) Migration;
                  // 3) Introduce a mechanism that allows to resync: go through all deployment changes
                  //    and create the necessary metadata records.
                  //

                  // Debug.trap("internal error");

                  "";
                };
                case (?v) v.build_instructions;
              };
            };
            case (_) "";
          };
        },
      )
      |> Iter.toArray(_)
      |> {
        changes = _;
        total_num_changes = internal_state.total_num_changes;
        timestamp_nanos = internal_state.timestamp_nanos;
        sync_version = internal_state.sync_version;
      };
    };

    public func canister_state() : CanisterStateResponse {
      {
        module_hash = internal_state.module_hash;
        controllers = internal_state.controllers;
        timestamp_nanos = internal_state.timestamp_nanos;
        sync_version = internal_state.sync_version;
      };
    };

    public func metadata() : CanisterMetadataResponse {
      let module_hash_metadata : [PublicModuleHashMetadata] = internal_state.metadata.module_hash_index.entries()
      |> (
        Iter.map(
          _,
          func(r : (Nat64, [Nat8])) : PublicModuleHashMetadata {
            switch (internal_state.metadata.module_hash_metadata.get(r.1)) {
              case (null) Debug.trap("internal error");
              case (?v) {
                {

                  module_hash = r.1;
                  first_found_timestamp = r.0;
                  build_instructions = v.build_instructions;
                };
              };
            };

          },
        )
      )
      |> Iter.toArray(_);

      {
        name = internal_state.metadata.name;
        description = internal_state.metadata.description;
        latest_update_timestamp = internal_state.metadata.latest_update_timestamp;
        module_hash_metadata;
      };
    };

    func check_controller(p : Principal) : async* Bool {
      let info = try {
        await ic.canister_info({
          canister_id;
          num_requested_changes = ?Nat64.fromNat(0);
        });
      } catch (_) throw Error.reject("canister_info error.");
      Array.find<Principal>(info.controllers, func c = c == p) != null;
    };

    public func update_metadata(caller : Principal, name : ?Text, description : ?Text) : async* () {
      let is_controller = await* check_controller(caller);
      if (not is_controller) throw Error.reject("Access denied.");

      switch (name) {
        case null {};
        case (?value) {
          internal_state.metadata.name := value;
        };
      };

      switch (description) {
        case null {};
        case (?value) {
          internal_state.metadata.description := value;
        };
      };

      internal_state.metadata.latest_update_timestamp := Prim.time();
    };

    public func update_module_hash_metadata(caller : Principal, payload : UpdateModuleHashMetadataPayload) : async* () {
      let is_controller = await* check_controller(caller);
      if (not is_controller) throw Error.reject("Access denied.");

      let metadata = internal_state.metadata.module_hash_metadata;
      switch (metadata.get(payload.module_hash)) {
        case (null) throw Error.reject("Metadata record for the provided module hash was not found.");
        case (?metadata_record) {
          metadata.put(
            payload.module_hash,
            {
              metadata_record with
              build_instructions = payload.build_instructions;
            },
          );
        };
      };
    };

    public func share() : StableData {
      internal_state
      |> {
        changes = _.changes.share();
        latest_change_timestamp = _.latest_change_timestamp;
        total_num_changes = _.total_num_changes;
        module_hash = _.module_hash;
        controllers = _.controllers;
        timestamp_nanos = _.timestamp_nanos;
        sync_version = _.sync_version;
        metadata = {
          name = _.metadata.name;
          description = _.metadata.description;
          latest_update_timestamp = _.metadata.latest_update_timestamp;
          module_hash_metadata = _.metadata.module_hash_metadata.share();
          module_hash_index = _.metadata.module_hash_index.share();
        };
        canister_id;
      };
    };

    public func unshare(data : StableData) {
      internal_state.changes.unshare(data.changes);
      internal_state.latest_change_timestamp := data.latest_change_timestamp;
      internal_state.total_num_changes := data.total_num_changes;
      internal_state.module_hash := data.module_hash;
      internal_state.controllers := data.controllers;
      internal_state.timestamp_nanos := data.timestamp_nanos;
      internal_state.sync_version := data.sync_version;

      let module_hash_metadata = RBTree.RBTree<[Nat8], ModuleHashMetadata>(func(a : [Nat8], b : [Nat8]) = #equal);
      module_hash_metadata.unshare(data.metadata.module_hash_metadata);

      let module_hash_index = RBTree.RBTree<Nat64, [Nat8]>(Nat64.compare);
      module_hash_index.unshare(data.metadata.module_hash_index);

      internal_state.metadata := {
        var name = data.metadata.name;
        var description = data.metadata.description;
        var latest_update_timestamp = data.metadata.latest_update_timestamp;
        module_hash_metadata;
        module_hash_index;
      };
    };
  };
};
