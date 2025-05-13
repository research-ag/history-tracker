import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Result "mo:base/Result";

import Call "call";

module {
  public type ProcFunc = Result.Result<Call.T, Error.Error> -> ();

  public type Item = {
    call_arg : Call.S;
    register_call : () -> ();
    process_response : ProcFunc;
  };

  // first version, not robust against traps in the process result function
  // if such a trap happens then the subsequent futures are lost
  // may be ok for certain applications if the calls are idemponent and will get repeated later
  public func make_calls(calls : [Item]) : async* () {
    let futures = Buffer.Buffer<(async Call.T, ProcFunc)>(calls.size());
    label L for (c in calls.vals()) {
      try {
        futures.add((Call.f(c.call_arg), c.process_response));
        c.register_call(); // register that call was scheduled
      } catch _ {
        break L
        // stop scheduling more calls
      };
    };
    await async {}; // commit point, send the calls
    // now process the responses
    for (fut in futures.vals()) {
      var returned = 0;
      try {
        fut.1 (#ok(await fut.0));
        returned += 1;
      } catch e {
        fut.1 (#err(e));
        returned += 1;
      } finally {
      };
    };
  };


};
