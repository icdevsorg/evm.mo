import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import { equal } "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map
import { bhash } "mo:map/Map";
import Sha256 "mo:sha2/Sha256"; // see https://mops.one/sha2
import Sha3 "mo:sha3/"; // see https://mops.one/sha3
import MPTrie "mo:merkle-patricia-trie/Trie"; // see https://github.com/f0i/merkle-patricia-trie.mo
import K "mo:merkle-patricia-trie/Key";
import V "mo:merkle-patricia-trie/Value";
import { encodeAccount; decodeAccount; encodeAddressNonce } "rlp"; // see https://github.com/relaxed04/rlp-motoko
import { callPreCompile } "precompiles";
import EVMStack "evmStack";
import T "types";
import { key; getCodeHash; } "utils";

module {

  type Result<Ok, Err> = { #ok: Ok; #err: Err };

  // --- Helper functions for PUSH, DUP, SWAP ---
  
  func pushN(bytes: Nat, exCon: T.ExecutionContext, exVar: T.ExecutionVariables, gasCost: Int) : Result<T.ExecutionVariables, Text> {
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
        let newGas: Int = exVar.totalGas - gasCost;
        if (newGas < 0) {
          return #err("Out of gas")
        } else {
          exVar.totalGas := Int.abs(newGas);
          return #ok(exVar);
        };
      };
    };
  };

  func dupN(n: Nat, exVar: T.ExecutionVariables, gasCost: Int) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(n)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
            let newGas: Int = exVar.totalGas - gasCost;
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

  func swapN(n: Nat, exVar: T.ExecutionVariables, gasCost: Int) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(n)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(n, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
                    let newGas: Int = exVar.totalGas - gasCost;
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
    };
  };

  // Memory Operations

  public func op_50_POP (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_51_MLOAD (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_52_MSTORE (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_53_MSTORE8 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_54_SLOAD (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_55_SSTORE (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_56_JUMP (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_57_JUMPI (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_58_PC (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_59_MSIZE (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_5A_GAS (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_5B_JUMPDEST (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let newGas: Int = exVar.totalGas - 1;
    if (newGas < 0) {
      return #err("Out of gas")
    } else {
      exVar.totalGas := Int.abs(newGas);
      return #ok(exVar);
    };
  };

  // Push Operations, Duplication Operations, Exchange Operations
  
  public func op_5F_PUSH0 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  public func op_60_PUSH1 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(1, exCon, exVar, 3);
  };

  public func op_61_PUSH2 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(2, exCon, exVar, 3);
  };

  public func op_62_PUSH3 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(3, exCon, exVar, 3);
  };

  public func op_63_PUSH4 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(4, exCon, exVar, 3);
  };

  public func op_64_PUSH5 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(5, exCon, exVar, 3);
  };

  public func op_65_PUSH6 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(6, exCon, exVar, 3);
  };

  public func op_66_PUSH7 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(7, exCon, exVar, 3);
  };

  public func op_67_PUSH8 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(8, exCon, exVar, 3);
  };

  public func op_68_PUSH9 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(9, exCon, exVar, 3);
  };

  public func op_69_PUSH10 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(10, exCon, exVar, 3);
  };

  public func op_6A_PUSH11 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(11, exCon, exVar, 3);
  };

  public func op_6B_PUSH12 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(12, exCon, exVar, 3);
  };

  public func op_6C_PUSH13 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(13, exCon, exVar, 3);
  };

  public func op_6D_PUSH14 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(14, exCon, exVar, 3);
  };

  public func op_6E_PUSH15 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(15, exCon, exVar, 3);
  };

  public func op_6F_PUSH16 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(16, exCon, exVar, 3);
  };

  public func op_70_PUSH17 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(17, exCon, exVar, 3);
  };

  public func op_71_PUSH18 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(18, exCon, exVar, 3);
  };

  public func op_72_PUSH19 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(19, exCon, exVar, 3);
  };

  public func op_73_PUSH20 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(20, exCon, exVar, 3);
  };

  public func op_74_PUSH21 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(21, exCon, exVar, 3);
  };

  public func op_75_PUSH22 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(22, exCon, exVar, 3);
  };

  public func op_76_PUSH23 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(23, exCon, exVar, 3);
  };

  public func op_77_PUSH24 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(24, exCon, exVar, 3);
  };

  public func op_78_PUSH25 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(25, exCon, exVar, 3);
  };

  public func op_79_PUSH26 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(26, exCon, exVar, 3);
  };

  public func op_7A_PUSH27 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(27, exCon, exVar, 3);
  };

  public func op_7B_PUSH28 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(28, exCon, exVar, 3);
  };

  public func op_7C_PUSH29 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(29, exCon, exVar, 3);
  };

  public func op_7D_PUSH30 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(30, exCon, exVar, 3);
  };

  public func op_7E_PUSH31 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(31, exCon, exVar, 3);
  };

  public func op_7F_PUSH32 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return pushN(32, exCon, exVar, 3);
  };

  public func op_80_DUP1 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(0, exVar, 3);
  };

  public func op_81_DUP2 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(1, exVar, 3);
  };

  public func op_82_DUP3 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(2, exVar, 3);
  };

  public func op_83_DUP4 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(3, exVar, 3);
  };

  public func op_84_DUP5 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(4, exVar, 3);
  };

  public func op_85_DUP6 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(5, exVar, 3);
  };

  public func op_86_DUP7 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(6, exVar, 3);
  };

  public func op_87_DUP8 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(7, exVar, 3);
  };

  public func op_88_DUP9 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(8, exVar, 3);
  };

  public func op_89_DUP10 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(9, exVar, 3);
  };

  public func op_8A_DUP11 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(10, exVar, 3);
  };

  public func op_8B_DUP12 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(11, exVar, 3);
  };

  public func op_8C_DUP13 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(12, exVar, 3);
  };

  public func op_8D_DUP14 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(13, exVar, 3);
  };

  public func op_8E_DUP15 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(14, exVar, 3);
  };

  public func op_8F_DUP16 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return dupN(15, exVar, 3);
  };

  public func op_90_SWAP1 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(1, exVar, 3);
  };

  public func op_91_SWAP2 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(2, exVar, 3);
  };

  public func op_92_SWAP3 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(3, exVar, 3);
  };

  public func op_93_SWAP4 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(4, exVar, 3);
  };

  public func op_94_SWAP5 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(5, exVar, 3);
  };

  public func op_95_SWAP6 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(6, exVar, 3);
  };

  public func op_96_SWAP7 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(7, exVar, 3);
  };

  public func op_97_SWAP8 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(8, exVar, 3);
  };

  public func op_98_SWAP9 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(9, exVar, 3);
  };

  public func op_99_SWAP10 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(10, exVar, 3);
  };

  public func op_9A_SWAP11 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(11, exVar, 3);
  };

  public func op_9B_SWAP12 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(12, exVar, 3);
  };

  public func op_9C_SWAP13 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(13, exVar, 3);
  };

  public func op_9D_SWAP14 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(14, exVar, 3);
  };

  public func op_9E_SWAP15 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(15, exVar, 3);
  };

  public func op_9F_SWAP16 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return swapN(16, exVar, 3);
  };
}