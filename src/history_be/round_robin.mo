import Iter "mo:new-base/Iter";
import List "mo:new-base/List";

module {

  // A storage with ability to loop over elements, preserving cursor. After running out of items, emits null once and starts from the beginning
  // Compatible with Iter.Iter<T> ({ next : () -> ?T })
  public class RoundRobinBuffer<T>() {
    var ctr_ : Nat = 0;
    var round_ : Nat = 0;

    public func ctr() : Nat = ctr_;
    public func round() : Nat = round_;

    public var items : List.List<T> = List.empty();

    public func size() : Nat = List.size(items);

    public func itemsRemaining() : Nat = List.size(items) - ctr_;

    public func next() : ?T {
      if (ctr_ < List.size(items)) {
        let item = List.get(items, ctr_);
        ctr_ += 1;
        return ?item;
      };
      ctr_ := 0;
      round_ += 1;
      return null;
    };

    public func insertItem(item : T) {
      List.add(items, item);
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
