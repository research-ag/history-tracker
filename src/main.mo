import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";

import IC "ic"

actor class CanisterHistory(canisterId_ : Principal) = self {
  let ic = actor "aaaaa-aa" : IC.Management;

  public func canisterInfo() : async IC.CanisterInfoResponse {
    await ic.canister_info({
      canister_id = canisterId_;
      num_requested_changes = ?Nat64.fromNat(20);
    });
  };

  public func canisterId() : async Principal {
    canisterId_;
  };

};
