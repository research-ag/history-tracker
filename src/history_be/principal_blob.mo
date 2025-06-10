import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";

/// Functions to convert principal to fixed-length blob (with size 32) and back.
/// Copied from https://github.com/research-ag/icrc-84/blob/main/src/lib.mo
module {

  public func toBlob(p : Principal) : Blob {
    let bytes = Blob.toArray(Principal.toBlob(p));
    let size = bytes.size();

    assert size <= 29;

    Array.tabulate<Nat8>(
      32,
      func(i : Nat) : Nat8 {
        if (i + size < 31) {
          0;
        } else if (i + size == 31) {
          Nat8.fromNat(size);
        } else {
          bytes[i + size - 32];
        };
      },
    ) |> Blob.fromArray(_);
  };

  public func toPrincipal(blob : Blob) : ?Principal {
    let bytes = Blob.toArray(blob);
    assert bytes.size() == 32;

    let (start, size) = do {
      var i = 0;
      label L while (i < 32) {
        if (bytes[i] != 0) break L;
        i += 1;
      };
      if (i == 32) return null;
      (i + 1, Nat8.toNat(bytes[i]));
    };

    if (start + size != 32) return null;
    Array.tabulate(size, func(i : Nat) : Nat8 = bytes[start + i])
    |> Blob.fromArray(_)
    |> ?Principal.fromBlob(_);
  };
};
