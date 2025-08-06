import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import T "types";

module {
  
  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  public let op_60_PUSH1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    // check that there are enough operands
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + 2) {return #err("Not enough operands")};
    switch (exVar.stack.push(Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + 1]))) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += 1;
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

  public let op_61_PUSH2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 2;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_62_PUSH3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 3;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_63_PUSH4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 4;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_64_PUSH5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 5;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_65_PUSH6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 6;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_66_PUSH7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 7;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_67_PUSH8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 8;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_68_PUSH9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 9;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_69_PUSH10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 10;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_6A_PUSH11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 11;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_6B_PUSH12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 12;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_6C_PUSH13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 13;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_6D_PUSH14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 14;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_6E_PUSH15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 15;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_6F_PUSH16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 16;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_70_PUSH17 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 17;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_71_PUSH18 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 18;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_72_PUSH19 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 19;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_73_PUSH20 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 20;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_74_PUSH21 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 21;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_75_PUSH22 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 22;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_76_PUSH23 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 23;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_77_PUSH24 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 24;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_78_PUSH25 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 25;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_79_PUSH26 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 26;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_7A_PUSH27 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 27;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_7B_PUSH28 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 28;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_7C_PUSH29 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 29;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_7D_PUSH30 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 30;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_7E_PUSH31 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 31;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  public let op_7F_PUSH32 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 32;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

}
