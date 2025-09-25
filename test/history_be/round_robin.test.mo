import Nat "mo:base/Nat";
import Prim "mo:prim";

import Iter "mo:core/Iter";

import RoundRobin "../../src/history_be/utils/round_robin";

// RoundRobinBuffer<T> has to be a subtype of RoundRobinSource<T> and Iter<T>
let _ : RoundRobin.RoundRobinSource<Float> = RoundRobin.RoundRobinBuffer<Float>(null);
let _ : Iter.Iter<Float> = RoundRobin.RoundRobinBuffer<Float>(null);

// RoundRobinNatGenerator has to be a subtype of RoundRobinSource<Nat> and Iter<Nat>
let _ : RoundRobin.RoundRobinSource<Nat> = RoundRobin.RoundRobinNatGenerator(null);
let _ : Iter.Iter<Nat> = RoundRobin.RoundRobinNatGenerator(null);

func mapRes<T>(res : Iter.Iter<(Nat, T)>, itemsAmount : Nat) : [T] = Iter.take<(Nat, T)>(res, itemsAmount)
|> Iter.map<(Nat, T), T>(_, func(_, x) = x)
|> Iter.toArray(_);

// ================== RoundRobinBuffer tests ==================
do {
  Prim.debugPrint("RoundRobinBuffer :: should return null if empty");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  assert li.next() == null;
};

do {
  Prim.debugPrint("RoundRobinBuffer :: should return items in order");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(0);
  li.insertItem(1);
  assert li.next() == ?0;
  assert li.next() == ?1;
};

do {
  Prim.debugPrint("RoundRobinBuffer :: should return null when the end is reached and then continue from start");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(123);
  li.insertItem(456);
  assert li.next() == ?123;
  assert li.next() == ?456;
  assert li.next() == null;
  assert li.next() == ?123;
};

do {
  Prim.debugPrint("RoundRobinBuffer :: should continue from the same position after inserting new item");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(123);
  li.insertItem(456);
  assert li.next() == ?123;
  li.insertItem(789);
  assert li.next() == ?456;
  assert li.next() == ?789;
  assert li.next() == null;
  assert li.next() == ?123;
};

do {
  Prim.debugPrint("RoundRobinBuffer :: should continue from the same position after inserting new item (edge case #1)");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(123);
  li.insertItem(456);
  assert li.next() == ?123;
  assert li.next() == ?456;
  li.insertItem(789);
  assert li.next() == ?789;
  assert li.next() == null;
  assert li.next() == ?123;
};

do {
  Prim.debugPrint("RoundRobinBuffer :: should continue from the same position after inserting new item (edge case #2)");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(123);
  li.insertItem(456);
  assert li.next() == ?123;
  assert li.next() == ?456;
  assert li.next() == null;
  li.insertItem(789);
  assert li.next() == ?123;
};

do {
  Prim.debugPrint("RoundRobinBuffer :: should count remaining items");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  assert li.itemsRemaining() == 0;
  li.insertItem(123);
  assert li.itemsRemaining() == 1;
  li.insertItem(456);
  assert li.itemsRemaining() == 2;

  assert li.next() == ?123;
  assert li.itemsRemaining() == 1;
  li.insertItem(789);
  assert li.itemsRemaining() == 2;

  assert li.next() == ?456;
  assert li.itemsRemaining() == 1;

  assert li.next() == ?789;
  assert li.itemsRemaining() == 0;

  assert li.next() == null;
  assert li.itemsRemaining() == 3;
};

do {
  Prim.debugPrint("RoundRobinBuffer :: view should return items without advancing cursor");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(10);
  li.insertItem(20);
  li.insertItem(30);

  let viewIter = li.view();
  assert viewIter.next() == ?(0, 10);
  assert viewIter.next() == ?(1, 20);
  assert li.ctr() == 0; // still unchanged
};

do {
  Prim.debugPrint("RoundRobinBuffer :: commit should advance cursor after view");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(10);
  li.insertItem(20);
  li.insertItem(30);

  let viewIter = li.view();
  ignore viewIter.next(); // ?(0, 10)
  ignore viewIter.next(); // ?(1, 20)
  li.setCtr(2); // manually advance

  assert li.next() == ?30; // now we continue from third
};

do {
  Prim.debugPrint("RoundRobinBuffer :: commit should wrap around and increment round");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(1);
  li.insertItem(2);
  li.insertItem(3);

  li.setCtr(3); // full round
  assert li.ctr() == 0;
  assert li.round() == 1;
};

