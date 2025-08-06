import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Vec "mo:vector";
import T "types";
import { getCodeHash } "evm_helpers";

module {
  public let op_20_KECCAK256 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result.Result<T.ExecutionVariables, Text> {
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
            let dataBuffer = Buffer.Buffer<Nat8>(4);
            if (size > 0) {
              for (pos in Iter.range(offset, offset + size - 1)) {
                dataBuffer.add(Vec.get(exVar.memory, pos));
              };
            };
            let dataArray = Buffer.toArray<Nat8>(dataBuffer);
            let hashBlob = getCodeHash(dataArray);
            var pos: Nat = 32;
            var hashNat: Nat = 0;
            for (byte: Nat8 in hashBlob.vals()) {
              pos -= 1;
              hashNat += Nat8.toNat(byte) * (256 ** pos);
            };
            switch (exVar.stack.push(hashNat)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let memory_expansion_cost = new_memory_cost - memory_cost;
                let newGas: Int = exVar.totalGas - 30 - memory_expansion_cost;
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
}
