import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";

// Assuming T is the module that contains our shared types: ExecutionContext, ExecutionVariables, etc.
import T "./types";

module {

  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  // Comparison and Bitwise Logic Operations

  public let op_10_LT = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result = 0;
            if (a < b) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_11_GT = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result = 0;
            if (a > b) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_12_SLT = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var b_mod: Int = b;
            if (b_mod >= 2**255) { b_mod -= 2**256 };
            var result = 0;
            if (a_mod < b_mod) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_13_SGT = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var b_mod: Int = b;
            if (b_mod >= 2**255) { b_mod -= 2**256 };
            var result = 0;
            if (a_mod > b_mod) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_14_EQ = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result = 0;
            if (a == b) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_15_ISZERO = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var result = 0;
        if (a ==0) {
            result := 1;
        };
        switch (exVar.stack.push(result)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
            let newGas: Int = exVar.totalGas - 3;
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

  public let op_16_AND = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let a1: Nat64 = Nat64.fromNat(a / 2**192);
            let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
            let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
            let a4: Nat64 = Nat64.fromNat(a % 2**64);
            let b1: Nat64 = Nat64.fromNat(b / 2**192);
            let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
            let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
            let b4: Nat64 = Nat64.fromNat(b % 2**64);
            let result = Nat64.toNat(a1 & b1) * 2**192 + Nat64.toNat(a2 & b2) * 2**128 + Nat64.toNat(a3 & b3) * 2**64 + Nat64.toNat(a4 & b4);
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_17_OR = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let a1: Nat64 = Nat64.fromNat(a / 2**192);
            let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
            let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
            let a4: Nat64 = Nat64.fromNat(a % 2**64);
            let b1: Nat64 = Nat64.fromNat(b / 2**192);
            let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
            let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
            let b4: Nat64 = Nat64.fromNat(b % 2**64);
            let result = Nat64.toNat(a1 | b1) * 2**192 + Nat64.toNat(a2 | b2) * 2**128 + Nat64.toNat(a3 | b3) * 2**64 + Nat64.toNat(a4 | b4);
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_18_XOR = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let a1: Nat64 = Nat64.fromNat(a / 2**192);
            let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
            let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
            let a4: Nat64 = Nat64.fromNat(a % 2**64);
            let b1: Nat64 = Nat64.fromNat(b / 2**192);
            let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
            let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
            let b4: Nat64 = Nat64.fromNat(b % 2**64);
            let result = Nat64.toNat(a1 ^ b1) * 2**192 + Nat64.toNat(a2 ^ b2) * 2**128 + Nat64.toNat(a3 ^ b3) * 2**64 + Nat64.toNat(a4 ^ b4);
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_19_NOT = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        let result = (2**256 - 1) - a;
        switch (exVar.stack.push(result)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
            let newGas: Int = exVar.totalGas - 3;
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

  public let op_1A_BYTE = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(i)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(x)) {
            var result = 0;
            if (i < 32) {
              let num = x / (256 ** (31 - i));
              result := num % 256;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_1B_SHL = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(shift)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(value)) {
            let result = (value * (2 ** shift)) % 2**256;
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_1C_SHR = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(shift)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(value)) {
            let result = (value / (2 ** shift));
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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

  public let op_1D_SAR = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(shift)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(value)) {
            var result = (value / (2 ** shift));
            if (value >= 2**255) {
              result += (2**256 - (2 ** (256 - shift)));
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
                if (newGas < 0) {
                  return #err("Out of gas")
                  } else {
                  exVar.totalGas := Int.abs(newGas);
                  return #ok(exVar);};
              };
            };
          };
        };
      };
    };
  };
}