do {
  Prim.debugPrint("RoundRobinBuffer :: view should start at latest position");
  let li = RoundRobin.RoundRobinBuffer<Nat>(null);
  li.insertItem(1);
  li.insertItem(2);
  li.insertItem(3);

  li.setCtr(1);
  let viewIter = li.view();
  assert viewIter.next() == ?(1, 2);
  assert viewIter.next() == ?(2, 3);
};

// ================== RoundRobinNatGenerator tests ==================
do {
  Prim.debugPrint("RoundRobinNatGenerator :: should return null if empty");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  assert li.next() == null;
};

do {
  Prim.debugPrint("RoundRobinNatGenerator :: should return null when the end is reached and then continue from start");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  li.setSize(2);
  assert li.next() == ?0;
  assert li.next() == ?1;
  assert li.next() == null;
  assert li.next() == ?0;
};

do {
  Prim.debugPrint("RoundRobinNatGenerator :: should continue from the same position after increasing size");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  li.setSize(2);
  assert li.next() == ?0;
  li.setSize(3);
  assert li.next() == ?1;
  assert li.next() == ?2;
  assert li.next() == null;
  assert li.next() == ?0;
};

do {
  Prim.debugPrint("RoundRobinNatGenerator :: should count remaining items");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  assert li.itemsRemaining() == 0;
  li.setSize(li.size() + 1);
  assert li.itemsRemaining() == 1;
  li.setSize(li.size() + 1);
  assert li.itemsRemaining() == 2;

  assert li.next() == ?0;
  assert li.itemsRemaining() == 1;
  li.setSize(li.size() + 1);
  assert li.itemsRemaining() == 2;

  assert li.next() == ?1;
  assert li.itemsRemaining() == 1;

  assert li.next() == ?2;
  assert li.itemsRemaining() == 0;

  assert li.next() == null;
  assert li.itemsRemaining() == 3;
};

do {
  Prim.debugPrint("RoundRobinNatGenerator :: should handle decreased size");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  li.setSize(4);
  assert li.next() == ?0;
  assert li.next() == ?1;
  assert li.next() == ?2;
  li.setSize(1);
  assert li.next() == null;
  assert li.next() == ?0;
  assert li.next() == null;
};

do {
  Prim.debugPrint("RoundRobinNatGenerator :: view should return items without advancing cursor");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  li.setSize(3);

  let viewIter = li.view();
  assert viewIter.next() == ?(0, 0);
  assert viewIter.next() == ?(1, 1);
  assert li.ctr() == 0; // still unchanged
};

do {
  Prim.debugPrint("RoundRobinNatGenerator :: commit should advance cursor after view");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  li.setSize(3);

  let viewIter = li.view();
  ignore viewIter.next(); // ?(0, 0)
  ignore viewIter.next(); // ?(1, 1)
  li.setCtr(2); // manually advance

  assert li.next() == ?2; // now we continue from third
};

do {
  Prim.debugPrint("RoundRobinNatGenerator :: commit should wrap around and increment round");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  li.setSize(3);

  li.setCtr(3); // full round
  assert li.ctr() == 0;
  assert li.round() == 1;
};

do {
  Prim.debugPrint("RoundRobinNatGenerator :: view should start at latest position");
  let li = RoundRobin.RoundRobinNatGenerator(null);
  li.setSize(3);

  li.setCtr(1);
  let viewIter = li.view();
  assert viewIter.next() == ?(1, 1);
  assert viewIter.next() == ?(2, 2);
};

// ================== roundRobinCollect tests ==================
func bCreate(items : [Nat]) : RoundRobin.RoundRobinBuffer<Nat> {
  let b = RoundRobin.RoundRobinBuffer<Nat>(null);
  for (item in items.vals()) {
    b.insertItem(item);
  };
  b;
};

do {
  Prim.debugPrint("roundRobinCollect :: should return empty array when no buffers");
  let res = RoundRobin.roundRobinCollect<Nat>([], null) |> mapRes(_, 100);
  assert res.size() == 0;
};

do {
  Prim.debugPrint("roundRobinCollect :: should return limited amount of items");
  let b = bCreate([0, 1, 2, 3, 4, 5, 6, 7]);
  assert b.itemsRemaining() == 8;

  let res = RoundRobin.roundRobinCollect<Nat>([b], null) |> mapRes(_, 3);
  assert res.size() == 3;
  assert res == [0, 1, 2];
  assert b.itemsRemaining() == 5;
};

