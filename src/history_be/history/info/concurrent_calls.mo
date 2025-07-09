import Buffer "mo:base/Buffer";
import Error "mo:base/Error";

import Call "single_call";

module {
  public type Item = {
    call_arg : Call.Arg;
    process_response : Call.Response -> ();
    process_error : Error.Error -> ();
    register_call : () -> ();
    register_fail_cb : () -> ();
  };

  type BufferItem = (async Call.Response, Call.Response -> (), Error.Error -> ());

  public func make_calls(calls : [Item], trap_cb : Nat -> ()) : async* () {
    let futures = Buffer.Buffer<(async Call.Response, Call.Response -> (), Error.Error -> ())>(calls.size());
    label L for (i in calls.keys()) {
      let c = calls[i];
      try {
        futures.add((Call.f(c.call_arg), c.process_response, c.process_error));
        c.register_call(); // register that call was scheduled
      } catch _ {
        // stop scheduling more calls
        var j = i;
        while (j < calls.size()) {
          calls[j].register_fail_cb();
          j += 1;
        };
        break L;
      };
    };
    // now process the responses
    var i = 0;
    while (i < futures.size()) {
      let fut = futures.get(i);
      var trapDetected = true;
      try {
        fut.1 (await? fut.0);
        trapDetected := false;
      } catch e {
        fut.2 (e);
        trapDetected := false;
      } finally if (trapDetected) trap_cb(i);
      i += 1;
    };
  };

};
