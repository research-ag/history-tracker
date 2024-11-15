import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Array "mo:base/Array";
import OrderedMap "mo:base/OrderedMap";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Prim "mo:prim";

actor class () = self {

  public type WasmMetadata = {
    module_hash : Blob;
    description : Text;
    build_instructions : Text;
    latest_update_timestamp : Nat64;
    created_timestamp : Nat64;
  };

  public type PrincipalRecord = {
    var wasm_metadata_storage : OrderedMap.Map<Blob, WasmMetadata>;
  };

  let principalMap = OrderedMap.Make<Principal>(Principal.compare);
  let blobMap = OrderedMap.Make<Blob>(Blob.compare);

  stable var storage : OrderedMap.Map<Principal, PrincipalRecord> = principalMap.empty<PrincipalRecord>();

  //
  // API for Metadata directory management
  //

  public shared query ({ caller }) func get_wasm_metadata() : async [WasmMetadata] {
    let ?pr = principalMap.get(storage, caller) else return [];
    pr.wasm_metadata_storage
    |> blobMap.vals(_)
    |> Iter.toArray(_);
  };

  public shared ({ caller }) func add_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async () {
    let pr = switch (principalMap.get(storage, caller)) {
      case (?value) value;
      case (null) {
        let pr_new : PrincipalRecord = {
          var wasm_metadata_storage = blobMap.empty<WasmMetadata>();
        };
        storage := principalMap.put(storage, caller, pr_new);
        pr_new;
      };
    };
    let is_valid = Blob.toArray(module_hash).size();
    if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
    if (blobMap.get(pr.wasm_metadata_storage, module_hash) != null) throw Error.reject("The provided module hash already exists.");
    pr.wasm_metadata_storage := blobMap.put(
      pr.wasm_metadata_storage,
      module_hash,
      {
        module_hash;
        description = Option.get(description, "");
        build_instructions = Option.get(build_instructions, "");
        latest_update_timestamp = Prim.time();
        created_timestamp = Prim.time();
      },
    );
  };

  public shared ({ caller }) func update_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async () {
    let ?pr = principalMap.get(storage, caller) else throw Error.reject("There is no metadata for the wasm module.");
    let ?wasm_metadata = blobMap.get(pr.wasm_metadata_storage, module_hash) else throw Error.reject("There is no metadata for the wasm module.");
    let is_valid = Blob.toArray(module_hash).size();
    if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
    pr.wasm_metadata_storage := blobMap.put(
      pr.wasm_metadata_storage,
      module_hash,
      {
        module_hash;
        description = Option.get(description, wasm_metadata.description);
        build_instructions = Option.get(build_instructions, wasm_metadata.build_instructions);
        latest_update_timestamp = Prim.time();
        created_timestamp = wasm_metadata.created_timestamp;
      },
    );
  };

  //
  // API for Canister dashboard
  //

  public query func find_wasm_metadata(principal : Principal, module_hash : Blob) : async WasmMetadata {
    let ?pr = principalMap.get(storage, principal) else throw Error.reject("There is no metadata for the wasm module.");
    let ?wasm_metadata = blobMap.get(pr.wasm_metadata_storage, module_hash) else throw Error.reject("There is no metadata for the wasm module.");
    wasm_metadata;
  };

  public query func available_metadata(principals : [Principal], module_hashes : [Blob]) : async [(Principal, Blob)] {
    principals
    |> Array.filter<Principal>(
      _,
      func(p : Principal) = switch (principalMap.get(storage, p)) {
        case (?_) true;
        case (null) false;
      },
    )
    |> Array.foldLeft<Principal, [(Principal, Blob)]>(
      _,
      [],
      func(acc, p) {
        module_hashes
        |> Array.filter<Blob>(
          module_hashes,
          func(module_hash : Blob) {
            let ?pr = principalMap.get(storage, p) else Debug.trap("internal error");
            switch (blobMap.get(pr.wasm_metadata_storage, module_hash)) {
              case (?_) true;
              case (null) false;
            };
          },
        )
        |> Array.map<Blob, (Principal, Blob)>(_, func(module_hash : Blob) = (p, module_hash))
        |> Array.append(acc, _);
      },
    );
  };
};