do {
  Prim.debugPrint("roundRobinCollect :: should work with regular iterables");
  let res = RoundRobin.roundRobinCollect<Nat>([[0, 1, 2, 3, 4, 5, 6, 7].vals()], null) |> mapRes(_, 5);
  assert res.size() == 5;
  assert res == [0, 1, 2, 3, 4];
};

do {
  Prim.debugPrint("roundRobinCollect :: should return all items if not enough to fulfil full value");
  let b = bCreate([0, 1, 2, 3]);
  assert b.itemsRemaining() == 4;

  let res = RoundRobin.roundRobinCollect<Nat>([b], null) |> mapRes(_, 100);
  assert res.size() == 4;
  assert res == [0, 1, 2, 3];
  assert b.itemsRemaining() == 4; // buffer round-robin state should be reset
};

do {
  Prim.debugPrint("roundRobinCollect :: should handle empty buffers");
  let res = RoundRobin.roundRobinCollect<Nat>([bCreate([]), bCreate([]), bCreate([]), bCreate([]), bCreate([])], null) |> mapRes(_, 100);
  assert res.size() == 0;
};

do {
  Prim.debugPrint("roundRobinCollect :: should pick items evenly from buffers");

  let buffers = [
    bCreate([100, 101, 102, 103]),
    bCreate([200, 201, 202]),
    bCreate([300, 301, 302, 303, 304, 305]),
  ];

  let res0 = RoundRobin.roundRobinCollect<Nat>(buffers, null) |> mapRes(_, 3);
  assert res0.size() == 3;
  assert res0 == [100, 200, 300];

  let res1 = RoundRobin.roundRobinCollect<Nat>(buffers, null) |> mapRes(_, 3);
  assert res1.size() == 3;
  assert res1 == [101, 201, 301];

  let res2 = RoundRobin.roundRobinCollect<Nat>(buffers, null) |> mapRes(_, 3);
  assert res2.size() == 3;
  assert res2 == [102, 202, 302];

  // Note: 2 items got from buffer 3 because buffer 2 ended. We do not immediately get first item from buffer 2 again
  let res3 = RoundRobin.roundRobinCollect<Nat>(buffers, null) |> mapRes(_, 3);
  assert res3.size() == 3;
  assert res3 == [103, 303, 304];
};

do {
  Prim.debugPrint("roundRobinCollect :: should produce duplicates by default");

  let buffers = [
    bCreate([555, 101, 102, 103]),
    bCreate([200, 555, 202]),
  ];

  let res = RoundRobin.roundRobinCollect<Nat>(buffers, null) |> mapRes(_, 6);
  assert res.size() == 6;
  assert res == [555, 200, 101, 555, 102, 202];
};

do {
  Prim.debugPrint("roundRobinCollect :: should skip duplicates if needed");

  let buffers = [
    bCreate([555, 101, 102, 103]),
    bCreate([200, 555, 202]),
  ];

  let res = RoundRobin.roundRobinCollect<Nat>(buffers, ?Nat.equal) |> mapRes(_, 6);
  assert res.size() == 6;
  assert res == [555, 200, 101, 102, 202, 103];
};

do {
  Prim.debugPrint("roundRobinCollect :: should progress over buffers along with the collected iter");

  let buffers = [
    bCreate([555, 101, 102, 103]),
    bCreate([200, 555, 202]),
  ];
  let iter = RoundRobin.roundRobinCollect<Nat>(buffers, null);

  assert buffers[0].ctr() == 0;
  assert buffers[1].ctr() == 0;

  ignore iter.next();
  assert buffers[0].ctr() == 1;
  assert buffers[1].ctr() == 0;

  ignore iter.next();
  assert buffers[0].ctr() == 1;
  assert buffers[1].ctr() == 1;

  ignore iter.next();
  assert buffers[0].ctr() == 2;
  assert buffers[1].ctr() == 1;

  ignore iter.next();
  assert buffers[0].ctr() == 2;
  assert buffers[1].ctr() == 2;
};

do {
  Prim.debugPrint("roundRobinCollect :: should return correct source index alongside with items");

  let buffers = [
    bCreate([100, 101, 102, 103]),
    bCreate([200, 201]),
    bCreate([300, 301, 302, 303, 304]),
  ];
  let res = RoundRobin.roundRobinCollect<Nat>(buffers, null) |> Iter.take(_, 11) |> Iter.toArray(_);

  assert res == [
    (0, 100),
    (1, 200),
    (2, 300),
    (0, 101),
    (1, 201),
    (2, 301),
    (0, 102),
    (2, 302),
    (0, 103),
    (2, 303),
    (2, 304),
  ];
};
