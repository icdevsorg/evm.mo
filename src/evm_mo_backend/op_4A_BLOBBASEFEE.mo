import Vec "mo:vector";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Nat8  "mo:base/Nat8";

// Assuming T is the module that contains our shared types: ExecutionContext, ExecutionVariables, etc.
import T "./types";

module {

  // BLOBBASEFEE opcode: Compute and push the blob base fee based on blob size.

  public func op_4A_BLOBBASEFEE(exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result.Result<T.ExecutionVariables, Text> {
    

    // Push the baseFee onto the stack
    switch (exVar.stack.push(exCon.consensusInfo.blobBaseFee)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {
        // Deduct a fixed gas cost, e.g., 3 units
        let newGas: Int = exVar.totalGas - 2;
        if (newGas < 0) {
          return #err("Out of gas")
        };
        exVar.totalGas := Int.abs(newGas);
        return #ok(exVar);
      };
    };
  }
}