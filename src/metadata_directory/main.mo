import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Array "mo:base/Array";
import OrderedMap "mo:base/OrderedMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Vector "mo:vector/Class";
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

  func validate_change_payload(payload : WasmMetadataChangePayload) : async* () {
    let is_valid = Blob.toArray(payload.module_hash).size();
    if (is_valid != 32) throw Error.reject("Provided module hash is not valid.");

    func validate_maximum_length(text : ?Text, max : Nat) : async* () {
      switch (text) {
        case (?value) {
          if (value.size() > max) {
            let error_msg = "Description exceeds the maximum allowed length of " # Nat.toText(max) # " characters.";
            throw Error.reject(error_msg);
          };
        };
        case (null) {};
      };
    };

    await* validate_maximum_length(payload.description, 100);
    await* validate_maximum_length(payload.build_instructions, 1000);
  };

  public shared ({ caller }) func add_wasm_metadata(payload : WasmMetadataChangePayload) : async () {
    await* validate_change_payload(payload);
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
    if (blobMap.contains(pr.wasm_metadata_storage, payload.module_hash)) throw Error.reject("The provided module hash already exists.");
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
    await* validate_change_payload(payload);
    let ?pr = principalMap.get(storage, caller) else throw Error.reject("There is no metadata for the wasm module.");
    let ?wasm_metadata = blobMap.get(pr.wasm_metadata_storage, payload.module_hash) else throw Error.reject("There is no metadata for the wasm module.");
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
    let result = Vector.Vector<(Principal, WasmMetadata)>();

    label loop_1 for (p in Iter.fromArray(principals)) {
      let ?pr = principalMap.get(storage, p) else continue loop_1;
      let ?wasm_metadata = blobMap.get(pr.wasm_metadata_storage, module_hash) else continue loop_1;
      result.add((p, wasm_metadata));
    };

    Vector.toArray(result);
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
    let result = Vector.Vector<(Principal, Blob, Nat)>();

    label loop_1 for (p in Iter.fromArray(principals)) {
      let ?pr = principalMap.get(storage, p) else continue loop_1;

      // interpret [] as a wildcard
      if (Array.size(module_hashes) == 0) {
        let iter = blobMap.vals(pr.wasm_metadata_storage);
        for (wasm_metadata in iter) {
          wasm_metadata
          |> (p, _.module_hash, calculate_wasm_metadata_size(_))
          |> result.add(_);
        };
        continue loop_1;
      };

      // general case
      label loop_2 for (module_hash in Iter.fromArray(module_hashes)) {
        let ?wasm_metadata = blobMap.get(pr.wasm_metadata_storage, module_hash) else continue loop_2;
        wasm_metadata
        |> (p, _.module_hash, calculate_wasm_metadata_size(_))
        |> result.add(_);
      };
    };

    Vector.toArray(result);
  };
};
