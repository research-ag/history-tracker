import Iter "mo:core/Iter";
import Option "mo:core/Option";
import Prim "mo:prim";

import Enumeration "mo:stable-trie/Enumeration";

// A wrapper around stable-trie enumeration
module {

  public class StableOrderedSet<T>(
    keySize : Nat,
    serializeValue : T -> Blob,
    deserializeValue : Blob -> ?T,
  ) {

    let storage : Enumeration.Enumeration = Enumeration.Enumeration({
      aridity = 4;
      pointer_size = 4;
      key_size = keySize;
      root_aridity = ?(4 ** 6);
      value_size = 0;
    });

    public func size() : Nat = storage.size();

    public func indexOf(v : T) : ?Nat {
      let ?(_, idx) = storage.lookup(serializeValue(v)) else return null;
      ?idx;
    };

    public func has(v : T) : Bool = Option.isSome(indexOf(v));

    public func put(v : T) : (Nat, Bool) {
      let idx = storage.add(serializeValue(v), "");
      (idx, idx + 1 == size());
    };

    public func get(index : Nat) : ?T {
      let ?(d, _) = storage.get(index) else return null;
      deserializeValue(d);
    };

    public func values() : Iter.Iter<T> {
      storage.keys()
      |> Iter.map<Blob, ?T>(_, deserializeValue)
      |> Iter.filter<?T>(_, func x = Option.isSome(x))
      |> Iter.map<?T, T>(
        _,
        func xopt {
          let ?x = xopt else Prim.trap("Can never happen");
          x;
        },
      );
    };

    public func memoryStats() : Enumeration.MemoryStats = storage.memoryStats();

    public func share() : Enumeration.StableData = storage.share();
    public func unshare(v : Enumeration.StableData) = storage.unshare(v);

  };

};
