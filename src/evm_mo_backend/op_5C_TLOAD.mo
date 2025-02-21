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
import Debug "mo:base/Debug";

// Assuming T is the module that contains our shared types: ExecutionContext, ExecutionVariables, etc.
import T "./types";

module{
  // TLOAD opcode: Load 32 bytes from temporary storage.
  // We assume that the temporary memory is provided as a Storage within the ExecutionVariables, named `tempMemory`.

  public func op_5C_TLOAD(exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result.Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(keyNat)) {
        let keyBuffer = Buffer.Buffer<Nat8>(32);
        for (i in Iter.revRange(31, 0)) {
          keyBuffer.add(Nat8.fromNat((keyNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let key_ = Blob.fromArray(Buffer.toArray<Nat8>(keyBuffer));
        Debug.print(debug_show(("key",key_)));
        let storageValueOpt = Trie.get(exVar.tempMemory, key key_, Blob.equal);
        Debug.print(debug_show(("storageValueOpt",storageValueOpt)));
        var storageValue = Array.init<Nat8>(0, 0);
        var result: Nat = 0;
        var keyExists: Bool = false;
        switch (storageValueOpt) {
          case (null) {};
          case (?value) {
            storageValue := Array.thaw<Nat8>(value);
            keyExists := true;
          };
        };
        
        if (keyExists) {
          var pos: Nat = 32;
          for (byte: Nat8 in storageValue.vals()) {
            pos -= 1;
            result += Nat8.toNat(byte) * (256 ** pos);
          };
        };
        
        
        switch (exVar.stack.push(result)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
            let newGas: Int = exVar.totalGas - 100; 
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
