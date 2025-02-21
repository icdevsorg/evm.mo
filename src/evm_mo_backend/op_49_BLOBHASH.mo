import Vec "mo:vector";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Nat8  "mo:base/Nat8";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";

// Assuming T is the module that contains our shared types: ExecutionContext, ExecutionVariables, etc.
import T "./types";

module {

  // BLOBBASEFEE opcode: Compute and push the blob base fee based on blob size.

  public func op_49_BLOBHASH(exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result.Result<T.ExecutionVariables, Text> {
    // 1. Check if the stack has at least one value
    if (exVar.stack.size() < 1) {
        return #err("Error: Stack underflow");
    };

    // 2. Pop the index from the stack
    let index = switch(exVar.stack.pop()){
        case (#err(e)) { return #err(e) };
        case (#ok(v)) { v }
    };


    // 3. Ensure index is within valid range (0–5 for blobs)
    if (index >= 6) {
        
        switch(exVar.stack.push(0)){
            case (#err(e)) { return #err(e) };
            case (#ok(_)) { return #ok(exVar) };
        }; // Push zero (error handling, per EVM convention)
        
    };

    // 4. Retrieve the commitment hash from `blockInfo.blobCommitments`
    if(exCon.blockInfo.blockCommitments.size() < index+1) {
        //Debug.print("Error: No commitment found for blob index " # Nat.toText(index));
         switch(exVar.stack.push(0)){
            case (#err(e)) { return #err(e) };
            case (#ok(_)) { return #ok(exVar) };
        }; // Push zero (error handling, per EVM convention)
    };
    let commitment = Blob.toArray(exCon.blockInfo.blockCommitments[index]);

    var result: Nat = 0;
    for (pos in Iter.revRange(31, 0)) {
      result += Nat8.toNat(commitment[Int.abs(pos)]) * (256 ** Int.abs(pos));
    };

    // 5. Push the commitment hash onto the stack (or 0 if not found)
    switch(exVar.stack.push(result)){
        case (#err(e)) { return #err(e) };
        case (#ok(_)) {};
    };

    //calc gas

    let newGas: Int = exVar.totalGas - 3;
    if (newGas < 0) {
      return #err("Out of gas")
    };
    exVar.totalGas := Int.abs(newGas);

    return #ok(exVar);
  }
}