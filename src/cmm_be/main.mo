import Principal "mo:base/Principal";
import RBTree "mo:base/RBTree";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Vector "mo:vector/Class";
import Vec "mo:vector";

import CMM "cmm";

/// CMM, Controller-managed metadata
actor class () = self {
  public type StableData = (
    [CMM.StableData], // cmm_storage
    RBTree.Tree<Principal, Nat>, // cmm_storage_map
  );

  /// Converts `cmm_storage` to stable type.
  func convert_cmm_to_stable(data : Vector.Vector<CMM.CMM>) : [CMM.StableData] {
    data.vals()
    |> Iter.map<CMM.CMM, CMM.StableData>(_, func(v) = v.share())
    |> Iter.toArray(_);
  };

  let cmm_storage = Vector.Vector<CMM.CMM>();
  let cmm_storage_map = RBTree.RBTree<Principal, Nat>(Principal.compare);

  stable var stable_data : StableData = (convert_cmm_to_stable(cmm_storage), cmm_storage_map.share());

  public shared ({ caller }) func createCMM() {
    if (cmm_storage_map.get(caller) != null) throw Error.reject("Metadata managed by the caller already exists.");
    let new_cmm = CMM.CMM();
    cmm_storage.add(new_cmm);
    let last_index : Nat = cmm_storage.size() - 1;
    cmm_storage_map.put(caller, last_index);
  };

  /// Checks if CMM exists for the caller.
  public shared query ({ caller }) func checkCMM() : async Bool {
    cmm_storage_map.get(caller) != null;
  };

  public shared query ({ caller }) func wasm_metadata() : async [CMM.WasmMetadata] {
    let ?index = cmm_storage_map.get(caller) else throw Error.reject("There is no metadata managed by the caller.");
    cmm_storage.get(index).wasm_metadata();
  };

  public query func wasm_metadata_by_principal(p : Principal) : async [CMM.WasmMetadata] {
    let ?index = cmm_storage_map.get(p) else throw Error.reject("There is no metadata managed by the principal.");
    cmm_storage.get(index).wasm_metadata();
  };

  /// Returns principals managing metadata.
  public query func check_principals(p_list : [Principal]) : async [Principal] {
    Array.filter<Principal>(p_list, func(p : Principal) = cmm_storage_map.get(p) != null);
  };

  public shared ({ caller }) func add_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async () {
    let ?index = cmm_storage_map.get(caller) else throw Error.reject("There is no metadata managed by the caller.");
    await* cmm_storage.get(index).add_wasm_metadata(module_hash, description, build_instructions);
  };

  public shared ({ caller }) func update_wasm_metadata(module_hash : Blob, description : ?Text, build_instructions : ?Text) : async () {
    let ?index = cmm_storage_map.get(caller) else throw Error.reject("There is no metadata managed by the caller.");
    await* cmm_storage.get(index).update_wasm_metadata(module_hash, description, build_instructions);
  };

  system func preupgrade() {
    stable_data := (convert_cmm_to_stable(cmm_storage), cmm_storage_map.share());
  };

  system func postupgrade() {
    cmm_storage.unshare(
      (stable_data.0)
      |> Iter.fromArray(_)
      |> Iter.map<CMM.StableData, CMM.CMM>(
        _,
        func(v) = CMM.fromStableData(v),
      )
      |> Vec.fromIter(_)
    );

    cmm_storage_map.unshare(stable_data.1);
  };
};
