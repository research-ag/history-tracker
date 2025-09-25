import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";

/// Functions to convert principal to fixed-length blob (with size 30) and back.
module {

  public func toBlob(p : Principal) : Blob {
    let bytes = Blob.toArray(Principal.toBlob(p));
    let size = bytes.size();

    assert size <= 29;

    Array.tabulate<Nat8>(
      30,
      func(i : Nat) : Nat8 {
        if (i == 0) {
          Nat8.fromNat(size);
        } else if (i <= size) {
          bytes[i - 1];
        } else {
          0;
        };
      },
    ) |> Blob.fromArray(_);
  };

  public func toPrincipal(blob : Blob) : ?Principal {
    let bytes = Blob.toArray(blob);
    assert bytes.size() == 30;

    let size = bytes[0];
    assert size <= 29;

    Array.tabulate<Nat8>(Nat8.toNat(size), func i = bytes[i + 1])
    |> Blob.fromArray(_)
    |> ?Principal.fromBlob(_);
  };
};
