import List "mo:core/List";
import Error "mo:core/Error";

import Call "single_call";

module {
  public type Item = {
    call_arg : Call.Arg;
    process_response : Call.Response -> ();
    process_error : Error.Error -> ();
    register_call : () -> ();
  };

  type BufferItem = (async Call.Response, Call.Response -> (), Error.Error -> ());

  public func make_calls(calls : [Item], trap_cb : Nat -> ()) : async* () {
    let futures = List.empty<(async Call.Response, Call.Response -> (), Error.Error -> ())>();
    label L for (i in calls.keys()) {
      let c = calls[i];
      try {
        List.add(futures, (Call.f(c.call_arg), c.process_response, c.process_error));
        c.register_call(); // register that call was scheduled
      } catch _ {
        // stop scheduling more calls
        break L;
      };
    };
    // now process the responses
    for ((i, fut) in futures.enumerate()) {
      var trapDetected = true;
      try {
        fut.1 (await? fut.0);
        trapDetected := false;
      } catch e {
        fut.2 (e);
        trapDetected := false;
      } finally if (trapDetected) trap_cb(i);
    };
  };

};
