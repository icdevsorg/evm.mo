import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Trie "mo:base/Trie";
import Map "mo:map/Map";
import Vec "mo:vector";
import Sha3 "mo:sha3/";
import T "types";
import { key } "utils";
import { encodeAccount; decodeAccount; encodeAddressNonce } "rlp";

module {
  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  // System Operations (0xF0-0xFF)
  // These operations handle contract creation, calls, returns, and destruction

  private let { bhash } = Map;
  
  // Helper function to get code hash
  private func getCodeHash(code: [Nat8]) : Blob {
    var sha = Sha3.Keccak(256);
    sha.update(code);
    Blob.fromArray(sha.finalize());
  };

  // Helper function for subcontext execution
  private func executeSubcontext(
    code: [Nat8],
    gas: Nat,
    value: Nat,
    address: Blob,
    addressNat: Nat,
    calldata: Blob,
    exCon: T.ExecutionContext,
    exVar: T.ExecutionVariables,
    engineInstance: T.Engine
  ) : T.ExecutionVariables {
    // This is a complex function that would need to be imported or copied
    // For now, returning a default execution variables structure
    exVar // placeholder
  };

  public let op_F0_CREATE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(offset)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(size)) {
                if (exVar.staticCall > 0) {
                  return #err("Disallowed opcode CREATE called within STATICCALL")
                };
                // adjust memory size if necessary
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
                // get initialisation code from memory
                let dataBuffer = Buffer.Buffer<Nat8>(4);
                if (size > 0) {
                  for (pos in Iter.range(offset, offset + size - 1)) {
                    dataBuffer.add(Vec.get(exVar.memory, pos));
                  };
                };
                let initCode = Buffer.toArray<Nat8>(dataBuffer);
                // get caller balance and nonce
                let callerAddress = exCon.caller;
                let callerAccountData = Trie.get(exCon.accounts, key callerAddress, Blob.equal);
                var callerBalance = 0;
                var callerNonce = 0;
                switch (callerAccountData) {
                  case (null) {};
                  case (?data) {
                    let decodedData = decodeAccount(data);
                    callerBalance := decodedData.1;
                    callerNonce := decodedData.0;
                  };
                };
                for (change in Vec.vals(exVar.balanceChanges)) {
                  if (change.from == exCon.caller) {callerBalance -= change.amount;};
                  if (change.to == exCon.caller) {callerBalance += change.amount;};
                };
                // calculate address of new account
                //   address = keccak256(rlp([sender_address,sender_nonce]))[12:]
                let encodedBlob = encodeAddressNonce(callerAddress, callerNonce);
                var sha = Sha3.Keccak(256);
                sha.update(Blob.toArray(encodedBlob));
                let hashedRLP = sha.finalize();
                let addressArray = Array.subArray<Nat8>(hashedRLP, 12, 20);
                let address = Blob.fromArray(addressArray);
                // check if account already exists at address
                var addressIsNew = true;
                let newAccountData = Trie.get(exCon.accounts, key address, Blob.equal);
                switch (newAccountData) {
                  case (null) {
                    for (change in Vec.vals(exVar.balanceChanges)) {
                      if (change.to == exCon.caller) { addressIsNew := false; };
                    };
                  };
                  case (?data) {
                    addressIsNew := false;
                  };
                };
                // execute a subcontext with the initialisation code
                var result = 1;
                var gasUsed = 0;
                let gas = exVar.totalGas * 63 / 64;
                if (value <= callerBalance and addressIsNew) {
                  let subcontext = executeSubcontext(
                    initCode,
                    gas,
                    value,
                    address,
                    0,
                    "" : Blob, // calldata
                    exCon,
                    exVar,
                    engineInstance
                  );
                  // persist state changes from subcontext
                  exVar.balanceChanges := subcontext.balanceChanges;
                  exVar.storageChanges := subcontext.storageChanges;
                  exVar.codeAdditions := subcontext.codeAdditions;
                  exVar.codeStore := subcontext.codeStore;
                  exVar.storageStore := subcontext.storageStore;
                  exVar.lastReturnData := null;
                  // add initialisation subcontext return data as new account code
                  switch (subcontext.returnData) {
                    case (null) {};
                    case (?data) {
                      let code = Blob.toArray(data);
                      let emptyCode = Array.init<Nat8>(0, 0);
                      let codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                      let newCodeChange: T.CodeChange = {
                        key = codeChangeKey;
                        originalValue = [] : [T.OpCode];
                        newValue = Option.make(code);
                      };
                      Map.set(exVar.codeAdditions, bhash, codeChangeKey, newCodeChange);
                      Map.set(exVar.codeStore, bhash, getCodeHash(code), code);
                    };
                  };
                  gasUsed := gas - subcontext.totalGas - subcontext.gasRefund;
                } else {
                  result := 0;
                };
                // push to stack: the address of the deployed contract, or 0 if the deployment failed
                if (result > 0) {
                  var pos: Nat = 20;
                  result := 0;
                  for (byte: Nat8 in address.vals()) {
                    pos -= 1;
                    result += Nat8.toNat(byte) * (256 ** pos);
                  };
                };
                switch (exVar.stack.push(result)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(_)) {
                    // calculate gas
                    let memory_expansion_cost = new_memory_cost - memory_cost;
                    let minimum_word_size = (size + 31) / 32;
                    let init_code_cost = 2 * minimum_word_size;
                    let code_deposit_cost = 200 * initCode.size();
                    let dynamic_gas = init_code_cost + memory_expansion_cost + gasUsed + code_deposit_cost;
                    let newGas: Int = exVar.totalGas - 32000 - dynamic_gas;
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

}