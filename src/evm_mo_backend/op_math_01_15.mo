
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";

import Int "mo:base/Int";

import Debug "mo:base/Debug";


import T "types";
import {popN; pushAndGas;} "utils";




module{

  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  

  

  // Refactored op_01_ADD as example
  public func op_01_ADD (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let result = (a + b) % 2**256;
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_02_MUL (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let result = (a * b) % 2**256;
        return pushAndGas(exVar, result, 5);
      }
    }
  };

  

    public func op_03_SUB (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        var result: Int = a - b;
        Debug.print("result: " # debug_show(result));
        if (result < 0) { result += 2**256 };
        Debug.print("result: " # debug_show(result));
        return pushAndGas(exVar, Int.abs(result), 3);
      }
    }
  };

  public func op_04_DIV (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let result = if (b == 0) { 0 } else { a / b };
        return pushAndGas(exVar, result, 5);
      }
    }
  };

  public func op_05_SDIV (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        var b_mod: Int = b;
        if (b_mod >= 2**255) { b_mod -= 2**256 };
        var result: Int = 0;
        if (b_mod != 0) {
          result := a_mod / b_mod;
          if (result < 0) { result += 2**256 };
        };
        return pushAndGas(exVar, Int.abs(result), 5);
      }
    }
  };

  public func op_06_MOD (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let result = if (b == 0) { 0 } else { a % b };
        return pushAndGas(exVar, result, 5);
      }
    }
  };

  public func op_07_SMOD (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        var b_mod: Int = b;
        if (b_mod >= 2**255) { b_mod -= 2**256 };
        var result: Int = 0;
        if (b_mod != 0) {
          result := a_mod % b_mod;
          if (result < 0) { result += 2**256 };
        };
        return pushAndGas(exVar, Int.abs(result), 5);
      }
    }
  };

  public func op_08_ADDMOD (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 3)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let N = vals[2];
        let result = if (N == 0) { 0 } else { (a + b) % N };
        return pushAndGas(exVar, result, 8);
      }
    }
  };

  public func op_09_MULMOD (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 3)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let N = vals[2];
        let result = if (N == 0) { 0 } else { (a * b) % N };
        return pushAndGas(exVar, result, 8);
      }
    }
  };

  public func op_0A_EXP (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let exponent = vals[1];
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
              return #ok(exVar);
            }
          }
        }
      }
    }
  };

  public func op_0B_SIGNEXTEND (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let b = vals[0];
        let x = vals[1];
        var x_mod = x % (256 ** (b + 1));
        if (x_mod >= ((256 ** (b + 1)) / 2)) {
          x_mod := 2**256 + x_mod - (256 ** (b + 1));
        };
        let result = x_mod;
        return pushAndGas(exVar, result, 5);
      }
    }
  };

  public func op_10_LT (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let result = if (a < b) { 1 } else { 0 };
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_11_GT (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let result = if (a > b) { 1 } else { 0 };
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_12_SLT (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        var b_mod: Int = b;
        if (b_mod >= 2**255) { b_mod -= 2**256 };
        let result = if (a_mod < b_mod) { 1 } else { 0 };
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_13_SGT (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        var b_mod: Int = b;
        if (b_mod >= 2**255) { b_mod -= 2**256 };
        let result = if (a_mod > b_mod) { 1 } else { 0 };
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_14_EQ (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let result = if (a == b) { 1 } else { 0 };
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_15_ISZERO (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 1)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let result = if (a == 0) { 1 } else { 0 };
        return pushAndGas(exVar, result, 3);
      }
    }
  }
}