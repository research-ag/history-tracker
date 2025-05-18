import IC "ic";

module {
  let ic = actor "aaaaa-aa" : IC.Management;
  public type S = IC.CanisterInfoRequest;
  public type T = IC.CanisterInfoResponse;
  public let f = ic.canister_info;
};
