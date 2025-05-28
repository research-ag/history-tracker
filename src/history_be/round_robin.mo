import Iter "mo:new-base/Iter";
import List "mo:new-base/List";

module {

  public type RoundRobinBufferData<T> = {
    items : List.List<T>;
    ctr : Nat;
    round : Nat;
  };

  // A storage with ability to loop over elements, preserving cursor. After running out of items, emits null once and starts from the beginning
  // Compatible with Iter.Iter<T> ({ next : () -> ?T })
  public class RoundRobinBuffer<T>() {
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
      };
      ctr_ := 0;
      round_ += 1;
      return null;
    };

    public func getItem(index : Nat) : T {
      List.get(items_, index);
    };

    public func insertItem(item : T) {
      List.add(items_, item);
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

  public func roundRobinCollect<T>(sources : [Iter.Iter<T>], amount : Nat) : [T] {
    if (sources.size() == 0) return [];

    var sourcesToUse : List.List<Iter.Iter<T>> = List.fromArray(sources);
    let ret : List.List<T> = List.empty();

    label l while (true) {
      let nextLoopSources : List.List<Iter.Iter<T>> = List.empty();
      for (b in List.values(sourcesToUse)) {
        switch (b.next()) {
          case (?item) {
            List.add(nextLoopSources, b);
            List.add(ret, item);
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
