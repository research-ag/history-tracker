import RBTree "mo:base/RBTree";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Vector "mo:vector/Class";
import Vec "mo:vector";
import Prim "mo:prim";

module {

  public type WasmMetadata = {
    module_hash : Blob;
    description : Text;
    build_instructions : Text;
    latest_update_timestamp : Nat64;
  };

  public type StableData = (
    Vec.Vector<WasmMetadata>, // wasm_modules
    RBTree.Tree<Blob, Nat>, // wasm_modules_map
  );

  public func fromStableData(data : StableData) : CMM {
    let cmm = CMM();
    cmm.unshare(data);
    cmm;
  };

  public class CMM() {
    let wasm_modules = Vector.Vector<WasmMetadata>();
    let wasm_modules_map = RBTree.RBTree<Blob, Nat>(Blob.compare);

    /// Returns all the Wasm metadata.
    public func wasm_metadata() : [WasmMetadata] = Vector.toArray(wasm_modules);

    /// Returns one metadata item by module hash.
    public func wasm_metadata_by_hash(module_hash : Blob) : ?WasmMetadata {
      let ?index = wasm_modules_map.get(module_hash) else return null;
      ?wasm_modules.get(index);
    };

    /// Adds one Wasm metadata item.
    public func add_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async* () {
      let is_valid = Blob.toArray(module_hash).size();
      if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
      wasm_modules_map.put(module_hash, wasm_modules.size());
      wasm_modules.add({
        module_hash;
        description = Option.get(description, "");
        build_instructions = Option.get(build_instructions, "");
        latest_update_timestamp = Prim.time();
      });
    };

    /// Updates one Wasm metadata item.
    public func update_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async* () {
      let is_valid = Blob.toArray(module_hash).size();
      if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
      let ?index = wasm_modules_map.get(module_hash) else throw Error.reject("There is no metadata for the wasm module.");
      let wasm_module_metadata = wasm_modules.get(index);
      wasm_modules.put(
        index,
        {
          module_hash;
          description = Option.get(description, wasm_module_metadata.description);
          build_instructions = Option.get(build_instructions, wasm_module_metadata.build_instructions);
          latest_update_timestamp = Prim.time();
        },
      );
    };

    public func share() : StableData {
      (wasm_modules.share(), wasm_modules_map.share());
    };

    public func unshare(data : StableData) {
      wasm_modules.unshare(data.0);
      wasm_modules_map.unshare(data.1);
    };
  };
};
