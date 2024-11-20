import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Array "mo:base/Array";
import OrderedMap "mo:base/OrderedMap";
import Iter "mo:base/Iter";
import Prim "mo:prim";

actor class () = self {

  public type WasmMetadata = {
    module_hash : Blob;
    description : Text;
    build_instructions : Text;
    latest_update_timestamp : Nat64;
    created_timestamp : Nat64;
  };

  public type WasmMetadataChangePayload = {
    module_hash : Blob;
    description : ?Text;
    build_instructions : ?Text;
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

  public shared query ({ caller }) func wasm_metadata(p : ?Principal) : async [WasmMetadata] {
    let p_to_request = switch (p) {
      case (?value) value;
      case (null) caller;
    };
    let ?pr = principalMap.get(storage, p_to_request) else return [];
    pr.wasm_metadata_storage
    |> blobMap.vals(_)
    |> Iter.toArray(_);
  };

  public shared ({ caller }) func add_wasm_metadata(payload : WasmMetadataChangePayload) : async () {
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
    let is_valid = Blob.toArray(payload.module_hash).size();
    if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
    if (blobMap.get(pr.wasm_metadata_storage, payload.module_hash) != null) throw Error.reject("The provided module hash already exists.");
    pr.wasm_metadata_storage := blobMap.put(
      pr.wasm_metadata_storage,
      payload.module_hash,
      {
        module_hash = payload.module_hash;
        description = Option.get(payload.description, "");
        build_instructions = Option.get(payload.build_instructions, "");
        latest_update_timestamp = Prim.time();
        created_timestamp = Prim.time();
      },
    );
  };

  public shared ({ caller }) func update_wasm_metadata(payload : WasmMetadataChangePayload) : async () {
    let ?pr = principalMap.get(storage, caller) else throw Error.reject("There is no metadata for the wasm module.");
    let ?wasm_metadata = blobMap.get(pr.wasm_metadata_storage, payload.module_hash) else throw Error.reject("There is no metadata for the wasm module.");
    let is_valid = Blob.toArray(payload.module_hash).size();
    if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");
    pr.wasm_metadata_storage := blobMap.put(
      pr.wasm_metadata_storage,
      payload.module_hash,
      {
        module_hash = payload.module_hash;
        description = Option.get(payload.description, wasm_metadata.description);
        build_instructions = Option.get(payload.build_instructions, wasm_metadata.build_instructions);
        latest_update_timestamp = Prim.time();
        created_timestamp = wasm_metadata.created_timestamp;
      },
    );
  };

  //
  // API for Canister dashboard
  //

  public query func find_wasm_metadata(module_hash : Blob, principals : [Principal]) : async [(Principal, WasmMetadata)] {
    Array.foldLeft<Principal, [(Principal, WasmMetadata)]>(
      principals,
      [],
      func(acc, p) {
        let ?pr = principalMap.get(storage, p) else return acc;
        switch (blobMap.get(pr.wasm_metadata_storage, module_hash)) {
          case (?wasm_metadata) Array.append(acc, [(p, wasm_metadata)]);
          case (null) acc;
        };
      },
    );
  };

  func calculate_wasm_metadata_size(wasm_metadata : WasmMetadata) : Nat {
    wasm_metadata
    |> _.module_hash.size() // module_hash
    |> _ + wasm_metadata.description.size() // description
    |> _ + wasm_metadata.build_instructions.size() // build_instructions
    |> _ + 8 // latest_update_timestamp
    |> _ + 8; // created_timestamp

  };

  public query func available_metadata(principals : [Principal], module_hashes : [Blob]) : async [(Principal, Blob, Nat)] {
    Array.foldLeft<Principal, [(Principal, Blob, Nat)]>(
      principals,
      [],
      func(acc, p) {
        let ?pr = principalMap.get(storage, p) else return acc;

        // interpret [] as a wildcard
        if (Array.size(module_hashes) == 0) {
          return pr.wasm_metadata_storage
          |> blobMap.vals(_)
          |> Iter.map<WasmMetadata, (Principal, Blob, Nat)>(
            _,
            func(wasm_metadata) {
              wasm_metadata
              |> (p, _.module_hash, calculate_wasm_metadata_size(_));
            },
          )
          |> Iter.toArray(_)
          |> Array.append(acc, _);
        };

        Array.foldLeft<Blob, [(Principal, Blob, Nat)]>(
          module_hashes,
          [],
          func(acc_2, module_hash) {
            switch (blobMap.get(pr.wasm_metadata_storage, module_hash)) {
              case (?wasm_metadata) {
                [(p, module_hash, calculate_wasm_metadata_size(wasm_metadata))]
                |> Array.append(acc_2, _);
              };
              case (null) acc_2;
            };
          },
        )
        |> Array.append(acc, _);
      },
    );
  };
};
