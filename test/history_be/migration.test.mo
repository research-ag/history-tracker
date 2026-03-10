import Prim "mo:prim";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import EC "../../src/history_be/history/extended_change";

// ================== StableExtendedChange deserialization tests ==================
type StableExtendedChangeLatest = EC.StableExtendedChange;

type StableExtendedChangeV1 = {
  change_index : Nat;
  timestamp_nanos : Nat64;
  canister_version : Nat64;
  origin : {
    #from_user : {
      user_id_index : Nat;
    };
    #from_canister : {
      canister_id_index : Nat;
      canister_version : ?Nat64;
    };
  };
  details : {
    #creation : {
      controller_indexes : [Nat];
    };
    #code_deployment : {
      mode : {
        #reinstall;
        #upgrade;
        #install;
      };
      module_hash_index : Nat;
    };
    #controllers_change : {
      controller_indexes : [Nat];
    };
    #code_uninstall;
    #load_snapshot : {
      canister_version : Nat64;
      snapshot_id : Blob;
      taken_at_timestamp : Nat64;
    };
  };
};

func convertV1(c : StableExtendedChangeV1) : StableExtendedChangeLatest {
  let ?ret : ?StableExtendedChangeLatest = from_candid (to_candid (c)) else Prim.trap("Cannot deserialize!");
  ret;
};

// ========== Case 1: origin=#from_user, details=#creation ==========
var data = convertV1({
  change_index = 123;
  timestamp_nanos = 12345 : Nat64;
  canister_version = 2 : Nat64;
  origin = #from_user({ user_id_index = 56 });
  details = #creation({ controller_indexes = [0, 1] });
});
assert data.change_index == 123;
assert data.timestamp_nanos == (12345 : Nat64);
assert data.canister_version == (2 : Nat64);
switch (data.origin) {
  case (#from_user { user_id_index }) {
    assert user_id_index == 56;
  };
  case (_) Prim.trap("origin is not #from_user");
};
switch (data.details) {
  case (#creation { controller_indexes }) {
    assert Array.equal<Nat>(controller_indexes, [0, 1], Nat.equal);
  };
  case (_) Prim.trap("details is not #creation");
};

// ========== Case 2: origin=#from_canister (some version), details=#controllers_change ==========
data := convertV1({
  change_index = 5;
  timestamp_nanos = 111 : Nat64;
  canister_version = 3 : Nat64;
  origin = #from_canister({
    canister_id_index = 7;
    canister_version = ?(9 : Nat64);
  });
  details = #controllers_change({ controller_indexes = [2, 3, 5] });
});
switch (data.origin) {
  case (#from_canister { canister_id_index; canister_version }) {
    assert canister_id_index == 7;
    switch (canister_version) {
      case (?(v)) { assert v == (9 : Nat64) };
      case (null) Prim.trap("case2: expected some canister_version");
    };
  };
  case (_) Prim.trap("case2: origin is not #from_canister");
};
switch (data.details) {
  case (#controllers_change { controller_indexes }) {
    assert Array.equal<Nat>(controller_indexes, [2, 3, 5], Nat.equal);
  };
  case (_) Prim.trap("case2: details is not #controllers_change");
};

// ========== Case 3: origin=#from_canister (null version) ==========
data := convertV1({
  change_index = 6;
  timestamp_nanos = 222 : Nat64;
  canister_version = 4 : Nat64;
  origin = #from_canister({ canister_id_index = 8; canister_version = null });
  details = #code_uninstall;
});
switch (data.origin) {
  case (#from_canister { canister_id_index; canister_version }) {
    assert canister_id_index == 8;
    assert canister_version == null;
  };
  case (_) Prim.trap("case3: origin is not #from_canister");
};
switch (data.details) {
  case (#code_uninstall) { /* ok */ };
  case (_) Prim.trap("case3: details is not #code_uninstall");
};

// ========== Case 4: details=#code_deployment install ==========
data := convertV1({
  change_index = 7;
  timestamp_nanos = 333 : Nat64;
  canister_version = 5 : Nat64;
  origin = #from_user({ user_id_index = 10 });
  details = #code_deployment({ mode = #install; module_hash_index = 42 });
});
switch (data.details) {
  case (#code_deployment { mode; module_hash_index }) {
    switch (mode) {
      case (#install) {};
      case (_) Prim.trap("case4: mode not #install");
    };
    assert module_hash_index == 42;
  };
  case (_) Prim.trap("case4: details is not #code_deployment");
};

// ========== Case 5: details=#code_deployment upgrade ==========
data := convertV1({
  change_index = 8;
  timestamp_nanos = 444 : Nat64;
  canister_version = 6 : Nat64;
  origin = #from_user({ user_id_index = 11 });
  details = #code_deployment({ mode = #upgrade; module_hash_index = 43 });
});
switch (data.details) {
  case (#code_deployment { mode; module_hash_index }) {
    switch (mode) {
      case (#upgrade) {};
      case (_) Prim.trap("case5: mode not #upgrade");
    };
    assert module_hash_index == 43;
  };
  case (_) Prim.trap("case5: details is not #code_deployment");
};

// ========== Case 6: details=#code_deployment reinstall ==========
data := convertV1({
  change_index = 9;
  timestamp_nanos = 555 : Nat64;
  canister_version = 7 : Nat64;
  origin = #from_user({ user_id_index = 12 });
  details = #code_deployment({ mode = #reinstall; module_hash_index = 44 });
});
switch (data.details) {
  case (#code_deployment { mode; module_hash_index }) {
    switch (mode) {
      case (#reinstall) {};
      case (_) Prim.trap("case6: mode not #reinstall");
    };
    assert module_hash_index == 44;
  };
  case (_) Prim.trap("case6: details is not #code_deployment");
};

// ========== Case 7: details=#load_snapshot (V1 had no from_canister_id_index) ==========
data := convertV1({
  change_index = 10;
  timestamp_nanos = 666 : Nat64;
  canister_version = 8 : Nat64;
  origin = #from_user({ user_id_index = 13 });
  details = #load_snapshot({
    canister_version = 77 : Nat64;
    snapshot_id = Blob.fromArray([1, 2, 3] : [Nat8]);
    taken_at_timestamp = 999 : Nat64;
  });
});
switch (data.details) {
  case (#load_snapshot x) {
    assert x.canister_version == (77 : Nat64);
    assert Blob.equal(x.snapshot_id, Blob.fromArray([1, 2, 3] : [Nat8]));
    assert x.taken_at_timestamp == (999 : Nat64);
    // Field added in latest stable type should default to null when decoding V1
    assert x.from_canister_id_index == null;
  };
  case (_) Prim.trap("case7: details is not #load_snapshot");
};
