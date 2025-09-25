/// A module containing canister metadata
module Metadata {
  public type Metadata = {
    var name : Text;
    var description : Text;
    var latest_update_timestamp : Nat64;
  };

  public type SharedMetadata = {
    name : Text;
    description : Text;
    latest_update_timestamp : Nat64;
  };

  public func shareMetadata(md : Metadata) : SharedMetadata = {
    name = md.name;
    description = md.description;
    latest_update_timestamp = md.latest_update_timestamp;
  };

  public func new() : Metadata = {
    var name = "";
    var description = "";
    var latest_update_timestamp = 0 : Nat64;
  };
};
