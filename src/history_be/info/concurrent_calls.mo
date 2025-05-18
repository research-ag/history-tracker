import Buffer "mo:base/Buffer";
import Error "mo:base/Error";

import Call "single_call";

module {
  //public type ProcFunc = Result.Result<Call.Response, Error.Error> -> ();

  public type Item = {
    call_arg : Call.Arg;
    process_response : Call.Response -> ();
    process_error : Error.Error -> ();
    register_call : () -> ();
  };

  type BufferItem = (async Call.Response, Call.Response -> (), Error.Error -> ());

  // first version, not robust against traps in the process result function
  // if such a trap happens then the subsequent futures are lost
  // may be ok for certain applications if the calls are idemponent and will get repeated later
  public func make_calls(calls : [Item], trap_cb : Nat -> ()) : async* () {
    let futures = Buffer.Buffer<(async Call.Response, Call.Response -> (), Error.Error -> ())>(calls.size());
    label L for (c in calls.vals()) {
      try {
        futures.add((Call.f(c.call_arg), c.process_response, c.process_error));
        c.register_call(); // register that call was scheduled
      } catch _ {
        break L
        // stop scheduling more calls
      };
    };
    await async {}; // commit point, send the calls
    // now process the responses
    var i = 0;
    while (i < futures.size()) {
      let fut = futures.get(i);
      var trapDetected = true;
      try {
        fut.1 (await fut.0);
        trapDetected := false;
      } catch e {
        fut.2 (e);
        trapDetected := false;
      } finally if (trapDetected) trap_cb(i);
      i += 1;
    };
  };

};
