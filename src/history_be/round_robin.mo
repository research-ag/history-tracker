import Iter "mo:new-base/Iter";
import List "mo:new-base/List";
import Option "mo:new-base/Option";

module {

  // interface
  public type RoundRobinSource<T> = {
    ctr : () -> Nat;
    round : () -> Nat;
    size : () -> Nat;
    itemsRemaining : () -> Nat;
    next : () -> ?T;
    resetProgress : () -> ();
  };

  public type RoundRobinBufferData<T> = {
    items : List.List<T>;
    ctr : Nat;
    round : Nat;
  };

  // A storage with ability to loop over elements, preserving cursor. After running out of items, emits null once and starts from the beginning
  // Compatible with Iter.Iter<T> ({ next : () -> ?T })
  public class RoundRobinBuffer<T>() = {

    var ctr_ : Nat = 0;
    var round_ : Nat = 0;
    var items_ : List.List<T> = List.empty();

    public func ctr() : Nat = ctr_;
    public func round() : Nat = round_;

    public func size() : Nat = List.size(items_);

    public func itemsRemaining() : Nat = List.size(items_) - ctr_;

    public func next() : ?T {
      if (ctr_ < List.size(items_)) {
        let item = List.get(items_, ctr_);
        ctr_ += 1;
        return ?item;
      } else if (ctr_ > 0) {
        round_ += 1;
        ctr_ := 0;
      };
      return null;
    };

    public func getItem(index : Nat) : T {
      List.get(items_, index);
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
  };

  public type RoundRobinGeneratorData = {
    size : Nat;
    ctr : Nat;
    round : Nat;
  };

  // Works like RoundRobinBuffer<Nat>, but produces consecutive nat-s from 0 to size_ - 1
  public class RoundRobinNatGenerator() {
    var ctr_ : Nat = 0;
    var round_ : Nat = 0;
    var size_ : Nat = 0;

    public func ctr() : Nat = ctr_;
    public func round() : Nat = round_;

    public func size() : Nat = size_;
    public func setSize(v : Nat) = size_ := v;

    public func itemsRemaining() : Nat = size_ - ctr_;

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
  };

  public func roundRobinCollect<T>(sources : [Iter.Iter<T>], amount : Nat, deduplicationEqual : ?((T, T) -> Bool)) : [T] {
    if (sources.size() == 0) return [];

    var sourcesToUse : List.List<Iter.Iter<T>> = List.fromArray(sources);
    let ret : List.List<T> = List.empty();

    label l while (true) {
      let nextLoopSources : List.List<Iter.Iter<T>> = List.empty();
      for (b in List.values(sourcesToUse)) {
        switch (b.next()) {
          case (?item) {
            List.add(nextLoopSources, b);
            switch (deduplicationEqual) {
              case (null) List.add(ret, item);
              case (?eq) if (Option.isNull(List.indexOf(ret, eq, item))) {
                List.add(ret, item);
              };
            };
            if (List.size(ret) == amount) break l;
          };
          case (_) {};
        };
      };
      if (List.size(nextLoopSources) == 0) break l;
      sourcesToUse := nextLoopSources;
    };

    List.toArray(ret);
  };

};
