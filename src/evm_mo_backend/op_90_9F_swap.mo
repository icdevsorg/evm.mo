import Int "mo:base/Int";
import T "types";

module {
  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  // Swap Operations (0x90-0x9F)
  // These operations exchange the 1st and Nth stack items

  public let op_90_SWAP1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(1)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(1, a)) {
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
        };
      };
    };
  };

  public let op_91_SWAP2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(2)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(2, a)) {
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
        };
      };
    };
  };

  public let op_92_SWAP3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(3)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(3, a)) {
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
        };
      };
    };
  };

  public let op_93_SWAP4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(4)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(4, a)) {
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
        };
      };
    };
  };

  public let op_94_SWAP5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(5)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(5, a)) {
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
        };
      };
    };
  };

  public let op_95_SWAP6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(6)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(6, a)) {
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
        };
      };
    };
  };

  public let op_96_SWAP7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(7)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(7, a)) {
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
        };
      };
    };
  };

  public let op_97_SWAP8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(8)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(8, a)) {
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
        };
      };
    };
  };

  public let op_98_SWAP9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(9)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(9, a)) {
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
        };
      };
    };
  };

  public let op_99_SWAP10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(10)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(10, a)) {
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
        };
      };
    };
  };

  public let op_9A_SWAP11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(11)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(11, a)) {
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
        };
      };
    };
  };

  public let op_9B_SWAP12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(12)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(12, a)) {
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
        };
      };
    };
  };

  public let op_9C_SWAP13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(13)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(13, a)) {
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
        };
      };
    };
  };

  public let op_9D_SWAP14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(14)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(14, a)) {
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
        };
      };
    };
  };

  public let op_9E_SWAP15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(15)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(15, a)) {
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
        };
      };
    };
  };

  public let op_9F_SWAP16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(16)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(16, a)) {
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
        };
      };
    };
  };
}
