import IC "../ic";

module {
  let ic = actor "aaaaa-aa" : IC.Management;
  public type Arg = IC.CanisterInfoRequest;
  public type Response = IC.CanisterInfoResponse;
  public let f = ic.canister_info;
};
