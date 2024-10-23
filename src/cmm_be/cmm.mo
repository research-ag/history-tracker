import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Vector "mo:vector/Class";
import Prim "mo:prim";

import IC "ic"

module {
  type CanisterMetadata = {
    name : Text;
    description : Text;
    latest_update_timestamp : Nat64;
  };

  type WasmMetadata = {
    description : Text;
    build_instructions : Text;
    latest_update_timestamp : Nat64;
  };

  type StableData = (
    RBTree.Tree<Principal, CanisterMetadata>, // canisters
    RBTree.Tree<Text, WasmMetadata>, // wasm_modules
  );

  type History = actor {
    is_canister_tracked : query (Principal) -> async Bool;
  };

  public class ControllerManagedMetadata(
    p : Principal, // controller principal
    history_canister_id : Principal, // history backend canister id
  ) {
    let canisters = Vector.Vector<CanisterMetadata>();
    let canisters_map = RBTree.RBTree<Principal, Nat>(Principal.compare);

    let wasm_modules = Vector.Vector<WasmMetadata>();
    let wasm_modules_map = RBTree.RBTree<Blob, Nat>(Blob.compare);

    let ic = actor "aaaaa-aa" : IC.Management;

    let history = actor (Principal.toText(history_canister_id)) : History;

    func check_controller(canister_id : Principal) : async* Bool {
      let info = try {
        await ic.canister_info({
          canister_id;
          num_requested_changes = ?Nat64.fromNat(0);
        });
      } catch (_) throw Error.reject("canister_info error.");
      Array.find<Principal>(info.controllers, func c = c == p) != null;
    };

    public func add_canister_metadata(canister_id : Principal) : async* () {
      let tracked = await history.is_canister_tracked(canister_id);
      if (not tracked) throw Error.reject("Canister must be registered in HistoryTracker.");
      let is_controller = await* check_controller(canister_id);
      if (not is_controller) throw Error.reject("Access denied. You are not a controller of the canister.");
      canisters_map.put(canister_id, canisters.size());
      canisters.add({
        name = "";
        description = "";
        latest_update_timestamp = Prim.time();
      });
    };

    public func update_canister_metadata(canister_id : Principal, name : ?Text, description : ?Text) : async* () {
      let ?index = canisters_map.get(canister_id) else throw Error.reject("There is no metadata for the canister.");
      let canister_metadata = canisters.get(index);
      canisters.put(
        index,
        {
          name = Option.get(name, canister_metadata.name);
          description = Option.get(description, canister_metadata.description);
          latest_update_timestamp = Prim.time();
        },
      );
    };

    public func canister_metadata() : [CanisterMetadata] = Vector.toArray(canisters);

    public func canister_metadata_by_id(canister_id : Principal) : async* CanisterMetadata {
      let ?index = canisters_map.get(canister_id) else throw Error.reject("There is no metadata for the canister.");
      canisters.get(index);
    };

    public func add_wasm_metadata(module_hash : Blob) : async* () {
      let is_valid = Blob.toArray(module_hash).size();
      if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
      wasm_modules_map.put(module_hash, wasm_modules.size());
      wasm_modules.add({
        description = "";
        build_instructions = "";
        latest_update_timestamp = Prim.time();
      });
    };

    public func update_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async* () {
      let is_valid = Blob.toArray(module_hash).size();
      if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
      let ?index = wasm_modules_map.get(module_hash) else throw Error.reject("There is no metadata for the wasm module.");
      let wasm_module_metadata = wasm_modules.get(index);
      wasm_modules.put(
        index,
        {
          description = Option.get(description, wasm_module_metadata.description);
          build_instructions = Option.get(build_instructions, wasm_module_metadata.build_instructions);
          latest_update_timestamp = Prim.time();
        },
      );
    };

    public func wasm_metadata() : [WasmMetadata] = Vector.toArray(wasm_modules);

    public func wasm_metadata_by_id(module_hash : Blob) : async* WasmMetadata {
      let ?index = wasm_modules_map.get(module_hash) else throw Error.reject("There is no metadata for the wasm module.");
      wasm_modules.get(index);
    };
  };
};
