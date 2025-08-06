import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat8 "mo:base/Nat8";
import { equal } "mo:base/Nat8";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map
import { bhash } "mo:map/Map";
import Sha3 "mo:sha3/"; // see https://mops.one/sha3
import T "types";
import { key } "utils";

module {
  
  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  func getCodeHash(code: [T.OpCode]) : Blob {
    var sha = Sha3.Keccak(256);
    sha.update(code);
    Blob.fromArray(sha.finalize());
  };

  public let op_50_POP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(y)) {
        let newGas: Int = exVar.totalGas - 2;
        if (newGas < 0) {
          return #err("Out of gas")
          } else {
          exVar.totalGas := Int.abs(newGas);
          return #ok(exVar); };
      };
    };
  };

  public let op_51_MLOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        let memory_byte_size = Vec.size(exVar.memory);
        let memory_size_word = (memory_byte_size + 31) / 32;
        let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
        var new_memory_cost = memory_cost;
        if (offset +32 > memory_byte_size) {
          let new_memory_size_word = (offset + 32 + 31) / 32;
          let new_memory_byte_size = new_memory_size_word * 32;
          Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
          new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
        };
        var result: Nat = 0;
        for (pos in Iter.revRange(31, 0)) {
          result += Nat8.toNat(Vec.get(exVar.memory, offset + 31 - Int.abs(pos))) * (256 ** Int.abs(pos));
        };
        switch (exVar.stack.push(result)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
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

  public let op_52_MSTORE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(value)) {
            let valueBuffer = Buffer.Buffer<Nat8>(32);
            for (i in Iter.revRange(31, 0)) {
              valueBuffer.add(Nat8.fromNat((value % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
            };
            let valueArray = Buffer.toArray<Nat8>(valueBuffer);
            let memory_byte_size = Vec.size(exVar.memory);
            let memory_size_word = (memory_byte_size + 31) / 32;
            let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
            var new_memory_cost = memory_cost;
            if (offset + 32 > memory_byte_size) {
              let new_memory_size_word = (offset + 32 + 31) / 32;
              let new_memory_byte_size = new_memory_size_word * 32;
              let mem_incr = new_memory_byte_size - memory_byte_size;
              Vec.addMany(exVar.memory, mem_incr, Nat8.fromNat(0));
              new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
            };
            for (i in Iter.range(0, 31)) {
              Vec.put(exVar.memory, offset + i, valueArray[i]);
            };
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

  public let op_53_MSTORE8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(value)) {
            let valueMod = Nat8.fromNat(value % 256);
            let memory_byte_size = Vec.size(exVar.memory);
            let memory_size_word = (memory_byte_size + 31) / 32;
            let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
            var new_memory_cost = memory_cost;
            if (offset + 32 > memory_byte_size) {
              let new_memory_size_word = (offset + 32) / 32;
              let new_memory_byte_size = new_memory_size_word * 32;
              let mem_incr = new_memory_byte_size - memory_byte_size;
              Vec.addMany(exVar.memory, mem_incr, Nat8.fromNat(0));
              new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
            };
            Vec.put(exVar.memory, offset, valueMod);
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

  public let op_54_SLOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(keyNat)) {
        let keyBuffer = Buffer.Buffer<Nat8>(32);
        for (i in Iter.revRange(31, 0)) {
          keyBuffer.add(Nat8.fromNat((keyNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let key_ = Blob.fromArray(Buffer.toArray<Nat8>(keyBuffer));
        let storageValueOpt = Trie.get(exVar.contractStorage, key key_, Blob.equal);
        var storageValue = Array.init<Nat8>(0, 0);
        var result: Nat = 0;
        var keyExists = false;
        switch (storageValueOpt) {
          case (null) {};
          case (?value) {
            storageValue := Array.thaw<Nat8>(value);
            keyExists := true;
          };
        };
        // Check for any changes during the current execution
        for (change in Map.entries(exVar.storageChanges)) {
          if (change.0 == key_) {
            switch (change.1.newValue) {
              case (null) {};
              case (?value) {
                storageValue := Array.thaw<Nat8>(value);
                keyExists := true;
              };
            };
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
            let newGas: Int = exVar.totalGas - 100; // warm/cold address distinction not in this version
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

  public let op_55_SSTORE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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
              return #err("Disallowed opcode SSTORE called within STATICCALL")
            };
            let valueBuffer = Buffer.Buffer<Nat8>(32);
            for (i in Iter.revRange(31, 0)) {
              valueBuffer.add(Nat8.fromNat((value % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
            };
            let valueArray = Buffer.toArray<Nat8>(valueBuffer);
            var originalValueOpt = Trie.get(exCon.contractStorage, key key_, Blob.equal); // type ?[Nat8]
            var currentValueOpt = Trie.get(exVar.contractStorage, key key_, Blob.equal);
            var originalValue = Array.init<Nat8>(32, 0);
            var currentValue = Array.init<Nat8>(32, 0);
            let zeroArray = Array.freeze<Nat8>(Array.init<Nat8>(32, 0));
            var storageChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(exCon.callee), Blob.toArray(key_)));
            switch (originalValueOpt) {
              case (null) {};
              case (?origVal) {
                originalValue := Array.thaw<Nat8>(origVal);
              };
            };
            switch (currentValueOpt) {
              case (null) {};
              case (?curVal) {
                currentValue := Array.thaw<Nat8>(curVal);
                storageChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(storageChangeKey), curVal));
              };
            };
            let storageSlotChange = {
              key = key_;
              originalValue = currentValueOpt;
              newValue = Option.make(valueArray);
            };
            Map.set(exVar.storageChanges, bhash, storageChangeKey, storageSlotChange);
            Vec.add(exVar.storageStore, (exCon.callee, storageChangeKey));
            exVar.contractStorage := Trie.put(exVar.contractStorage, key(key_), Blob.equal, valueArray).0;
            // calculate dynamic gas cost
            var dynamicGas = 100;
            if (Array.equal(valueArray, Array.freeze<Nat8>(currentValue), equal)) {
              dynamicGas := 100;
            } else {
              if (Array.equal(Array.freeze<Nat8>(currentValue), Array.freeze<Nat8>(originalValue), equal)) {
                if (Array.equal(Array.freeze<Nat8>(originalValue), zeroArray, equal)) {
                  dynamicGas := 20000;
                } else {
                  dynamicGas := 2900;
                };
              };
            };
            // calculate gas refunds
            if (not (Array.equal(valueArray, Array.freeze<Nat8>(currentValue), equal))) {
              if (Array.equal(Array.freeze<Nat8>(currentValue), Array.freeze<Nat8>(originalValue), equal)) {
                if ((not (Array.equal(Array.freeze<Nat8>(originalValue), zeroArray, equal))) and value == 0) {
                  exVar.gasRefund += 4800;
                };
              } else {
                if (not (Array.equal(Array.freeze<Nat8>(originalValue), zeroArray, equal))) {
                  if (Array.equal(Array.freeze<Nat8>(currentValue), zeroArray, equal)) {
                    exVar.gasRefund -= 4800; // In this instance there would have been at least 4800 added to gas refunds earlier in the context.
                  } else {
                    if (Array.equal(valueArray, zeroArray, equal)) {
                      exVar.gasRefund += 4800;
                    };
                  };
                };
                if (Array.equal(valueArray, Array.freeze<Nat8>(originalValue), equal)) {
                  if (Array.equal(Array.freeze<Nat8>(originalValue), zeroArray, equal)) {
                    exVar.gasRefund += 19900;
                  } else {
                    exVar.gasRefund += 2800;
                  };
                };
              };
            };
            // apply gas cost
            let newGas: Int = exVar.totalGas - dynamicGas; // warm/cold slot distinction not in this version
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

  public let op_56_JUMP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(counter)) {
        if (exCon.code[counter] == 0x5b) {
          exVar.programCounter := counter - 1;
          } else {
          return #err("Counter offset is not a JUMPDEST");
        };        
        let newGas: Int = exVar.totalGas - 8;
        if (newGas < 0) {
          return #err("Out of gas")
          } else {
          exVar.totalGas := Int.abs(newGas);
          return #ok(exVar);
        };
      };
    };
  };

  public let op_57_JUMPI = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(counter)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(i)) {
            if (i != 0) {
              if (exCon.code[counter] == 0x5b) {
                exVar.programCounter := counter - 1;
                } else {
                return #err("Counter offset is not a JUMPDEST");
              };  
            };
          };
        };      
        let newGas: Int = exVar.totalGas - 10;
        if (newGas < 0) {
          return #err("Out of gas")
          } else {
          exVar.totalGas := Int.abs(newGas);
          return #ok(exVar);
        };
      };
    };
  };

  public let op_58_PC = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(Int.abs(exVar.programCounter))) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {
        let newGas: Int = exVar.totalGas - 2;
        if (newGas < 0) {
          return #err("Out of gas")
          } else {
          exVar.totalGas := Int.abs(newGas);
          return #ok(exVar);
        };
      };
    };
  };

  public let op_59_MSIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(Vec.size(exVar.memory))) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {
        let newGas: Int = exVar.totalGas - 2;
        if (newGas < 0) {
          return #err("Out of gas")
          } else {
          exVar.totalGas := Int.abs(newGas);
          return #ok(exVar);
        };
      };
    };
  };

  public let op_5A_GAS = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let newGas: Int = exVar.totalGas - 2;
    if (newGas < 0) {
      return #err("Out of gas")
    } else {
      exVar.totalGas := Int.abs(newGas);
      switch (exVar.stack.push(exVar.totalGas)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) { return #ok(exVar) };
      };
    };
  };

  public let op_5B_JUMPDEST = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let newGas: Int = exVar.totalGas - 1;
    if (newGas < 0) {
      return #err("Out of gas")
    } else {
      exVar.totalGas := Int.abs(newGas);
      return #ok(exVar);
    };
  };

  public let op_5F_PUSH0 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        let newGas: Int = exVar.totalGas - 2;
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
