import Iter "mo:core/Iter";
import List "mo:core/List";
import Option "mo:core/Option";
import Queue "mo:core/Queue";

import Prim "mo:prim";

module {

  // interface
  public type RoundRobinSource<T> = Iter.Iter<T> and {
    ctr : () -> Nat;
    round : () -> Nat;
    size : () -> Nat;
    itemsRemaining : () -> Nat;

    // start viewing elements one by one, do not touch the progress pointer
    // returns item index and item
    view : () -> Iter.Iter<(Nat, T)>;
    // update pointer
    setCtr : Nat -> ();

    resetProgress : () -> ();
  };

  public type RoundRobinBufferData<T> = {
    items : List.List<T>;
    ctr : Nat;
    round : Nat;
  };

  // A storage with ability to loop over elements, preserving cursor. After running out of items, emits null once and starts from the beginning
  // Compatible with Iter.Iter<T> ({ next : () -> ?T })
  public class RoundRobinBuffer<T>(data : ?RoundRobinBufferData<T>) = {

    var ctr_ : Nat = 0;
    var round_ : Nat = 0;
    var items_ : List.List<T> = List.empty();

    public func ctr() : Nat = ctr_;
    public func round() : Nat = round_;

    public func size() : Nat = List.size(items_);

    public func itemsRemaining() : Nat {
      let size_ = List.size(items_);
      if (ctr_ > size_) {
        Prim.trap("Ctr cannot be greater than size in RoundRobinBuffer");
      };
      size_ - ctr_;
    };

    public func next() : ?T {
      if (ctr_ < List.size(items_)) {
        let ?item = List.get(items_, ctr_) else Prim.trap("");
        ctr_ += 1;
        return ?item;
      } else if (ctr_ > 0) {
        round_ += 1;
        ctr_ := 0;
      };
      return null;
    };

    public func view() : Iter.Iter<(Nat, T)> {
      let baseCtr = ctr_;
      var i = 0;
      {
        next = func() : ?(Nat, T) {
          let ctr = baseCtr + i;
          if (ctr < List.size(items_)) {
            i += 1;
            let ?item = List.get(items_, ctr) else Prim.trap("");
            return ?(ctr, item);
          };
          null;
        };
      };
    };

    public func setCtr(ctr : Nat) {
      ctr_ := ctr;
      if (ctr_ >= List.size(items_)) {
        round_ += 1;
        ctr_ := 0;
      };
    };

    public func getItem(index : Nat) : T {
      let ?item = List.get(items_, index) else Prim.trap("");
      item;
    };

    public func insertItem(item : T) {
      List.add(items_, item);
    };

    public func hasItem(item : T, equal : (T, T) -> Bool) : Bool {
      not Option.isNull(List.indexOf(items_, equal, item));
    };

    public func resetProgress() {
      round_ := 0;
      ctr_ := 0;
    };

    public func share() : RoundRobinBufferData<T> = {
      items = items_;
      ctr = ctr_;
      round = round_;
    };

    public func unshare(data : RoundRobinBufferData<T>) {
      items_ := data.items;
      ctr_ := data.ctr;
      round_ := data.round;
    };

    switch (data) {
      case (?d) unshare(d);
      case (_) {};
    };
  };

  public type RoundRobinGeneratorData = {
    size : Nat;
    ctr : Nat;
    round : Nat;
  };

  // Works like RoundRobinBuffer<Nat>, but produces consecutive nat-s from 0 to size_ - 1
  public class RoundRobinNatGenerator(data : ?RoundRobinGeneratorData) {
    var ctr_ : Nat = 0;
    var round_ : Nat = 0;
    var size_ : Nat = 0;

    public func ctr() : Nat = ctr_;
    public func round() : Nat = round_;

    public func size() : Nat = size_;
    public func setSize(v : Nat) = size_ := v;

    public func itemsRemaining() : Nat {
      if (ctr_ > size_) {
        Prim.trap("Ctr cannot be greater than size in RoundRobinNatGenerator");
      };
      size_ - ctr_;
    };

    public func next() : ?Nat {
      if (ctr_ < size_) {
        let item = ctr_;
        ctr_ += 1;
        return ?item;
      } else if (ctr_ > 0) {
        round_ += 1;
        ctr_ := 0;
      };
      return null;
    };

    public func view() : Iter.Iter<(Nat, Nat)> {
      let baseCtr = ctr_;
      var i = 0;
      {
        next = func() : ?(Nat, Nat) {
          let ctr = baseCtr + i;
          if (ctr < size_) {
            i += 1;
            return ?(ctr, ctr);
          };
          null;
        };
      };
    };

    public func setCtr(ctr : Nat) {
      ctr_ := ctr;
      if (ctr_ >= size_) {
        round_ += 1;
        ctr_ := 0;
      };
    };

    public func resetProgress() {
      round_ := 0;
      ctr_ := 0;
    };

    public func share() : RoundRobinGeneratorData = {
      size = size_;
      ctr = ctr_;
      round = round_;
    };

    public func unshare(data : RoundRobinGeneratorData) {
      size_ := data.size;
      ctr_ := data.ctr;
      round_ := data.round;
    };

    switch (data) {
      case (?d) unshare(d);
      case (_) {};
    };
  };

  public func roundRobinCollect<T>(sources : [Iter.Iter<T>], deduplicationEqual : ?((T, T) -> Bool)) : Iter.Iter<(Nat, T)> {
    if (sources.size() == 0) return Iter.empty();

    let sourcesToUse : Queue.Queue<(Nat, Iter.Iter<T>)> = sources.keys()
    |> Iter.map<Nat, (Nat, Iter.Iter<T>)>(_, func(i) = (i, sources[i]))
    |> Queue.fromIter(_);

    let producedItems : List.List<T> = List.empty();

    return {
      next = func() : ?(Nat, T) {
        label l while (true) {
          let ?(sourceIdx, source) = Queue.popFront(sourcesToUse) else return null;
          switch (source.next()) {
            case (?x) {
              Queue.pushBack(sourcesToUse, (sourceIdx, source));
              switch (deduplicationEqual) {
                case (null) {};
                case (?eq) {
                  if (Option.isSome(List.indexOf(producedItems, eq, x))) {
                    continue l;
                  };
                  List.add(producedItems, x);
                };
              };
              return ?(sourceIdx, x);
            };
            case (null) {};
          };
        };
        null;
      };
    };
  };

};
