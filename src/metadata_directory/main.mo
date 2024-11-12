import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Vec "mo:vector";
import Prim "mo:prim";

actor class () = self {

  public type WasmMetadata = {
    module_hash : Blob;
    description : Text;
    build_instructions : Text;
    latest_update_timestamp : Nat64;
  };

  /// Stores all the metadata.
  ///
  /// 1st dimension - metadata directories divided by the principal.
  ///
  /// 2nd dimension - wasm module metadata records for a principal.
  stable var storage : Vec.Vector<Vec.Vector<WasmMetadata>> = Vec.new();

  /// Map principal to index of the directory managed by the principal.
  let storage_map = RBTree.RBTree<Principal, Nat>(Principal.compare);

  /// Map (principal, module_hash) to index of wasm module metadata record.
  let wasm_modules_map = RBTree.RBTree<(Principal, Blob), Nat>(
    func(
      a : (Principal, Blob),
      b : (Principal, Blob),
    ) {
      switch (Principal.compare(a.0, b.0)) {
        case (#equal) Blob.compare(a.1, b.1);
        case (value) value;
      };
    }
  );

  stable var stable_storage_map = storage_map.share();
  stable var stable_wasm_modules_map = wasm_modules_map.share();

  //
  // API for Metadata directory management
  //

  public shared ({ caller }) func create_directory() {
    if (storage_map.get(caller) != null) throw Error.reject("Metadata directory managed by the caller already exists.");
    let wasm_modules : Vec.Vector<WasmMetadata> = Vec.new();
    storage_map.put(caller, Vec.size(storage));
    Vec.add(storage, wasm_modules);
  };

  /// Checks if the metadata directory exists for the caller.
  public shared query ({ caller }) func check_directory() : async Bool {
    storage_map.get(caller) != null;
  };

  public shared query ({ caller }) func get_wasm_metadata() : async [WasmMetadata] {
    let ?index = storage_map.get(caller) else throw Error.reject("There is no metadata directory managed by the caller.");
    Vec.get(storage, index) |> Vec.toArray(_);
  };

  public shared ({ caller }) func add_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async () {
    let ?index = storage_map.get(caller) else throw Error.reject("There is no metadata directory managed by the caller.");
    let is_valid = Blob.toArray(module_hash).size();
    if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
    if (wasm_modules_map.get((caller, module_hash)) != null) throw Error.reject("The provided module hash already exists.");
    let wasm_modules = Vec.get(storage, index);
    wasm_modules_map.put((caller, module_hash), Vec.size(wasm_modules));
    Vec.add(
      wasm_modules,
      {
        module_hash;
        description = Option.get(description, "");
        build_instructions = Option.get(build_instructions, "");
        latest_update_timestamp = Prim.time();
      },
    );
  };

  public shared ({ caller }) func update_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async () {
    let ?directory_index = storage_map.get(caller) else throw Error.reject("There is no metadata directory managed by the caller.");
    let is_valid = Blob.toArray(module_hash).size();
    if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
    let ?index = wasm_modules_map.get((caller, module_hash)) else throw Error.reject("There is no metadata for the wasm module.");
    let wasm_modules = Vec.get(storage, directory_index);
    let wasm_module_metadata = Vec.get(wasm_modules, index);
    Vec.put(
      wasm_modules,
      index,
      {
        module_hash;
        description = Option.get(description, wasm_module_metadata.description);
        build_instructions = Option.get(build_instructions, wasm_module_metadata.build_instructions);
        latest_update_timestamp = Prim.time();
      },
    );
  };

  //
  // API for Canister dashboard
  //

  public query func find_wasm_metadata(principal : Principal, module_hash : Blob) : async WasmMetadata {
    let ?directory_index = storage_map.get(principal) else throw Error.reject("There is no metadata directory managed by the caller.");
    let ?index = wasm_modules_map.get((principal, module_hash)) else throw Error.reject("There is no metadata for the wasm module.");
    let wasm_modules = Vec.get(storage, directory_index);
    let wasm_module_metadata = Vec.get(wasm_modules, index);
    wasm_module_metadata;
  };

  public query func available_metadata(principals : [Principal], module_hashes : [Blob]) : async [(Principal, Blob)] {
    principals
    |> Array.filter<Principal>(_, func(p : Principal) = storage_map.get(p) != null)
    |> Array.foldLeft<Principal, [(Principal, Blob)]>(
      _,
      [],
      func(acc, p) {
        module_hashes
        |> Array.filter<Blob>(
          module_hashes,
          func(module_hash : Blob) = wasm_modules_map.get((p, module_hash)) != null,
        )
        |> Array.map<Blob, (Principal, Blob)>(_, func(module_hash : Blob) = (p, module_hash))
        |> Array.append(acc, _);
      },
    );
  };

  system func preupgrade() {
    stable_storage_map := storage_map.share();
    stable_wasm_modules_map := wasm_modules_map.share();
  };

  system func postupgrade() {
    storage_map.unshare(stable_storage_map);
    wasm_modules_map.unshare(stable_wasm_modules_map);
  };
};
