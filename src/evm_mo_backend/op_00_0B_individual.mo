import Array "mo:base/Array";
import Int "mo:base/Int";
import T "types";

module {
  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  // Individual Operations
  // STOP (0x00) and SIGNEXTEND (0x0B)

  public let op_00_STOP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    exVar.programCounter := Array.size(exCon.code);
    return #ok(exVar);
  };

  public let op_0B_SIGNEXTEND = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(b)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(x)) {
            var x_mod = x % (256 ** (b + 1));
            if (x_mod >= ((256 ** (b + 1)) / 2)) {
              x_mod := 2**256 + x_mod - (256 ** (b + 1));
            };
            let result = x_mod;
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 5;
                if (newGas < 0) {
                  return #err("Out of gas")
                  } else {
                  exVar.totalGas := Int.abs(newGas);
                  return #ok(exVar); };
              };
            };
          };
        };
      };
    };
  };
}
