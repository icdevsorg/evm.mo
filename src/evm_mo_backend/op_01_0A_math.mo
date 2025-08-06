import Int "mo:base/Int";
import Result "mo:base/Result";

// Assuming T is the module that contains our shared types: ExecutionContext, ExecutionVariables, etc.
import T "./types";

module {

  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  // Basic Math and Bitwise Logic Operations

  public let op_01_ADD = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    // pop two values from the stack; returns error if stack is empty
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            // add them and check for result overflow
            let result = (a + b) % 2**256;
            // push result to stack and check for stack overflow
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
                // return new execution context variables
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

  public let op_02_MUL = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let result = (a * b) % 2**256;
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

  public let op_03_SUB = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result: Int = a - b;
            if (result < 0) {result += 2**256};
            switch (exVar.stack.push(Int.abs(result))) {
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

  public let op_04_DIV = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let result = if (b == 0) { 0; } else { a / b; };
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

  public let op_05_SDIV = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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
            var result: Int = 0;
            if (b_mod != 0) {
              result := a_mod / b_mod;
              if (result < 0) { result += 2**256 };
            };
            switch (exVar.stack.push(Int.abs(result))) {
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

  public let op_06_MOD = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let result = if (b == 0) { 0; } else { a % b; };
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

  public let op_07_SMOD = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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
            var result: Int = 0;
            if (b_mod != 0) {
              result := a_mod % b_mod;
              if (result < 0) { result += 2**256 };
            };
            switch (exVar.stack.push(Int.abs(result))) {
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

  public let op_08_ADDMOD = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(N)) {
                let result = if (N == 0) { 0; } else { (a + b) % N; };
                switch (exVar.stack.push(result)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(_)) {
                    let newGas: Int = exVar.totalGas - 8;
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
    };
  };

  public let op_09_MULMOD = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(N)) {
                let result = if (N == 0) { 0; } else { (a * b) % N; };
                switch (exVar.stack.push(result)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(_)) {
                    let newGas: Int = exVar.totalGas - 8;
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
    };
  };

  public let op_0A_EXP = func (_exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(exponent)) {
            //modfied from https://forum.dfinity.org/t/reject-text-ic0503-canister-trapped-explicitly-bigint-function-error/26937/3
            var result: Nat = 1;
            var base_ = a;
            var exponent_ = exponent;
            while (exponent_ > 0){
              if (exponent_ % 2 == 1) result := (result * base_) % 2**256;
              exponent_ := exponent_ / 2;
              base_ := (base_ * base_) % 2**256;
            };
            var byteSize: Nat = 0;
            var num = exponent;
            while (num >= 1) {
              num /= 256;
              byteSize += 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - (10 + byteSize * 50);
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
