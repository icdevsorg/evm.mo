import Vec "mo:vector";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Trie "mo:base/Trie";
import { key } "./utils";

// Assuming T is the module that contains our shared types: ExecutionContext, ExecutionVariables, etc.
import T "./types";

module{
  // TSTORE opcode: Store 32 bytes into temporary memory.
  // We assume that the temporary memory is provided as a Vec<Nat8> within the ExecutionVariables, named tempMemory.

  public func op_5D_TSTORE(exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result.Result<T.ExecutionVariables, Text> {
    // Pop the value and then the offset from the stack (Assuming value is pushed last, offset first)
    switch (exVar.stack.pop()) {
        case (#err(e)) { return #err(e) };
        case (#ok(keyNat)) {
          let keyBuffer = Buffer.Buffer<Nat8>(32);
          for (i in Iter.revRange(31, 0)) {
            keyBuffer.add(Nat8.fromNat((keyNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
          };
          let key_ = Blob.fromArray(Buffer.toArray<Nat8>(keyBuffer));
          switch (exVar.stack.pop()) {
            case (#err(e)) { return #err(e) };
            case (#ok(value)) {
              if (exVar.staticCall > 0) {
                return #err("Disallowed opcode TSTORE called within STATICCALL")
              };
              let valueBuffer = Buffer.Buffer<Nat8>(32);
              for (i in Iter.revRange(31, 0)) {
                valueBuffer.add(Nat8.fromNat((value % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
              };
              let valueArray = Buffer.toArray<Nat8>(valueBuffer);
              

              
              exVar.tempMemory := Trie.put(exVar.tempMemory, key(key_), Blob.equal, valueArray).0;
              
              // apply gas cost
              let newGas: Int = exVar.totalGas - 100; // warm/cold slot distinction not in this version
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
  }
};