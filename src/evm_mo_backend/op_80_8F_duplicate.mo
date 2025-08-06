import Int "mo:base/Int";
import T "types";

module {
  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  // Duplicate Operations (0x80-0x8F)
  // These operations duplicate the Nth stack item to the top of the stack

  public let op_80_DUP1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_81_DUP2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(1)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_82_DUP3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(2)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_83_DUP4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(3)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_84_DUP5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(4)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_85_DUP6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(5)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_86_DUP7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(6)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_87_DUP8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(7)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_88_DUP9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(8)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_89_DUP10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(9)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_8A_DUP11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(10)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_8B_DUP12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(11)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_8C_DUP13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(12)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_8D_DUP14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(13)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_8E_DUP15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(14)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

  public let op_8F_DUP16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(15)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - 3;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };
}
