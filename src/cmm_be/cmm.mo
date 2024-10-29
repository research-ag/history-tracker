import RBTree "mo:base/RBTree";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Vector "mo:vector/Class";
import Prim "mo:prim";

module {

  type WasmMetadata = {
    description : Text;
    build_instructions : Text;
    latest_update_timestamp : Nat64;
  };

  type StableData = (
    RBTree.Tree<Text, WasmMetadata>, // wasm_modules
  );

  public class ControllerManagedMetadata() {
    let wasm_modules = Vector.Vector<WasmMetadata>();
    let wasm_modules_map = RBTree.RBTree<Blob, Nat>(Blob.compare);

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
