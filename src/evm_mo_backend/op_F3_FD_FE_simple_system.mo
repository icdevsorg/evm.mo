import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Map "mo:map/Map";
import Vec "mo:vector";
import EVMStack "evmStack";
import T "types";

module {
  type Result<Ok, Err> = { #ok: Ok; #err: Err};
  
  private let { bhash } = Map;

  // Simple System Operations that don't require executeSubcontext
  // RETURN (0xF3), REVERT (0xFD), INVALID (0xFE)

  public let op_F3_RETURN = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    exVar.programCounter := Array.size(exCon.code);
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            let memory_byte_size = Vec.size(exVar.memory);
            let memory_size_word = (memory_byte_size + 31) / 32;
            let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
            var new_memory_cost = memory_cost;
            if (offset + size > memory_byte_size) {
              let new_memory_size_word = (offset + size + 31) / 32;
              let new_memory_byte_size = new_memory_size_word * 32;
              Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
              new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
            };
            var result = "" : Blob;
            if (size > 0) {
              let resultBuffer = Buffer.Buffer<Nat8>(size);
              for (pos in Iter.range(0, size - 1)) {
                resultBuffer.add(Vec.get(exVar.memory, offset + pos));
              };
              result := Blob.fromArray(Buffer.toArray<Nat8>(resultBuffer));
            };
            exVar.returnData := Option.make(result);
            let memory_expansion_cost = new_memory_cost - memory_cost;
            let newGas: Int = exVar.totalGas - 3 - memory_expansion_cost;
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

  public let op_FD_REVERT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    exVar.programCounter := Array.size(exCon.code) + 1;
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            let memory_byte_size = Vec.size(exVar.memory);
            let memory_size_word = (memory_byte_size + 31) / 32;
            let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
            var new_memory_cost = memory_cost;
            if (offset + size > memory_byte_size) {
              let new_memory_size_word = (offset + size + 31) / 32;
              let new_memory_byte_size = new_memory_size_word * 32;
              Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
              new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
            };
            var result = "" : Blob;
            if (size > 0) {
              let resultBuffer = Buffer.Buffer<Nat8>(size);
              for (pos in Iter.range(0, size - 1)) {
                resultBuffer.add(Vec.get(exVar.memory, offset + pos));
              };
              result := Blob.fromArray(Buffer.toArray<Nat8>(resultBuffer));
            };
            exVar.returnData := Option.make(result);
            exVar.stack := EVMStack.EVMStack();
            exVar.memory := Vec.new<Nat8>();
            exVar.contractStorage := exCon.contractStorage;
            exVar.balanceChanges := Vec.fromArray<T.BalanceChange>(exCon.balanceChanges);
            let storageChangesIter = Iter.fromArray<(Blob, T.StorageSlotChange)>(exCon.storageChanges);
            let codeAdditionsIter = Iter.fromArray<(Blob, T.CodeChange)>(exCon.codeAdditions);
            let codeStoreIter = Iter.fromArray<(Blob, [T.OpCode])>(exCon.codeStore);
            exVar.storageChanges := Map.fromIter<Blob, T.StorageSlotChange>(storageChangesIter, bhash);
            exVar.codeAdditions := Map.fromIter<Blob, T.CodeChange>(codeAdditionsIter, bhash);
            exVar.codeStore := Map.fromIter<Blob, [T.OpCode]>(codeStoreIter, bhash);
            exVar.storageStore := Vec.fromArray<(Blob, Blob)>(exCon.storageStore);
            exVar.logs := Vec.new<T.LogEntry>();
            exVar.gasRefund := 0;
            let memory_expansion_cost = new_memory_cost - memory_cost;
            let newGas: Int = exVar.totalGas - 3 - memory_expansion_cost;
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

  public let op_FE_INVALID = func (_exCon: T.ExecutionContext, _exVar: T.ExecutionVariables, _engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return #err("Designated INVALID opcode called");
  };

}
