import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map
import { bhash } "mo:map/Map";
import Sha3 "mo:sha3/"; // see https://mops.one/sha3
import T "types";
import { key } "utils";
import { decodeAccount } "rlp"; // see https://github.com/relaxed04/rlp-motoko

module {

  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  func getCodeHash(code: [T.OpCode]) : Blob {
    var sha = Sha3.Keccak(256);
    sha.update(code);
    Blob.fromArray(sha.finalize());
  };

  // Environmental Information Operations

  public let op_30_ADDRESS = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    var pos: Nat = 20;
    var result: Nat = 0;
    for (byte: Nat8 in exCon.callee.vals()) {
      pos -= 1;
      result += Nat8.toNat(byte) * (256 ** pos);
    };
    switch (exVar.stack.push(result)) {
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

  public let op_31_BALANCE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(addressNat)) {
        let addressBuffer = Buffer.Buffer<Nat8>(20);
        for (i in Iter.revRange(19, 0)) {
          addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
        let accountData = Trie.get(exCon.accounts, key address, Blob.equal);
        var balance = 0;
        switch (accountData) {
          case (null) {};
          case (?data) {
            let decodedData = decodeAccount(data);
            balance := decodedData.1;
          };
        };
        for (change in Vec.vals(exVar.balanceChanges)) {
          if (change.from == address) {balance -= change.amount};
          if (change.to == address) {balance += change.amount};
        };
        switch (exVar.stack.push(balance)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {};
        };
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
  
  public let op_32_ORIGIN = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    var pos: Nat = 20;
    var result: Nat = 0;
    for (byte: Nat8 in exCon.origin.vals()) {
      pos -= 1;
      result += Nat8.toNat(byte) * (256 ** pos);
    };
    switch (exVar.stack.push(result)) {
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

  public let op_33_CALLER = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    var pos: Nat = 20;
    var result: Nat = 0;
    for (byte: Nat8 in exCon.caller.vals()) {
      pos -= 1;
      result += Nat8.toNat(byte) * (256 ** pos);
    };
    switch (exVar.stack.push(result)) {
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

  public let op_34_CALLVALUE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.incomingEth)) {
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

  public let op_35_CALLDATALOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(i)) {
        let array1 = Blob.toArray(exCon.calldata);
        let array2 = Array.freeze<Nat8>(Array.init<Nat8>(32, 0));
        let array3 = Array.append<Nat8>(array1, array2);
        var array4 = Array.init<Nat8>(32, 0);
        if (i < array1.size()) {
          array4 := Array.thaw<Nat8>(Array.subArray<Nat8>(array3, i, 32));
        };
        var pos: Nat = 32;
        var result: Nat = 0;
        for (byte: Nat8 in array4.vals()) {
          pos -= 1;
          result += Nat8.toNat(byte) * (256 ** pos);
        }; 
        switch (exVar.stack.push(result)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
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
    };
  };

  public let op_36_CALLDATASIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.calldata.size())) {
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

  public let op_37_CALLDATACOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(destOffset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(offset)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(size)) {
                let array1 = Blob.toArray(exCon.calldata);
                let array2 = Array.freeze<Nat8>(Array.init<Nat8>(size, 0));
                let array3 = Array.append<Nat8>(array1, array2);
                var array4 = Array.init<Nat8>(size, 0);
                if (offset < array1.size()) {
                  array4 := Array.thaw<Nat8>(Array.subArray<Nat8>(array3, offset, size));
                };
                let memory_byte_size = Vec.size(exVar.memory);
                let memory_size_word = (memory_byte_size + 31) / 32;
                let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                var new_memory_cost = memory_cost;
                if (destOffset + size > memory_byte_size) {
                  let new_memory_size_word = (destOffset + size + 31) / 32;
                  let new_memory_byte_size = new_memory_size_word * 32;
                  Vec.addMany(exVar.memory, Int.abs(new_memory_byte_size - memory_byte_size), Nat8.fromNat(0));
                  new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                };
                if (size > 0) {
                  for (i in Iter.range(0, size - 1)) {
                    Vec.put(exVar.memory, destOffset + i, array4[i]);
                  };
                };
                let memory_expansion_cost = Int.abs(new_memory_cost - memory_cost);
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
    };
  };

  public let op_38_CODESIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.code.size())) {
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

  public let op_39_CODECOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(destOffset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(offset)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(size)) {
                let array1 = exCon.code;
                let array2 = Array.freeze<Nat8>(Array.init<Nat8>(size, 0));
                let array3 = Array.append<Nat8>(array1, array2);
                var array4 = Array.init<Nat8>(size, 0);
                if (offset < array1.size()) {
                  array4 := Array.thaw<Nat8>(Array.subArray<Nat8>(array3, offset, size));
                };
                let memory_byte_size = Vec.size(exVar.memory);
                let memory_size_word = (memory_byte_size + 31) / 32;
                let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                var new_memory_cost = memory_cost;
                if (destOffset + size > memory_byte_size) {
                  let new_memory_size_word = (destOffset + size + 31) / 32;
                  let new_memory_byte_size = new_memory_size_word * 32;
                  Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
                  new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                };
                if (size > 0) {
                  for (i in Iter.range(0, size - 1)) {
                    Vec.put(exVar.memory, destOffset + i, array4[i]);
                  };
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
    };
  };

  public let op_3A_GASPRICE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.gasPrice)) {
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

  public let op_3B_EXTCODESIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(addressNat)) {
        let addressBuffer = Buffer.Buffer<Nat8>(20);
        for (i in Iter.revRange(19, 0)) {
          addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
        let accountData = Trie.get(exCon.accounts, key address, Blob.equal);
        var extCode = Array.init<Nat8>(0, 0);
        var extCodeSize = 0;
        var codeHash = "" : Blob;
        switch (accountData) {
          case (null) {};
          case (?data) {
            let decodedData = decodeAccount(data);
            codeHash := decodedData.3;
            let code = Map.get(exVar.codeStore, bhash, codeHash);
            switch (code) {
              case (null) {};
              case (?code_) {
                extCode := Array.thaw<Nat8>(code_);
                extCodeSize := code_.size();
              };
            };
          };
        };
        // Check for any changes during the current execution
        var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(extCode)));
        for (change in Map.entries(exVar.codeAdditions)) {
          if (change.0 == codeChangeKey) {
            switch (change.1.newValue) {
              case (null) {
                extCodeSize := 0;
              };
              case (?newCode) {
                extCodeSize := newCode.size();
                codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), newCode));
              };
            };
          };
        };
        switch (exVar.stack.push(extCodeSize)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {};
        };
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

  public let op_3C_EXTCODECOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(addressNat)) {
        let addressBuffer = Buffer.Buffer<Nat8>(20);
        for (i in Iter.revRange(19, 0)) {
          addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
        let accountData = Trie.get(exCon.accounts, key address, Blob.equal);
        var extCode = Array.init<Nat8>(0, 0);
        var codeHash = "" : Blob;
        switch (accountData) {
          case (null) {};
          case (?data) {
            let decodedData = decodeAccount(data);
            codeHash := decodedData.3;
            let code = Map.get(exVar.codeStore, bhash, codeHash);
            switch (code) {
              case (null) {};
              case (?code_) {
                extCode := Array.thaw<Nat8>(code_);
              };
            };
          };
        };
        // Check for any changes during the current execution
        var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(extCode)));
        for (change in Map.entries(exVar.codeAdditions)) {
          if (change.0 == codeChangeKey) {
            switch (change.1.newValue) {
              case (null) {
                extCode := Array.init<Nat8>(0, 0);
              };
              case (?newCode) {
                extCode := Array.thaw<Nat8>(newCode);
                codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), newCode));
              };
            };
          };
        };
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(destOffset)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(offset)) {
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(size)) {
                    let array1 = Array.freeze<Nat8>(extCode);
                    let array2 = Array.freeze<Nat8>(Array.init<Nat8>(size, 0));
                    let array3 = Array.append<Nat8>(array1, array2);
                    var array4 = Array.init<Nat8>(size, 0);
                    if (offset < array1.size()) {
                      array4 := Array.thaw<Nat8>(Array.subArray<Nat8>(array3, offset, size));
                    };
                    let memory_byte_size = Vec.size(exVar.memory);
                    let memory_size_word = (memory_byte_size + 31) / 32;
                    let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                    var new_memory_cost = memory_cost;
                    if (destOffset + size > memory_byte_size) {
                      let new_memory_size_word = (destOffset + size + 31) / 32;
                      let new_memory_byte_size = new_memory_size_word * 32;
                      Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
                      new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                    };
                    if (size > 0) {
                      for (i in Iter.range(0, size - 1)) {
                        Vec.put(exVar.memory, destOffset + i, array4[i]);
                      };
                    };
                    let memory_expansion_cost = new_memory_cost - memory_cost;
                    // warm/cold address distinction not in this version
                    let newGas: Int = exVar.totalGas - 100 - memory_expansion_cost;
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

  public let op_3D_RETURNDATASIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    var returnDataSize = 0;
    switch (exVar.lastReturnData) {
      case (null) {};
      case (?data) {
        returnDataSize := data.size();
      };
    };
    switch (exVar.stack.push(returnDataSize)) {
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

  public let op_3E_RETURNDATACOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    var returnData = "" : Blob;
    var returnDataSize = 0;
    switch (exVar.lastReturnData) {
      case (null) {};
      case (?data) {
        returnData := data;
        returnDataSize := data.size();
      };
    };
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(destOffset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(offset)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(size)) {
                if (offset + size > returnDataSize) {
                  return #err("offset + size is larger than RETURNDATASIZE")
                };
                let array1 = Blob.toArray(returnData);
                let array2 = Array.freeze<Nat8>(Array.init<Nat8>(size, 0));
                let array3 = Array.append<Nat8>(array1, array2);
                var array4 = Array.init<Nat8>(size, 0);
                if (offset < array1.size()) {
                  array4 := Array.thaw<Nat8>(Array.subArray<Nat8>(array3, offset, size));
                };
                let memory_byte_size = Vec.size(exVar.memory);
                let memory_size_word = (memory_byte_size + 31) / 32;
                let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                var new_memory_cost = memory_cost;
                if (destOffset + size > memory_byte_size) {
                  let new_memory_size_word = (destOffset + size + 31) / 32;
                  let new_memory_byte_size = new_memory_size_word * 32;
                  Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
                  new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                };
                if (size > 0) {
                  for (i in Iter.range(0, size - 1)) {
                    Vec.put(exVar.memory, destOffset + i, array4[i]);
                  };
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
    };
  };

  public let op_3F_EXTCODEHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(addressNat)) {
        let addressBuffer = Buffer.Buffer<Nat8>(20);
        for (i in Iter.revRange(19, 0)) {
          addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
        let accountData = Trie.get(exCon.accounts, key address, Blob.equal);
        var extCode = Array.init<Nat8>(0, 0);
        var codeHash = "" : Blob;
        var codeHashNat = 0;
        var addressExists = false;
        switch (accountData) {
          case (null) {};
          case (?data) {
            let decodedData = decodeAccount(data);
            codeHash := decodedData.3;
            addressExists := true;
          };
        };
        // Check for any changes during the current execution
        var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(extCode)));
        for (change in Map.entries(exVar.codeAdditions)) {
          if (change.0 == codeChangeKey) {
            switch (change.1.newValue) {
              case (null) {
                codeHash := "" : Blob;
              };
              case (?newCode) {
                extCode := Array.thaw<Nat8>(newCode);
                codeHash := getCodeHash(newCode);
                codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), newCode));
              };
            };
          };
        };
        var pos = 32;
        if (addressExists) {
          for (val in codeHash.vals()) {
            pos -= 1;
            codeHashNat += Nat8.toNat(val) * (256 ** pos);
          };
        };
        switch (exVar.stack.push(codeHashNat)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
            let newGas: Int = exVar.totalGas - 100; // warm/cold address distinction not in this version
            if (newGas < 0) {
                  return #err("Out of gas")
                  } else {
                  exVar.totalGas := Int.abs(newGas);
                  return #ok(exVar); };
          };
        }; 
      };
    };
  };

  public let op_40_BLOCKHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(blockNumber)) {
        let index: Int = exCon.blockInfo.number - blockNumber - 1;
        var result: Nat = 0;
        if ((index >= 0) and (index < exCon.blockHashes.size())) {
          let hashTuple = exCon.blockHashes[Int.abs(index)];
          var pos: Nat = hashTuple.1.size();
          for (byte: Nat8 in hashTuple.1.vals()) {
            pos -= 1;
            result += Nat8.toNat(byte) * (256 ** pos);
          };
        };
        switch (exVar.stack.push(result)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
            let newGas: Int = exVar.totalGas - 20;
            if (newGas < 0) {
                  return #err("Out of gas")
                  } else {
                  exVar.totalGas := Int.abs(newGas);
                  return #ok(exVar); };
          };
        };
      };
    };
  };

  public let op_41_COINBASE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    var pos: Nat = 20;
    var result: Nat = 0;
    for (byte: Nat8 in exCon.blockInfo.coinbase.vals()) {
      pos -= 1;
      result += Nat8.toNat(byte) * (256 ** pos);
    };
    switch (exVar.stack.push(result)) {
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

  public let op_42_TIMESTAMP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.blockInfo.timestamp)) {
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

  public let op_43_NUMBER = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.blockInfo.number)) {
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

  public let op_44_DIFFICULTY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.blockInfo.difficulty)) {
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

  public let op_45_GASLIMIT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.blockInfo.gasLimit)) {
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

  public let op_46_CHAINID = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(exCon.blockInfo.chainId)) {
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

  public let op_47_SELFBALANCE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let address = exCon.caller;
    let accountData = Trie.get(exCon.accounts, key address, Blob.equal);
    var balance = 0;
    switch (accountData) {
      case (null) {};
      case (?data) {
        let decodedData = decodeAccount(data);
        balance := decodedData.1;
      };
    };
    for (change in Vec.vals(exVar.balanceChanges)) {
      if (change.from == address) {balance -= change.amount};
      if (change.to == address) {balance += change.amount};
    };
    switch (exVar.stack.push(balance)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {};
    };
    let newGas: Int = exVar.totalGas - 5;
    if (newGas < 0) {
      return #err("Out of gas")
      } else {
      exVar.totalGas := Int.abs(newGas);
      return #ok(exVar);
    };
  };

  public let op_48_BASEFEE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(0)) { // Base fee has not been included in the defined execution context.
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
}
