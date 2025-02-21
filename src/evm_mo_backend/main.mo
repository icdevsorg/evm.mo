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
import { key } "utils";
import { op_4A_BLOBBASEFEE } "op_4A_BLOBBASEFEE";
import { op_5C_TLOAD } "op_5C_TLOAD";
import { op_5D_TSTORE } "op_5D_TSTORE";
import { op_5E_MCOPY } "op_5E_MCOPY";
import { op_49_BLOBHASH } "op_49_BLOBHASH";

module {
  
  type Result<Ok, Err> = { #ok: Ok; #err: Err};
  type Vec<X> = Vec.Vector<X>;
  type Map<K, V> = Map.Map<K, V>;
  type Trie<K, V> = Trie.Trie<K, V>;
  type Key<K> = Trie.Key<K>;
 

  public func stateTransition(
    tx: T.Transaction,
    callerState: T.CallerState, // in production, would be derived from the accounts Trie
    calleeState: T.CalleeState, // in production, would be derived from the accounts Trie or created anew
    gasPrice: Nat,
    blockHashes: [(Nat, Blob)], // changed from Vec<(Nat, Blob)> to Array
    accounts: Trie<Blob, Blob>,
    blockInfo: T.BlockInfo,
    engineInstance : T.Engine
  ) : async T.ExecutionContext {
    // Add (or replace) caller and callee details in accounts Trie
    let encodedCallerState = encodeAccount((callerState.nonce, callerState.balance, getStorageRoot(callerState.storage), getCodeHash(callerState.code)));
    let encodedCalleeState = encodeAccount((calleeState.nonce, calleeState.balance, getStorageRoot(calleeState.storage), getCodeHash(calleeState.code)));
    let accounts1 = Trie.put(accounts, key(tx.caller), Blob.equal, encodedCallerState).0;
    let accounts2 = Trie.put(accounts1, key(tx.callee), Blob.equal, encodedCalleeState).0;
    // Add codeHash to codeStore for each account
    let codeStore = Map.new<Blob, [T.OpCode]>();
    Map.set(codeStore, bhash, getCodeHash(callerState.code), callerState.code);
    Map.set(codeStore, bhash, getCodeHash(calleeState.code), calleeState.code);
    // Add coinbase to accounts. In production, would be derived from the accounts Trie.
    let encodedCoinbaseState = encodeAccount(1, 0, getStorageRoot(Trie.empty()), getCodeHash([]));
    let accounts3 = Trie.put(accounts2, key(blockInfo.blockCoinbase), Blob.equal, encodedCoinbaseState).0;
    Map.set(codeStore, bhash, getCodeHash([]), []);
    // Add storageRoot to storageStore for caller and callee accounts
    let storageStore = Vec.new<(Blob, Blob)>();
    for ((k, v) in Trie.iter(callerState.storage)) {
      let storageChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(tx.caller), Blob.toArray(k)));
      Vec.add(storageStore, (tx.caller, storageChangeKey));
    };
    for ((k, v) in Trie.iter(calleeState.storage)) {
      let storageChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(tx.callee), Blob.toArray(k)));
      Vec.add(storageStore, (tx.callee, storageChangeKey));
    };
    // TODO - Note that the code above does not account for other pre-existing storage or code within accounts

    // Check Transaction has right number of values => will trap if not
    // Check signature is valid => not applicable for this version
    // Check that nonce matches nonce in sender's account => TODO
    // Calculate the transaction fee as STARTGAS(=gasLimitTx) * GASPRICE,
    let fee: Nat = tx.gasLimitTx * gasPrice;
    // check that caller is willing to pay at gasPrice,
    assert (gasPrice <= tx.gasPriceTx);
    // and determine the sending address from the signature (not in this version).
    // Subtract the fee from the sender's account balance and [increment the sender's nonce](TODO). If there is not enough balance to spend, return an error.
    var balanceChanges = Vec.new<T.BalanceChange>();
    assert (fee + tx.incomingEth <= callerState.balance);
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = blockInfo.blockCoinbase;
      amount = fee;
    });
    // Initialize GAS = STARTGAS, and take off a certain quantity of gas per byte to pay for the bytes in the transaction
    // gas per byte not included in this version
    // Transfer the transaction value from the sender's account to the receiving account.
    // Check that ((T.CallerState.balance - fee) > tx.incomingEth) => included above for this version
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = tx.callee;
      amount = tx.incomingEth;
    });
    // If the receiving account does not yet exist, create it => implemented above

    let exCon: T.ExecutionContext = {
      origin = tx.caller;
      code = calleeState.code;
      programCounter = 0; 
      stack = [];
      memory = [];
      tempMemory = Trie.empty();
      contractStorage = calleeState.storage; 
      caller = tx.caller;
      callee = tx.callee;
      currentGas = tx.gasLimitTx;
      gasPrice = gasPrice;
      incomingEth = tx.incomingEth; 
      balanceChanges = Vec.toArray<T.BalanceChange>(balanceChanges); 
      storageChanges = [];
      codeAdditions = []; 
      blockHashes = blockHashes; 
      codeStore = Map.toArray<Blob, [T.OpCode]>(codeStore); 
      storageStore = Vec.toArray<(Blob, Blob)>(storageStore);
      accounts = accounts3; 
      logs = []; 
      totalGas = tx.gasLimitTx;
      gasRefund = 0;
      returnData = null; 
      consensusInfo = {
        blobBaseFee = 0; // not implemented in this version
        baseFeePerGas = 0; // not implemented in this version
        prevRandao = 0; // not implemented in this version
        excessBlobGas = 0; // not implemented in this version
        parentBeaconBlockRoot = null; // not implemented in this version
      };
      blockInfo = {
        number = blockInfo.blockNumber; 
        gasLimit = blockInfo.blockGasLimit; 
        difficulty = blockInfo.blockDifficulty; 
        timestamp = blockInfo.blockTimestamp; 
        coinbase = blockInfo.blockCoinbase;
        chainId = blockInfo.chainId;
        blockCommitments = blockInfo.blockCommitments;
      };
      calldata = tx.dataTx; 
    };

    let exVar: T.ExecutionVariables = {
      var programCounter = 0; 
      var stack = EVMStack.EVMStack();
      var tempMemory = Trie.empty();
      var memory = Vec.new<Nat8>();
      var contractStorage = calleeState.storage; 
      var balanceChanges = balanceChanges; 
      var storageChanges = Map.new<Blob, T.StorageSlotChange>();
      var codeAdditions = Map.new<Blob, T.CodeChange>(); 
      var codeStore = codeStore; // Map.new<Blob, [T.OpCode]>(); 
      var storageStore = storageStore;
      var logs = Vec.new<T.LogEntry>();
      var totalGas = tx.gasLimitTx;
      var gasRefund = 0;
      var returnData = null;
      var lastReturnData = null;
      var staticCall = 0;
    };

    // If the receiving account is a contract, run the contract's code either to completion or until the execution runs out of gas.
    if (calleeState.code != []) {
      executeCode(exCon, exVar, engineInstance).0;
    } else {
      exCon;
    };
    // If the value transfer failed because the sender did not have enough money (TODO), or the code execution ran out of gas, revert all state changes except the payment of the fees, and add the fees to the miner's account.
    // Otherwise, refund the fees for all remaining gas to the sender, and send the fees paid for gas consumed to the miner.
  };

  func executeSubcontext(
    code: [T.OpCode],
    gas: Nat,
    value: Nat,
    callee: T.Address,
    codeAddress: Nat,
    calldata: Blob,
    callerExCon: T.ExecutionContext,
    callerExVar : T.ExecutionVariables,
    engineInstance : T.Engine
  ) : T.ExecutionVariables {
    // Check Transaction has right number of values => will trap if not
    // Check that nonce matches nonce in sender's account => TODO
    // Transfer the transaction value from the sender's account to the receiving account.

    var contractStorage : T.Storage = Trie.empty();
    for (element in Vec.vals(callerExVar.storageStore)) {
      if (element.0 == callee) {
        let storageChangeKey = element.1;
        let storageSlotChange = Map.get(callerExVar.storageChanges, bhash, storageChangeKey);
        switch (storageSlotChange) {
          case (null) {};
          case (?slotChange) {
            let key_ = slotChange.key;
            let value = slotChange.newValue;
            switch (value) {
              case (null) {
                contractStorage := Trie.put(contractStorage, key(key_), Blob.equal, [] : [Nat8]).0;
              };
              case (?val) {
                contractStorage := Trie.put(contractStorage, key(key_), Blob.equal, val).0
              };
            };
          };
        };
      }; 
    };

    let subExCon: T.ExecutionContext = {
      origin = callerExCon.origin;
      code = code;
      programCounter = 0; 
      stack = [];
      memory = [];
      contractStorage = contractStorage; 
      tempMemory = callerExCon.tempMemory; 
      caller = callerExCon.callee;
      callee = callee;
      currentGas = gas;
      gasPrice = callerExCon.gasPrice;
      incomingEth = value;
      balanceChanges = Vec.toArray<T.BalanceChange>(callerExVar.balanceChanges); 
      storageChanges = Map.toArray<Blob, T.StorageSlotChange>(callerExVar.storageChanges);
      codeAdditions = Map.toArray<Blob, T.CodeChange>(callerExVar.codeAdditions); 
      blockHashes = callerExCon.blockHashes; 
      codeStore = Map.toArray<Blob, [T.OpCode]>(callerExVar.codeStore); 
      storageStore = Vec.toArray<(Blob, Blob)>(callerExVar.storageStore);
      accounts = callerExCon.accounts; 
      consensusInfo = callerExCon.consensusInfo;
      logs = Vec.toArray<T.LogEntry>(callerExVar.logs);
      totalGas = gas;
      gasRefund = 0;
      returnData = null;
      blockInfo = callerExCon.blockInfo;
      calldata = calldata; 
    };

    let subExVar: T.ExecutionVariables = {
      var programCounter = 0; 
      var stack = EVMStack.EVMStack();
      var memory = Vec.new<Nat8>();
      var tempMemory = callerExVar.tempMemory;
      var contractStorage = contractStorage;
      var balanceChanges = callerExVar.balanceChanges; 
      var storageChanges = callerExVar.storageChanges;
      var codeAdditions = callerExVar.codeAdditions; 
      var codeStore = callerExVar.codeStore;
      var storageStore = callerExVar.storageStore;
      var logs = callerExVar.logs;
      var totalGas = gas;
      var gasRefund = 0;
      var returnData = null;
      var lastReturnData = null;
      var staticCall = callerExVar.staticCall;
    };

    Vec.add(subExVar.balanceChanges, {
      from = callerExCon.caller;
      to = callee;
      amount = value;
    });

    // Call pre-compile if applicable
    if (codeAddress > 0 and codeAddress < 10) {
      let codeOutput = callPreCompile[codeAddress](subExCon, subExVar, engineInstance);
      if (codeOutput.programCounter > Array.size(subExCon.code) + 1) {
        Debug.print("Precompile contract call failed");
      };
      let gasSpent = gas - codeOutput.totalGas;
      if (codeOutput.gasRefund > gasSpent / 5) {
        codeOutput.gasRefund := gasSpent / 5;
      };
      return codeOutput;
    };

    // If the receiving account is a contract, run the contract's code either to completion or until the execution runs out of gas.
    if (code != []) {
      let codeOutput = executeCode(subExCon, subExVar, engineInstance).1;
      if (codeOutput.programCounter > Array.size(subExCon.code) + 1) {
        Debug.print("Subcontext reverted");
      };
      let gasSpent = gas - codeOutput.totalGas;
      if (codeOutput.gasRefund > gasSpent / 5) {
        codeOutput.gasRefund := gasSpent / 5;
      };
      return codeOutput;
    } else {
      return subExVar;
    };
  };

  func executeCode(exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
    let codeSize = Array.size(exCon.code);
    while (Int.abs(exVar.programCounter) < codeSize) {
      // get current instruction from code[programCounter]
      let instruction = exCon.code[Int.abs(exVar.programCounter)];
      // execute instruction via OPCODE functions
      switch (engineInstance[Nat8.toNat(instruction)](exCon, exVar, engineInstance)) {
        case (#err(e)) {
          Debug.print("Error: " # e);
          let newExVar = revert(exCon);
          exVar.programCounter := newExVar.programCounter; 
          exVar.stack := newExVar.stack;
          exVar.memory := newExVar.memory;
          exVar.contractStorage := newExVar.contractStorage; 
          exVar.balanceChanges := newExVar.balanceChanges; 
          exVar.storageChanges := newExVar.storageChanges;
          exVar.codeAdditions := newExVar.codeAdditions; 
          exVar.codeStore := newExVar.codeStore; 
          exVar.storageStore := newExVar.storageStore;
          exVar.logs := newExVar.logs;
          exVar.totalGas := newExVar.totalGas;
          exVar.gasRefund := newExVar.gasRefund;
          exVar.returnData := newExVar.returnData;
          exVar.lastReturnData := newExVar.lastReturnData;
          exVar.staticCall := newExVar.staticCall;
        };
        case (#ok(output)) {
          let newExVar = output;
          newExVar.programCounter += 1;
          exVar.programCounter := newExVar.programCounter; 
          exVar.stack := newExVar.stack;
          exVar.memory := newExVar.memory;
          exVar.contractStorage := newExVar.contractStorage; 
          exVar.balanceChanges := newExVar.balanceChanges; 
          exVar.storageChanges := newExVar.storageChanges;
          exVar.codeAdditions := newExVar.codeAdditions; 
          exVar.codeStore := newExVar.codeStore; 
          exVar.storageStore := newExVar.storageStore;
          exVar.logs := newExVar.logs;
          exVar.totalGas := newExVar.totalGas;
          exVar.gasRefund := newExVar.gasRefund;
          exVar.returnData := newExVar.returnData;
          exVar.lastReturnData := newExVar.lastReturnData;
          exVar.staticCall := newExVar.staticCall;
        };
      };
    };

    var _stack: [Nat] = [];
    switch (exVar.stack.freeze()) {
      case (#err(e)) {
        // no error case
      };
      case (#ok(output)) {
        _stack := output;
      };
    };
    let stack = _stack;

    // implement gas refund
    let gasSpent = exCon.currentGas - exVar.totalGas;
    if (exVar.gasRefund > gasSpent / 5) {
      exVar.gasRefund := gasSpent / 5;
    };
    let remainingGas = exVar.totalGas + exVar.gasRefund;
    let ethRefund = remainingGas * exCon.gasPrice;
    if (exCon.caller == exCon.origin) { // not implemented within a subcontext
      Vec.add(exVar.balanceChanges, {
        from = exCon.blockInfo.coinbase;
        to = exCon.caller;
        amount = ethRefund;
      });
    };

    // Iterate through balance, code and storage changes, apply changes to existing accounts and add
    //  new accounts where necessary. 
    // TODO - Account for nonce changes.
    // If an account fits criteria indicating a SELFDESTRUCT operation, i.e. that it was added anew in
    //  the current transaction (i.e. not already in the accounts trie), has zero balance and has a code
    //  change to empty code then it will not be included in the updated accounts trie.
    var updatedAccounts = exCon.accounts;

    // Update balances
    for (element in Vec.vals(exVar.balanceChanges)) {
      let fromAccount = element.from;
      let toAccount = element.to;
      let amount = element.amount;
      let fromAccountData = Trie.get(updatedAccounts, key fromAccount, Blob.equal);
      switch (fromAccountData) {
        case (null) {
          Debug.print("Invalid 'from' account included in exVar.balanceChanges."); // This should not happen
          Debug.print(debug_show(element));
          return (exCon, revert(exCon));
        };
        case (?data) {
          let decodedData = decodeAccount(data);
          let newBalance = decodedData.1 - amount;
          let updatedEncodedData = encodeAccount(decodedData.0, newBalance, decodedData.2, decodedData.3);
          updatedAccounts := Trie.put(updatedAccounts, key(fromAccount), Blob.equal, updatedEncodedData).0;
        };
      };
      let toAccountData = Trie.get(updatedAccounts, key toAccount, Blob.equal);
      switch (toAccountData) {
        case (null) { // add new account
          let encodedData = encodeAccount(0, amount, getStorageRoot(Trie.empty()), getCodeHash([]));
          updatedAccounts := Trie.put(updatedAccounts, key(toAccount), Blob.equal, encodedData).0;
        };
        case (?data) {
          let decodedData = decodeAccount(data);
          let newBalance = decodedData.1 + amount;
          let updatedEncodedData = encodeAccount(decodedData.0, newBalance, decodedData.2, decodedData.3);
          updatedAccounts := Trie.put(updatedAccounts, key(toAccount), Blob.equal, updatedEncodedData).0;
        };
      };
    };

    // Update code and storage
    let accountsIter = Trie.iter(updatedAccounts);
    for ((address, accountData) in accountsIter) {
      var removedAccount = false;
      var decodedData = decodeAccount(accountData);
      // getCodeHash(address + starting code) will be the first key
      let emptyCode = Array.init<Nat8>(0, 0);
      var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
      // if address is in exCon.accounts then starting code is from there
      let startingAccountData = Trie.get(exCon.accounts, key address, Blob.equal);
      switch (startingAccountData) {
        case (null) {}; // new account, so starting code is emptyCode
        case (?data) {
          let decodedStartingData = decodeAccount(data);
          let startingCode = decodedStartingData.3;
          codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Blob.toArray(startingCode)));
        };
      };

      // Iterate through exVar.codeAdditions and make changes
      for (change in Map.entries(exVar.codeAdditions)) {
        var newCode = emptyCode;
        if (change.0 == codeChangeKey) {
          switch (change.1.newValue) {
            case (null) {
              codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
              // if change to no code, balance is 0 and address is not in exCon.accounts then flag as removedAccount
              switch (Trie.get(exCon.accounts, key address, Blob.equal)) {
                case (?account) {};
                case (null) {
                  if (decodedData.1 == 0) {
                    removedAccount := true;
                  };
                };
              };
            };
            case (?code) {
              newCode := Array.thaw<Nat8>(code);
              codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(newCode)));
            };
          };
          let updatedEncodedData_ = encodeAccount(decodedData.0, decodedData.1, decodedData.2, getCodeHash(Array.freeze<Nat8>(newCode)));
          updatedAccounts := Trie.put(updatedAccounts, key(address), Blob.equal, updatedEncodedData_).0;
        };
      };
      
      // Iterate through exVar.storageStore and make changes
      var contractStorage : T.Storage = Trie.empty();
      for (element in Vec.vals(exVar.storageStore)) {
        if (element.0 == address) {
          let storageChangeKey = element.1;
          let storageSlotChange = Map.get(exVar.storageChanges, bhash, storageChangeKey);
          switch (storageSlotChange) {
            case (null) {};
            case (?slotChange) {
              let key_ = slotChange.key;
              let value = slotChange.newValue;
              switch (value) {
                case (null) {
                  contractStorage := Trie.put(contractStorage, key(key_), Blob.equal, [] : [Nat8]).0;
                };
                case (?val) {
                  contractStorage := Trie.put(contractStorage, key(key_), Blob.equal, val).0
                };
              };
            };
          };
        };
      };
      if (address == exCon.callee) {
        exVar.contractStorage := contractStorage;
      };
      switch (Trie.get(updatedAccounts, key address, Blob.equal)) {
        case (null) {};
        case (?newData) {
          let newDecodedData = decodeAccount(newData);
          let updatedEncodedData = encodeAccount(newDecodedData.0, newDecodedData.1, getStorageRoot(contractStorage), newDecodedData.3);
          updatedAccounts := Trie.put(updatedAccounts, key(address), Blob.equal, updatedEncodedData).0;
        };
      };
      if (removedAccount) {
        updatedAccounts := Trie.remove(updatedAccounts, key(address), Blob.equal).0;
      };
    };

    let newExCon: T.ExecutionContext = {
      origin = exCon.origin;
      code = exCon.code;
      programCounter = Int.abs(exVar.programCounter); 
      stack = stack;
      memory = Vec.toArray<Nat8>(exVar.memory);
      contractStorage = exVar.contractStorage; 
      caller = exCon.caller;
      callee = exCon.callee;
      currentGas = exCon.currentGas;
      gasPrice = exCon.gasPrice;
      incomingEth = exCon.incomingEth; 
      balanceChanges = Vec.toArray<T.BalanceChange>(exVar.balanceChanges); 
      storageChanges = Map.toArray<Blob, T.StorageSlotChange>(exVar.storageChanges);
      codeAdditions = Map.toArray<Blob, T.CodeChange>(exVar.codeAdditions); 
      blockHashes = exCon.blockHashes; 
      codeStore = Map.toArray<Blob, [T.OpCode]>(exVar.codeStore); 
      storageStore = Vec.toArray<(Blob, Blob)>(exVar.storageStore);
      accounts = updatedAccounts; 
      logs = Vec.toArray<T.LogEntry>(exVar.logs); 
      totalGas = exVar.totalGas;
      gasRefund = exVar.gasRefund;
      returnData = exVar.returnData; 
      blockInfo = exCon.blockInfo;
      consensusInfo = exCon.consensusInfo;
      calldata = exCon.calldata; 
      tempMemory = exCon.tempMemory;
    };
    (newExCon, exVar);
  };

  func revert(exCon: T.ExecutionContext) : T.ExecutionVariables {
    // revert all state changes except payment of fees
    let storageChangesIter = Iter.fromArray<(Blob, T.StorageSlotChange)>(exCon.storageChanges);
    let codeAdditionsIter = Iter.fromArray<(Blob, T.CodeChange)>(exCon.codeAdditions);
    let codeStoreIter = Iter.fromArray<(Blob, [T.OpCode])>(exCon.codeStore);
    let newExVar: T.ExecutionVariables = {
      var programCounter = Array.size(exCon.code) + 2;
      var stack = EVMStack.EVMStack();
      var memory = Vec.new<Nat8>();
      var contractStorage = exCon.contractStorage; 
      var balanceChanges = Vec.fromArray<T.BalanceChange>(exCon.balanceChanges);
      var storageChanges = Map.fromIter<Blob, T.StorageSlotChange>(storageChangesIter, bhash);
      var codeAdditions = Map.fromIter<Blob, T.CodeChange>(codeAdditionsIter, bhash);
      var codeStore = Map.fromIter<Blob, [T.OpCode]>(codeStoreIter, bhash);
      var storageStore = Vec.fromArray<(Blob, Blob)>(exCon.storageStore);
      var logs = Vec.new<T.LogEntry>();
      var totalGas = 0;
      var gasRefund = 0;
      var returnData = null;
      var lastReturnData = null;
      var staticCall = 0;
      var tempMemory = Trie.empty();
    };
    newExVar;
  };

  func getCodeHash(code: [T.OpCode]) : Blob {
    var sha = Sha3.Keccak(256);
    sha.update(code);
    Blob.fromArray(sha.finalize());
  };

  func getStorageRoot(storage: T.Storage) : Blob {
    var trie = MPTrie.init();
    let iter = Trie.iter(storage);
    for ((k,v) in iter) {
      trie := MPTrie.put(trie, K.fromKeyBytes(Blob.toArray(k)), V.fromArray(v));
    };
    MPTrie.hash(trie);
  };

  // OPCODE FUNCTIONS

  // Basic Math and Bitwise Logic

  let op_01_ADD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    // pop two values from the stack; returns error if stack is empty
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            // add them and check for result overflow
            let result = (a + b) % 2**256;
            // push result to stack and check for stack overflow
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
                // return new execution context variables
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
    };
  };

  let op_02_MUL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let result = (a * b) % 2**256;
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 5;
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
    };
  };

  let op_03_SUB = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result: Int = a - b;
            if (result < 0) {result += 2**256};
            switch (exVar.stack.push(Int.abs(result))) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_04_DIV = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let result = if (b == 0) { 0; } else { a / b; };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 5;
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
    };
  };

  let op_05_SDIV = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var b_mod: Int = b;
            if (b_mod >= 2**255) { b_mod -= 2**256 };
            var result: Int = 0;
            if (b_mod != 0) {
              result := a_mod / b_mod;
              if (result < 0) { result += 2**256 };
            };
            switch (exVar.stack.push(Int.abs(result))) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 5;
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
    };
  };

  let op_06_MOD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let result = if (b == 0) { 0; } else { a % b; };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 5;
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
    };
  };

  let op_07_SMOD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var b_mod: Int = b;
            if (b_mod >= 2**255) { b_mod -= 2**256 };
            var result: Int = 0;
            if (b_mod != 0) {
              result := a_mod % b_mod;
              if (result < 0) { result += 2**256 };
            };
            switch (exVar.stack.push(Int.abs(result))) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 5;
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
    };
  };

  let op_08_ADDMOD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(N)) {
                let result = if (N == 0) { 0; } else { (a + b) % N; };
                switch (exVar.stack.push(result)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(_)) {
                    let newGas: Int = exVar.totalGas - 8;
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
        };
      };
    };
  };

  let op_09_MULMOD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(N)) {
                let result = if (N == 0) { 0; } else { (a * b) % N; };
                switch (exVar.stack.push(result)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(_)) {
                    let newGas: Int = exVar.totalGas - 8;
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
        };
      };
    };
  };

  let op_0A_EXP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(exponent)) {
            //modfied from https://forum.dfinity.org/t/reject-text-ic0503-canister-trapped-explicitly-bigint-function-error/26937/3
            var result: Nat = 1;
            var base_ = a;
            var exponent_ = exponent;
            while (exponent_ > 0){
              if (exponent_ % 2 == 1) result := (result * base_) % 2**256;
              exponent_ := exponent_ / 2;
              base_ := (base_ * base_) % 2**256;
            };
            var byteSize: Nat = 0;
            var num = exponent;
            while (num >= 1) {
              num /= 256;
              byteSize += 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - (10 + byteSize * 50);
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
    };
  };

  let op_0B_SIGNEXTEND = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(b)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(x)) {
            var x_mod = x % (256 ** (b + 1));
            if (x_mod >= ((256 ** (b + 1)) / 2)) {
              x_mod := 2**256 + x_mod - (256 ** (b + 1));
            };
            let result = x_mod;
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 5;
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
    };
  };

  let op_10_LT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result = 0;
            if (a < b) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_11_GT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result = 0;
            if (a > b) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_12_SLT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var b_mod: Int = b;
            if (b_mod >= 2**255) { b_mod -= 2**256 };
            var result = 0;
            if (a_mod < b_mod) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_13_SGT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var a_mod: Int = a;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var b_mod: Int = b;
            if (b_mod >= 2**255) { b_mod -= 2**256 };
            var result = 0;
            if (a_mod > b_mod) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_14_EQ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result = 0;
            if (a == b) {
              result := 1;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_15_ISZERO = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var result = 0;
        if (a ==0) {
            result := 1;
        };
        switch (exVar.stack.push(result)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
            let newGas: Int = exVar.totalGas - 3;
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

  let op_16_AND = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let a1: Nat64 = Nat64.fromNat(a / 2**192);
            let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
            let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
            let a4: Nat64 = Nat64.fromNat(a % 2**64);
            let b1: Nat64 = Nat64.fromNat(b / 2**192);
            let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
            let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
            let b4: Nat64 = Nat64.fromNat(b % 2**64);
            let result = Nat64.toNat(a1 & b1) * 2**192 + Nat64.toNat(a2 & b2) * 2**128 + Nat64.toNat(a3 & b3) * 2**64 + Nat64.toNat(a4 & b4);
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_17_OR = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let a1: Nat64 = Nat64.fromNat(a / 2**192);
            let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
            let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
            let a4: Nat64 = Nat64.fromNat(a % 2**64);
            let b1: Nat64 = Nat64.fromNat(b / 2**192);
            let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
            let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
            let b4: Nat64 = Nat64.fromNat(b % 2**64);
            let result = Nat64.toNat(a1 | b1) * 2**192 + Nat64.toNat(a2 | b2) * 2**128 + Nat64.toNat(a3 | b3) * 2**64 + Nat64.toNat(a4 | b4);
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_18_XOR = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let a1: Nat64 = Nat64.fromNat(a / 2**192);
            let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
            let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
            let a4: Nat64 = Nat64.fromNat(a % 2**64);
            let b1: Nat64 = Nat64.fromNat(b / 2**192);
            let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
            let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
            let b4: Nat64 = Nat64.fromNat(b % 2**64);
            let result = Nat64.toNat(a1 ^ b1) * 2**192 + Nat64.toNat(a2 ^ b2) * 2**128 + Nat64.toNat(a3 ^ b3) * 2**64 + Nat64.toNat(a4 ^ b4);
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_19_NOT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        let result = (2**256 - 1) - a;
        switch (exVar.stack.push(result)) {
          case (#err(e)) { return #err(e) };
          case (#ok(_)) {
            let newGas: Int = exVar.totalGas - 3;
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

  let op_1A_BYTE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(i)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(x)) {
            var result = 0;
            if (i < 32) {
              let num = x / (256 ** (31 - i));
              result := num % 256;
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_1B_SHL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(shift)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(value)) {
            let result = (value * (2 ** shift)) % 2**256;
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_1C_SHR = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(shift)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(value)) {
            let result = (value / (2 ** shift));
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
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
    };
  };

  let op_1D_SAR = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(shift)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(value)) {
            var result = (value / (2 ** shift));
            if (value >= 2**255) {
              result += (2**256 - (2 ** (256 - shift)));
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                let newGas: Int = exVar.totalGas - 3;
                if (newGas < 0) {
                  return #err("Out of gas")
                  } else {
                  exVar.totalGas := Int.abs(newGas);
                  return #ok(exVar);};
              };
            };
          };
        };
      };
    };
  };


  // Environmental Information and Block Information

  let op_30_ADDRESS = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_31_BALANCE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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
  
  let op_32_ORIGIN = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_33_CALLER = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_34_CALLVALUE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_35_CALLDATALOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_36_CALLDATASIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_37_CALLDATACOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_38_CODESIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_39_CODECOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_3A_GASPRICE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_3B_EXTCODESIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_3C_EXTCODECOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_3D_RETURNDATASIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_3E_RETURNDATACOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_3F_EXTCODEHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_40_BLOCKHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_41_COINBASE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_42_TIMESTAMP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_43_NUMBER = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_44_DIFFICULTY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_45_GASLIMIT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_46_CHAINID = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_47_SELFBALANCE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_48_BASEFEE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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


  // Memory Operations

  let op_50_POP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_51_MLOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_52_MSTORE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_53_MSTORE8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_54_SLOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_55_SSTORE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_56_JUMP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_57_JUMPI = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_58_PC = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_59_MSIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_5A_GAS = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_5B_JUMPDEST = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let newGas: Int = exVar.totalGas - 1;
    if (newGas < 0) {
      return #err("Out of gas")
    } else {
      exVar.totalGas := Int.abs(newGas);
      return #ok(exVar);
    };
  };


  // Push Operations, Duplication Operations, Exchange Operations
  
  let op_5F_PUSH0 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_60_PUSH1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    // check that there are enough operands
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + 2) {return #err("Not enough operands")};
    switch (exVar.stack.push(Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + 1]))) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += 1;
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

  let op_61_PUSH2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 2;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_62_PUSH3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 3;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_63_PUSH4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 4;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_64_PUSH5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 5;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_65_PUSH6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 6;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_66_PUSH7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 7;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_67_PUSH8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 8;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_68_PUSH9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 9;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_69_PUSH10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 10;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_6A_PUSH11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 11;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_6B_PUSH12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 12;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_6C_PUSH13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 13;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_6D_PUSH14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 14;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_6E_PUSH15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 15;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_6F_PUSH16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 16;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_70_PUSH17 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 17;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_71_PUSH18 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 18;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_72_PUSH19 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 19;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_73_PUSH20 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 20;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_74_PUSH21 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 21;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_75_PUSH22 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 22;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_76_PUSH23 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 23;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_77_PUSH24 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 24;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_78_PUSH25 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 25;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_79_PUSH26 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 26;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_7A_PUSH27 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 27;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_7B_PUSH28 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 28;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_7C_PUSH29 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 29;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_7D_PUSH30 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 30;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_7E_PUSH31 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 31;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_7F_PUSH32 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    let bytes = 32;
    if (Array.size(exCon.code) < Int.abs(exVar.programCounter) + bytes + 1) {return #err("Not enough operands")};
    var value: Nat = 0;
    for (i in Iter.range(1, bytes)) {
      value += Nat8.toNat(exCon.code[Int.abs(exVar.programCounter) + i]) * (256 ** (bytes - i));
    };
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(())) {
        exVar.programCounter += bytes;
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

  let op_80_DUP1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_81_DUP2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(1)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_82_DUP3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(2)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_83_DUP4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(3)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_84_DUP5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(4)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_85_DUP6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(5)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_86_DUP7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(6)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_87_DUP8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(7)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_88_DUP9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(8)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_89_DUP10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(9)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_8A_DUP11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(10)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_8B_DUP12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(11)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_8C_DUP13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(12)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_8D_DUP14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(13)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_8E_DUP15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(14)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_8F_DUP16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(15)) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.push(value)) {
          case (#err(e)) { return #err(e) };
          case (#ok()) {
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

  let op_90_SWAP1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(1)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(1, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_91_SWAP2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(2)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(2, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_92_SWAP3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(3)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(3, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_93_SWAP4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(4)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(4, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_94_SWAP5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(5)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(5, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_95_SWAP6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(6)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(6, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_96_SWAP7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(7)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(7, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_97_SWAP8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(8)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(8, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_98_SWAP9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(9)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(9, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_99_SWAP10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(10)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(10, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_9A_SWAP11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(11)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(11, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_9B_SWAP12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(12)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(12, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_9C_SWAP13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(13)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(13, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_9D_SWAP14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(14)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(14, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_9E_SWAP15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(15)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(15, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };

  let op_9F_SWAP16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.peek(0)) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.peek(16)) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            switch (exVar.stack.poke(0, b)) {
              case (#err(e)) { return #err(e) };
              case (#ok()) {
                switch (exVar.stack.poke(16, a)) {
                  case (#err(e)) { return #err(e) };
                  case (#ok()) {
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
        };
      };
    };
  };


  // Logging Operations

  let op_A0_LOG0 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG0 called within STATICCALL")
            };
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
            let data = Blob.fromArray(dataArray);
            let topics : [Blob] = [];
            let logEntry : T.LogEntry = { topics = topics; data = data; };
            Vec.add(exVar.logs, logEntry);
            let memory_expansion_cost = new_memory_cost - memory_cost;
            var topic_count = 0;
            for (entry in Vec.vals(exVar.logs)) {
              topic_count += entry.topics.size();
            };
            let dynamic_gas = 375 * topic_count + 8 * size + memory_expansion_cost;
            let newGas: Int = exVar.totalGas - 375 - dynamic_gas;
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

  let op_A1_LOG1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG1 called within STATICCALL")
            };
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
            let data = Blob.fromArray(dataArray);
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(topic1Nat)) {
                let topic1Buffer = Buffer.Buffer<Nat8>(32);
                for (i in Iter.revRange(31, 0)) {
                  topic1Buffer.add(Nat8.fromNat((topic1Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                };
                let topic1 = Blob.fromArray(Buffer.toArray<Nat8>(topic1Buffer));
                let topics : [Blob] = [topic1];
                let logEntry : T.LogEntry = { topics = topics; data = data; };
                Vec.add(exVar.logs, logEntry);
                let memory_expansion_cost = new_memory_cost - memory_cost;
                var topic_count = 0;
                for (entry in Vec.vals(exVar.logs)) {
                  topic_count += entry.topics.size();
                };
                let dynamic_gas = 375 * topic_count + 8 * size + memory_expansion_cost;
                let newGas: Int = exVar.totalGas - 375 - dynamic_gas;
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

  let op_A2_LOG2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG2 called within STATICCALL")
            };
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
            let data = Blob.fromArray(dataArray);
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(topic1Nat)) {
                let topic1Buffer = Buffer.Buffer<Nat8>(32);
                for (i in Iter.revRange(31, 0)) {
                  topic1Buffer.add(Nat8.fromNat((topic1Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                };
                let topic1 = Blob.fromArray(Buffer.toArray<Nat8>(topic1Buffer));
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(topic2Nat)) {
                    let topic2Buffer = Buffer.Buffer<Nat8>(32);
                    for (i in Iter.revRange(31, 0)) {
                      topic2Buffer.add(Nat8.fromNat((topic2Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                    };
                    let topic2 = Blob.fromArray(Buffer.toArray<Nat8>(topic2Buffer));
                    let topics : [Blob] = [topic1, topic2];
                    let logEntry : T.LogEntry = { topics = topics; data = data; };
                    Vec.add(exVar.logs, logEntry);
                    let memory_expansion_cost = new_memory_cost - memory_cost;
                    var topic_count = 0;
                    for (entry in Vec.vals(exVar.logs)) {
                      topic_count += entry.topics.size();
                    };
                    let dynamic_gas = 375 * topic_count + 8 * size + memory_expansion_cost;
                    let newGas: Int = exVar.totalGas - 375 - dynamic_gas;
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

  let op_A3_LOG3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG3 called within STATICCALL")
            };
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
            let data = Blob.fromArray(dataArray);
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(topic1Nat)) {
                let topic1Buffer = Buffer.Buffer<Nat8>(32);
                for (i in Iter.revRange(31, 0)) {
                  topic1Buffer.add(Nat8.fromNat((topic1Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                };
                let topic1 = Blob.fromArray(Buffer.toArray<Nat8>(topic1Buffer));
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(topic2Nat)) {
                    let topic2Buffer = Buffer.Buffer<Nat8>(32);
                    for (i in Iter.revRange(31, 0)) {
                      topic2Buffer.add(Nat8.fromNat((topic2Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                    };
                    let topic2 = Blob.fromArray(Buffer.toArray<Nat8>(topic2Buffer));
                    switch (exVar.stack.pop()) {
                      case (#err(e)) { return #err(e) };
                      case (#ok(topic3Nat)) {
                        let topic3Buffer = Buffer.Buffer<Nat8>(32);
                        for (i in Iter.revRange(31, 0)) {
                          topic3Buffer.add(Nat8.fromNat((topic3Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                        };
                        let topic3 = Blob.fromArray(Buffer.toArray<Nat8>(topic3Buffer));
                        let topics : [Blob] = [topic1, topic2, topic3];
                        let logEntry : T.LogEntry = { topics = topics; data = data; };
                        Vec.add(exVar.logs, logEntry);
                        let memory_expansion_cost = new_memory_cost - memory_cost;
                        var topic_count = 0;
                        for (entry in Vec.vals(exVar.logs)) {
                          topic_count += entry.topics.size();
                        };
                        let dynamic_gas = 375 * topic_count + 8 * size + memory_expansion_cost;
                        let newGas: Int = exVar.totalGas - 375 - dynamic_gas;
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
    };
  };

  let op_A4_LOG4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG4 called within STATICCALL")
            };
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
            let data = Blob.fromArray(dataArray);
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(topic1Nat)) {
                let topic1Buffer = Buffer.Buffer<Nat8>(32);
                for (i in Iter.revRange(31, 0)) {
                  topic1Buffer.add(Nat8.fromNat((topic1Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                };
                let topic1 = Blob.fromArray(Buffer.toArray<Nat8>(topic1Buffer));
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(topic2Nat)) {
                    let topic2Buffer = Buffer.Buffer<Nat8>(32);
                    for (i in Iter.revRange(31, 0)) {
                      topic2Buffer.add(Nat8.fromNat((topic2Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                    };
                    let topic2 = Blob.fromArray(Buffer.toArray<Nat8>(topic2Buffer));
                    switch (exVar.stack.pop()) {
                      case (#err(e)) { return #err(e) };
                      case (#ok(topic3Nat)) {
                        let topic3Buffer = Buffer.Buffer<Nat8>(32);
                        for (i in Iter.revRange(31, 0)) {
                          topic3Buffer.add(Nat8.fromNat((topic3Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                        };
                        let topic3 = Blob.fromArray(Buffer.toArray<Nat8>(topic3Buffer));
                        switch (exVar.stack.pop()) {
                          case (#err(e)) { return #err(e) };
                          case (#ok(topic4Nat)) {
                            let topic4Buffer = Buffer.Buffer<Nat8>(32);
                            for (i in Iter.revRange(31, 0)) {
                              topic4Buffer.add(Nat8.fromNat((topic4Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                            };
                            let topic4 = Blob.fromArray(Buffer.toArray<Nat8>(topic4Buffer));
                            let topics : [Blob] = [topic1, topic2, topic3, topic4];
                            let logEntry : T.LogEntry = { topics = topics; data = data; };
                            Vec.add(exVar.logs, logEntry);
                            let memory_expansion_cost = new_memory_cost - memory_cost;
                            var topic_count = 0;
                            for (entry in Vec.vals(exVar.logs)) {
                              topic_count += entry.topics.size();
                            };
                            let dynamic_gas = 375 * topic_count + 8 * size + memory_expansion_cost;
                            let newGas: Int = exVar.totalGas - 375 - dynamic_gas;
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
        };
      };
    };
  };


  // Execution and System Operations
  
  let op_00_STOP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    exVar.programCounter := Array.size(exCon.code);
    return #ok(exVar);
  };

  let op_F0_CREATE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_F1_CALL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(gas_)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(addressNat)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(value)) {
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(argsOffset)) {
                    switch (exVar.stack.pop()) {
                      case (#err(e)) { return #err(e) };
                      case (#ok(argsSize)) {
                        switch (exVar.stack.pop()) {
                          case (#err(e)) { return #err(e) };
                          case (#ok(retOffset)) {
                            switch (exVar.stack.pop()) {
                              case (#err(e)) { return #err(e) };
                              case (#ok(retSize)) {
                                if (exVar.staticCall > 0 and value > 0) {
                                  return #err("Disallowed opcode CALL (value > 0) called within STATICCALL")
                                };
                                // get calldata from memory
                                let memory_byte_size = Vec.size(exVar.memory);
                                let memory_size_word = (memory_byte_size + 31) / 32;
                                let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                                var new_memory_cost = memory_cost;
                                if (argsOffset + argsSize > memory_byte_size) {
                                  let new_memory_size_word = (argsOffset + argsSize + 31) / 32;
                                  let new_memory_byte_size = new_memory_size_word * 32;
                                  Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
                                  new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                                };
                                var calldata = "" : Blob;
                                if (argsSize > 0) {
                                  let calldataBuffer = Buffer.Buffer<Nat8>(argsSize);
                                  for (pos in Iter.range(0, argsSize - 1)) {
                                    calldataBuffer.add(Vec.get(exVar.memory, argsOffset + pos));
                                  };
                                  calldata := Blob.fromArray(Buffer.toArray<Nat8>(calldataBuffer));
                                };
                                // get code from code store
                                let addressBuffer = Buffer.Buffer<Nat8>(20);
                                for (i in Iter.revRange(19, 0)) {
                                  addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                                };
                                let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
                                let emptyCode = Array.init<Nat8>(0, 0);
                                var newCode = emptyCode;
                                var emptyAccountCost = 0;
                                var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                                let startingAccountData = Trie.get(exCon.accounts, key address, Blob.equal);
                                switch (startingAccountData) {
                                  case (null) { // new account is being called
                                    if (value > 0 and addressNat > 9) {
                                      emptyAccountCost := 25000;
                                    };
                                  };
                                  case (?data) {
                                    let decodedStartingData = decodeAccount(data);
                                    let startingCode = decodedStartingData.3;
                                    codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Blob.toArray(startingCode)));
                                  };
                                };
                                for (change in Map.entries(exVar.codeAdditions)) {
                                  if (change.0 == codeChangeKey) {
                                    switch (change.1.newValue) {
                                      case (null) {
                                        codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                                      };
                                      case (?someCode) {
                                        newCode := Array.thaw<Nat8>(someCode);
                                        codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(newCode)));
                                      };
                                    };
                                  };
                                };
                                let code = Array.freeze<Nat8>(newCode);
                                // check gas; gas is capped at all but one 64th (remaining_gas / 64) of
                                // the remaining gas of the current context; if more then change it
                                var gas = gas_;
                                if (gas > exVar.totalGas * 63 / 64) {
                                  gas := exVar.totalGas * 63 / 64;
                                };
                                var stipend = 0;
                                if (value > 0) { stipend := 2300; };
                                gas += stipend;
                                // check caller balance
                                let callerAddress = exCon.caller;
                                let callerAccountData = Trie.get(exCon.accounts, key callerAddress, Blob.equal);
                                var callerBalance = 0;
                                switch (callerAccountData) {
                                  case (null) {};
                                  case (?data) {
                                    let decodedData = decodeAccount(data);
                                    callerBalance := decodedData.1;
                                  };
                                };
                                for (change in Vec.vals(exVar.balanceChanges)) {
                                  if (change.from == exCon.caller) {callerBalance -= change.amount;};
                                  if (change.to == exCon.caller) {callerBalance += change.amount;};
                                };
                                // if value <= caller balance then run subcontext
                                // otherwise the call fails but the current context is not reverted
                                var result = 0; // 1 if successful
                                var memory_expansion_cost = 0;
                                var code_execution_cost = 0;
                                if (value <= callerBalance) {
                                  let subcontext = executeSubcontext(
                                    code,
                                    gas,
                                    value,
                                    address,
                                    addressNat,
                                    calldata,
                                    exCon,
                                    exVar,
                                    engineInstance
                                  );
                                  if (subcontext.programCounter <= code.size() + 1) {
                                    result := 1;
                                  };
                                  // store return data in memory
                                  var returnData = "" : Blob;
                                  switch (subcontext.returnData) {
                                    case (null) {};
                                    case (?returnData_) {
                                      returnData := returnData_;
                                      var returnDataArray = Blob.toArray(returnData);
                                      if (returnDataArray.size() > retSize) {
                                        let resizedArray = Array.subArray<Nat8>(returnDataArray, 0, retSize);
                                        returnData := Blob.fromArray(resizedArray);
                                      };
                                      let memory_byte_size = Vec.size(exVar.memory);
                                      let memory_size_word = (memory_byte_size + 31) / 32;
                                      let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                                      var new_memory_cost = memory_cost;
                                      if (retOffset + retSize > memory_byte_size) {
                                        let new_memory_size_word = (retOffset + retSize + 31) / 32;
                                        let new_memory_byte_size = new_memory_size_word * 32;
                                        let mem_incr = new_memory_byte_size - memory_byte_size;
                                        Vec.addMany(exVar.memory, mem_incr, Nat8.fromNat(0));
                                        new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                                      };
                                      var pos = retOffset;
                                      for (byte in returnData.vals()) {
                                        Vec.put(exVar.memory, pos, byte);
                                        pos += 1;
                                      };
                                      memory_expansion_cost := new_memory_cost - memory_cost;
                                    };
                                  };
                                  code_execution_cost := gas - subcontext.totalGas - subcontext.gasRefund;
                                  // persist state changes from subcontext
                                  exVar.balanceChanges := subcontext.balanceChanges;
                                  exVar.storageChanges := subcontext.storageChanges;
                                  exVar.codeAdditions := subcontext.codeAdditions;
                                  exVar.codeStore := subcontext.codeStore;
                                  exVar.storageStore := subcontext.storageStore;
                                  exVar.lastReturnData := subcontext.returnData;
                                };
                                // success?
                                switch (exVar.stack.push(result)) {
                                  case (#err(e)) { return #err(e) };
                                  case (#ok(_)) {
                                    // code_execution_cost is the cost of the called code execution (limited by the gas parameter).
                                    // If address is warm, then address_access_cost is 100, otherwise it is 2600. (Not used in this version.)
                                    // If value is not 0, then positive_value_cost is 9000. In this case there is also a call stipend that is given to make sure that a basic fallback function can be called. 2300 is thus removed from the cost, and also added to the gas input.
                                    // If value is not 0 and the address given points to an empty account, then value_to_empty_account_cost is 25000. An account is empty if its balance is 0, its nonce is 0 and it has no code.
                                    var newGas: Int = exVar.totalGas - 100 - memory_expansion_cost - stipend - emptyAccountCost - code_execution_cost;
                                    if (value > 0) { newGas -= 9000; };
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
                };
              };
            };
          };
        };
      };
    };
  };

  let op_F2_CALLCODE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(gas_)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(addressNat)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(value)) {
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(argsOffset)) {
                    switch (exVar.stack.pop()) {
                      case (#err(e)) { return #err(e) };
                      case (#ok(argsSize)) {
                        switch (exVar.stack.pop()) {
                          case (#err(e)) { return #err(e) };
                          case (#ok(retOffset)) {
                            switch (exVar.stack.pop()) {
                              case (#err(e)) { return #err(e) };
                              case (#ok(retSize)) {
                                // get calldata from memory
                                let memory_byte_size = Vec.size(exVar.memory);
                                let memory_size_word = (memory_byte_size + 31) / 32;
                                let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                                var new_memory_cost = memory_cost;
                                if (argsOffset + argsSize > memory_byte_size) {
                                  let new_memory_size_word = (argsOffset + argsSize + 31) / 32;
                                  let new_memory_byte_size = new_memory_size_word * 32;
                                  Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
                                  new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                                };
                                var calldata = "" : Blob;
                                if (argsSize > 0) {
                                  let calldataBuffer = Buffer.Buffer<Nat8>(argsSize);
                                  for (pos in Iter.range(0, argsSize - 1)) {
                                    calldataBuffer.add(Vec.get(exVar.memory, argsOffset + pos));
                                  };
                                  calldata := Blob.fromArray(Buffer.toArray<Nat8>(calldataBuffer));
                                };
                                // get code from code store
                                let addressBuffer = Buffer.Buffer<Nat8>(20);
                                for (i in Iter.revRange(19, 0)) {
                                  addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                                };
                                let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
                                let emptyCode = Array.init<Nat8>(0, 0);
                                var newCode = emptyCode;
                                var emptyAccountCost = 0;
                                var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                                let startingAccountData = Trie.get(exCon.accounts, key address, Blob.equal);
                                switch (startingAccountData) {
                                  case (null) { // new account is being called
                                    if (value > 0 and addressNat > 9) {
                                      emptyAccountCost := 25000;
                                    };
                                  };
                                  case (?data) {
                                    let decodedStartingData = decodeAccount(data);
                                    let startingCode = decodedStartingData.3;
                                    codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Blob.toArray(startingCode)));
                                  };
                                };
                                for (change in Map.entries(exVar.codeAdditions)) {
                                  if (change.0 == codeChangeKey) {
                                    switch (change.1.newValue) {
                                      case (null) {
                                        codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                                      };
                                      case (?someCode) {
                                        newCode := Array.thaw<Nat8>(someCode);
                                        codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(newCode)));
                                      };
                                    };
                                  };
                                };
                                let code = Array.freeze<Nat8>(newCode);
                                // check gas; gas is capped at all but one 64th (remaining_gas / 64) of
                                // the remaining gas of the current context; if more then change it
                                var gas = gas_;
                                if (gas > exVar.totalGas * 63 / 64) {
                                  gas := exVar.totalGas * 63 / 64;
                                };
                                var stipend = 0;
                                if (value > 0) { stipend := 2300; };
                                gas += stipend;
                                // check caller balance
                                let callerAddress = exCon.caller;
                                let callerAccountData = Trie.get(exCon.accounts, key callerAddress, Blob.equal);
                                var callerBalance = 0;
                                switch (callerAccountData) {
                                  case (null) {};
                                  case (?data) {
                                    let decodedData = decodeAccount(data);
                                    callerBalance := decodedData.1;
                                  };
                                };
                                for (change in Vec.vals(exVar.balanceChanges)) {
                                  if (change.from == exCon.caller) {callerBalance -= change.amount;};
                                  if (change.to == exCon.caller) {callerBalance += change.amount;};
                                };
                                // if value <= caller balance then run subcontext
                                // otherwise the call fails but the current context is not reverted
                                var result = 0; // 1 if successful
                                var memory_expansion_cost = 0;
                                var code_execution_cost = 0;
                                if (value <= callerBalance) {
                                  let subcontext = executeSubcontext(
                                    code,
                                    gas,
                                    value,
                                    exCon.callee, // uses own address
                                    addressNat,
                                    calldata,
                                    exCon,
                                    exVar,
                                    engineInstance
                                  );
                                  if (subcontext.programCounter <= code.size() + 1) {
                                    result := 1;
                                  };
                                  // store return data in memory
                                  var returnData = "" : Blob;
                                  switch (subcontext.returnData) {
                                    case (null) {};
                                    case (?returnData_) {
                                      returnData := returnData_;
                                      var returnDataArray = Blob.toArray(returnData);
                                      if (returnDataArray.size() > retSize) {
                                        let resizedArray = Array.subArray<Nat8>(returnDataArray, 0, retSize);
                                        returnData := Blob.fromArray(resizedArray);
                                      };
                                      let memory_byte_size = Vec.size(exVar.memory);
                                      let memory_size_word = (memory_byte_size + 31) / 32;
                                      let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                                      var new_memory_cost = memory_cost;
                                      if (retOffset + retSize > memory_byte_size) {
                                        let new_memory_size_word = (retOffset + retSize + 31) / 32;
                                        let new_memory_byte_size = new_memory_size_word * 32;
                                        let mem_incr = new_memory_byte_size - memory_byte_size;
                                        Vec.addMany(exVar.memory, mem_incr, Nat8.fromNat(0));
                                        new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                                      };
                                      var pos = retOffset;
                                      for (byte in returnData.vals()) {
                                        Vec.put(exVar.memory, pos, byte);
                                        pos += 1;
                                      };
                                      memory_expansion_cost := new_memory_cost - memory_cost;
                                    };
                                  };
                                  code_execution_cost := gas - subcontext.totalGas - subcontext.gasRefund;
                                  // persist state changes from subcontext
                                  exVar.balanceChanges := subcontext.balanceChanges;
                                  exVar.storageChanges := subcontext.storageChanges;
                                  exVar.codeAdditions := subcontext.codeAdditions;
                                  exVar.codeStore := subcontext.codeStore;
                                  exVar.storageStore := subcontext.storageStore;
                                  exVar.lastReturnData := subcontext.returnData;
                                };
                                // success?
                                switch (exVar.stack.push(result)) {
                                  case (#err(e)) { return #err(e) };
                                  case (#ok(_)) {
                                    // code_execution_cost is the cost of the called code execution (limited by the gas parameter).
                                    // If address is warm, then address_access_cost is 100, otherwise it is 2600. (Not used in this version.)
                                    // If value is not 0, then positive_value_cost is 9000. In this case there is also a call stipend that is given to make sure that a basic fallback function can be called. 2300 is thus removed from the cost, and also added to the gas input.
                                    // If value is not 0 and the address given points to an empty account, then value_to_empty_account_cost is 25000. An account is empty if its balance is 0, its nonce is 0 and it has no code.
                                    var newGas: Int = exVar.totalGas - 100 - memory_expansion_cost - stipend - emptyAccountCost - code_execution_cost;
                                    if (value > 0) { newGas -= 9000; };
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
                };
              };
            };
          };
        };
      };
    };
  };

  let op_F3_RETURN = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_F4_DELEGATECALL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(gas_)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(addressNat)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(argsOffset)) {
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(argsSize)) {
                    switch (exVar.stack.pop()) {
                      case (#err(e)) { return #err(e) };
                      case (#ok(retOffset)) {
                        switch (exVar.stack.pop()) {
                          case (#err(e)) { return #err(e) };
                          case (#ok(retSize)) {
                            // persist current context value
                            let value = exCon.incomingEth;
                            // get calldata from memory
                            let memory_byte_size = Vec.size(exVar.memory);
                            let memory_size_word = (memory_byte_size + 31) / 32;
                            let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                            var new_memory_cost = memory_cost;
                            if (argsOffset + argsSize > memory_byte_size) {
                              let new_memory_size_word = (argsOffset + argsSize + 31) / 32;
                              let new_memory_byte_size = new_memory_size_word * 32;
                              Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
                              new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                            };
                            var calldata = "" : Blob;
                            if (argsSize > 0) {
                              let calldataBuffer = Buffer.Buffer<Nat8>(argsSize);
                              for (pos in Iter.range(0, argsSize - 1)) {
                                calldataBuffer.add(Vec.get(exVar.memory, argsOffset + pos));
                              };
                              calldata := Blob.fromArray(Buffer.toArray<Nat8>(calldataBuffer));
                            };
                            // get code from code store
                            let addressBuffer = Buffer.Buffer<Nat8>(20);
                            for (i in Iter.revRange(19, 0)) {
                              addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                            };
                            let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
                            let emptyCode = Array.init<Nat8>(0, 0);
                            var newCode = emptyCode;
                            var emptyAccountCost = 0;
                            var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                            let startingAccountData = Trie.get(exCon.accounts, key address, Blob.equal);
                            switch (startingAccountData) {
                              case (null) { // new account is being called
                                if (value > 0 and addressNat > 9) {
                                  emptyAccountCost := 25000;
                                };
                              };
                              case (?data) {
                                let decodedStartingData = decodeAccount(data);
                                let startingCode = decodedStartingData.3;
                                codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Blob.toArray(startingCode)));
                              };
                            };
                            for (change in Map.entries(exVar.codeAdditions)) {
                              if (change.0 == codeChangeKey) {
                                switch (change.1.newValue) {
                                  case (null) {
                                    codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                                  };
                                  case (?someCode) {
                                    newCode := Array.thaw<Nat8>(someCode);
                                    codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(newCode)));
                                  };
                                };
                              };
                            };
                            let code = Array.freeze<Nat8>(newCode);
                            // check gas; gas is capped at all but one 64th (remaining_gas / 64) of
                            // the remaining gas of the current context; if more then change it
                            var gas = gas_;
                            if (gas > exVar.totalGas * 63 / 64) {
                              gas := exVar.totalGas * 63 / 64;
                            };
                            var stipend = 0;
                            if (value > 0) { stipend := 2300; };
                            gas += stipend;
                            // check caller balance
                            let callerAddress = exCon.caller;
                            let callerAccountData = Trie.get(exCon.accounts, key callerAddress, Blob.equal);
                            var callerBalance = 0;
                            switch (callerAccountData) {
                              case (null) {};
                              case (?data) {
                                let decodedData = decodeAccount(data);
                                callerBalance := decodedData.1;
                              };
                            };
                            for (change in Vec.vals(exVar.balanceChanges)) {
                              if (change.from == exCon.caller) {callerBalance -= change.amount;};
                              if (change.to == exCon.caller) {callerBalance += change.amount;};
                            };
                            // if value <= caller balance then run subcontext
                            // otherwise the call fails but the current context is not reverted
                            var result = 0; // 1 if successful
                            var memory_expansion_cost = 0;
                            var code_execution_cost = 0;
                            if (value <= callerBalance) {
                              let subcontext = executeSubcontext(
                                code,
                                gas,
                                value,
                                exCon.callee, // uses own address
                                addressNat,
                                calldata,
                                exCon,
                                exVar,
                                engineInstance
                              );
                              if (subcontext.programCounter <= code.size() + 1) {
                                result := 1;
                              };
                              // store return data in memory
                              var returnData = "" : Blob;
                              switch (subcontext.returnData) {
                                case (null) {};
                                case (?returnData_) {
                                  returnData := returnData_;
                                  var returnDataArray = Blob.toArray(returnData);
                                  if (returnDataArray.size() > retSize) {
                                    let resizedArray = Array.subArray<Nat8>(returnDataArray, 0, retSize);
                                    returnData := Blob.fromArray(resizedArray);
                                  };
                                  let memory_byte_size = Vec.size(exVar.memory);
                                  let memory_size_word = (memory_byte_size + 31) / 32;
                                  let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                                  var new_memory_cost = memory_cost;
                                  if (retOffset + retSize > memory_byte_size) {
                                    let new_memory_size_word = (retOffset + retSize + 31) / 32;
                                    let new_memory_byte_size = new_memory_size_word * 32;
                                    let mem_incr = new_memory_byte_size - memory_byte_size;
                                    Vec.addMany(exVar.memory, mem_incr, Nat8.fromNat(0));
                                    new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                                  };
                                  var pos = retOffset;
                                  for (byte in returnData.vals()) {
                                    Vec.put(exVar.memory, pos, byte);
                                    pos += 1;
                                  };
                                  memory_expansion_cost := new_memory_cost - memory_cost;
                                };
                              };
                              code_execution_cost := gas - subcontext.totalGas - subcontext.gasRefund;
                              // persist state changes from subcontext
                              exVar.balanceChanges := subcontext.balanceChanges;
                              exVar.storageChanges := subcontext.storageChanges;
                              exVar.codeAdditions := subcontext.codeAdditions;
                              exVar.codeStore := subcontext.codeStore;
                              exVar.storageStore := subcontext.storageStore;
                              exVar.lastReturnData := subcontext.returnData;
                            };
                            // success?
                            switch (exVar.stack.push(result)) {
                              case (#err(e)) { return #err(e) };
                              case (#ok(_)) {
                                // code_execution_cost is the cost of the called code execution (limited by the gas parameter).
                                // If address is warm, then address_access_cost is 100, otherwise it is 2600. (Not used in this version.)
                                // If value is not 0, then positive_value_cost is 9000. In this case there is also a call stipend that is given to make sure that a basic fallback function can be called. 2300 is thus removed from the cost, and also added to the gas input.
                                // If value is not 0 and the address given points to an empty account, then value_to_empty_account_cost is 25000. An account is empty if its balance is 0, its nonce is 0 and it has no code.
                                var newGas: Int = exVar.totalGas - 100 - memory_expansion_cost - stipend - emptyAccountCost - code_execution_cost;
                                if (value > 0) { newGas -= 9000; };
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
            };
          };
        };
      };
    };
  };

  let op_F5_CREATE2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(value)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(offset)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(size)) {
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(salt)) {
                    if (exVar.staticCall > 0) {
                      return #err("Disallowed opcode CREATE2 called within STATICCALL")
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
                    //   address = keccak256(0xff + sender_address + salt + keccak256(initialisation_code))[12:]
                    let saltBuffer = Buffer.Buffer<Nat8>(32);
                    for (i in Iter.revRange(31, 0)) {
                      saltBuffer.add(Nat8.fromNat((salt % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                    };
                    let saltArray = Buffer.toArray<Nat8>(saltBuffer);
                    let array1 = Array.append<Nat8>([0xff] : [Nat8], Blob.toArray(exCon.caller));
                    let array2 = Array.append<Nat8>(array1, saltArray);
                    let array3 = Array.append<Nat8>(array2, Blob.toArray(getCodeHash(initCode)));
                    let array4 = Blob.toArray(getCodeHash(array3));
                    let addressArray = Array.subArray<Nat8>(array4, 12, 20);
                    let address = Blob.fromArray(addressArray);
                    // check if account already exists at address
                    var addressIsNew = true;
                    let newAccountData = Trie.get(exCon.accounts, key address, Blob.equal);
                    switch (newAccountData) {
                      case (null) {
                        for (change in Vec.vals(exVar.balanceChanges)) {
                          if (change.to == address) { addressIsNew := false; };
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
                    // push to stack: the address of the deployed contract, 0 if the deployment failed
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
    };
  };

  let op_FA_STATICCALL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(gas_)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(addressNat)) {
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(argsOffset)) {
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(argsSize)) {
                    switch (exVar.stack.pop()) {
                      case (#err(e)) { return #err(e) };
                      case (#ok(retOffset)) {
                        switch (exVar.stack.pop()) {
                          case (#err(e)) { return #err(e) };
                          case (#ok(retSize)) {
                            // set value to 0
                            let value = 0;
                            // get calldata from memory
                            let memory_byte_size = Vec.size(exVar.memory);
                            let memory_size_word = (memory_byte_size + 31) / 32;
                            let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                            var new_memory_cost = memory_cost;
                            if (argsOffset + argsSize > memory_byte_size) {
                              let new_memory_size_word = (argsOffset + argsSize + 31) / 32;
                              let new_memory_byte_size = new_memory_size_word * 32;
                              Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
                              new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                            };
                            var calldata = "" : Blob;
                            if (argsSize > 0) {
                              let calldataBuffer = Buffer.Buffer<Nat8>(argsSize);
                              for (pos in Iter.range(0, argsSize - 1)) {
                                calldataBuffer.add(Vec.get(exVar.memory, argsOffset + pos));
                              };
                              calldata := Blob.fromArray(Buffer.toArray<Nat8>(calldataBuffer));
                            };
                            // get code from code store
                            let addressBuffer = Buffer.Buffer<Nat8>(20);
                            for (i in Iter.revRange(19, 0)) {
                              addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                            };
                            let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
                            let emptyCode = Array.init<Nat8>(0, 0);
                            var newCode = emptyCode;
                            var emptyAccountCost = 0;
                            var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                            let startingAccountData = Trie.get(exCon.accounts, key address, Blob.equal);
                            switch (startingAccountData) {
                              case (null) { // new account is being called
                                if (value > 0 and addressNat > 9) {
                                  emptyAccountCost := 25000;
                                };
                              };
                              case (?data) {
                                let decodedStartingData = decodeAccount(data);
                                let startingCode = decodedStartingData.3;
                                codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Blob.toArray(startingCode)));
                              };
                            };
                            for (change in Map.entries(exVar.codeAdditions)) {
                              if (change.0 == codeChangeKey) {
                                switch (change.1.newValue) {
                                  case (null) {
                                    codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(emptyCode)));
                                  };
                                  case (?someCode) {
                                    newCode := Array.thaw<Nat8>(someCode);
                                    codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(address), Array.freeze<Nat8>(newCode)));
                                  };
                                };
                              };
                            };
                            let code = Array.freeze<Nat8>(newCode);
                            // check gas; gas is capped at all but one 64th (remaining_gas / 64) of
                            // the remaining gas of the current context; if more then change it
                            var gas = gas_;
                            if (gas > exVar.totalGas * 63 / 64) {
                              gas := exVar.totalGas * 63 / 64;
                            };
                            var stipend = 0;
                            if (value > 0) { stipend := 2300; };
                            gas += stipend;
                            // run subcontext
                            exVar.staticCall += 1; // used for detecting disallowed opcodes
                            var result = 0; // 1 if successful
                            var memory_expansion_cost = 0;
                            var code_execution_cost = 0;
                            let subcontext = executeSubcontext(
                              code,
                              gas,
                              value,
                              address,
                              addressNat,
                              calldata,
                              exCon,
                              exVar,
                              engineInstance
                            );
                            if (subcontext.programCounter <= code.size() + 1) {
                              result := 1;
                            };
                            // store return data in memory
                            var returnData = "" : Blob;
                            switch (subcontext.returnData) {
                              case (null) {};
                              case (?returnData_) {
                                returnData := returnData_;
                                var returnDataArray = Blob.toArray(returnData);
                                if (returnDataArray.size() > retSize) {
                                  let resizedArray = Array.subArray<Nat8>(returnDataArray, 0, retSize);
                                  returnData := Blob.fromArray(resizedArray);
                                };
                                let memory_byte_size = Vec.size(exVar.memory);
                                let memory_size_word = (memory_byte_size + 31) / 32;
                                let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
                                var new_memory_cost = memory_cost;
                                if (retOffset + retSize > memory_byte_size) {
                                  let new_memory_size_word = (retOffset + retSize + 31) / 32;
                                  let new_memory_byte_size = new_memory_size_word * 32;
                                  let mem_incr = new_memory_byte_size - memory_byte_size;
                                  Vec.addMany(exVar.memory, mem_incr, Nat8.fromNat(0));
                                  new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
                                };
                                var pos = retOffset;
                                for (byte in returnData.vals()) {
                                  Vec.put(exVar.memory, pos, byte);
                                  pos += 1;
                                };
                                memory_expansion_cost := new_memory_cost - memory_cost;
                              };
                            };
                            exVar.lastReturnData := subcontext.returnData;
                            code_execution_cost := gas - subcontext.totalGas - subcontext.gasRefund;
                            exVar.staticCall -= 1;
                            // success?
                            switch (exVar.stack.push(result)) {
                              case (#err(e)) { return #err(e) };
                              case (#ok(_)) {
                                // code_execution_cost is the cost of the called code execution (limited by the gas parameter).
                                // If address is warm, then address_access_cost is 100, otherwise it is 2600. (Not used in this version.)
                                // If value is not 0, then positive_value_cost is 9000. In this case there is also a call stipend that is given to make sure that a basic fallback function can be called. 2300 is thus removed from the cost, and also added to the gas input.
                                // If value is not 0 and the address given points to an empty account, then value_to_empty_account_cost is 25000. An account is empty if its balance is 0, its nonce is 0 and it has no code.
                                var newGas: Int = exVar.totalGas - 100 - memory_expansion_cost - stipend - emptyAccountCost - code_execution_cost;
                                if (value > 0) { newGas -= 9000; };
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
            };
          };
        };
      };
    };
  };

  // Not in use
  let op_FB_TXHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };

  // Not in use
  let op_FC_CHAINID = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_FD_REVERT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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

  let op_FE_INVALID = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    return #err("Designated INVALID opcode called");
  };

  // This function sends the callee's full balance and removes code. When the accounts trie is
  //  updated at the end of the state transition, if it fits criteria showing that it was added anew in
  //  the current transaction (i.e. not already in the accounts trie), has zero balance and has a code change
  //  to empty code then it will not be included in the updated accounts trie. This will enable compliance
  //  with the current stipulation that the account is removed only if SELFDESTRUCT is executed in the
  //  same transaction in which a contract was created.
  // TODO - Gas refund might still need to be accounted for.
  let op_FF_SELFDESTRUCT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(addressNat)) {
        if (exVar.staticCall > 0) {
          return #err("Disallowed opcode SELFDESTRUCT called within STATICCALL")
        };
        let addressBuffer = Buffer.Buffer<Nat8>(20);
        for (i in Iter.revRange(19, 0)) {
          addressBuffer.add(Nat8.fromNat((addressNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
        // get callee balance
        let calleeAddress = exCon.callee;
        let calleeAccountData = Trie.get(exCon.accounts, key calleeAddress, Blob.equal);
        var calleeBalance = 0;
        switch (calleeAccountData) {
          case (null) {};
          case (?data) {
            let decodedData = decodeAccount(data);
            calleeBalance := decodedData.1;
          };
        };
        for (change in Vec.vals(exVar.balanceChanges)) {
          if (change.from == exCon.callee) {calleeBalance -= change.amount;};
          if (change.to == exCon.callee) {calleeBalance += change.amount;};
        };
        // get recipient balance, nonce and codeHash
        let accountData = Trie.get(exCon.accounts, key address, Blob.equal);
        var balance = 0;
        var nonce = 0;
        let emptyCode = [] : [T.OpCode];
        var codeHash = getCodeHash(emptyCode);
        switch (accountData) {
          case (null) {};
          case (?data) {
            let decodedData = decodeAccount(data);
            balance := decodedData.1;
            nonce := decodedData.0;
            codeHash := decodedData.3;
          };
        };
        for (change in Vec.vals(exVar.balanceChanges)) {
          if (change.from == address) {balance -= change.amount};
          if (change.to == address) {balance += change.amount};
        };
        var accountIsEmpty = false;
        if (balance == 0 and nonce == 0 and Blob.equal(codeHash, getCodeHash(emptyCode))) {
          accountIsEmpty := true;
        };
        // send full balance
        Vec.add(exVar.balanceChanges, {
          from = calleeAddress;
          to = address;
          amount = calleeBalance;
        });
        // get callee code
        let calleeData = Trie.get(exCon.accounts, key calleeAddress, Blob.equal);
        var calleeCode = Array.init<Nat8>(0, 0);
        var calleeCodeHash = "" : Blob;
        switch (calleeData) {
          case (null) {};
          case (?data) {
            let decodedData = decodeAccount(data);
            calleeCodeHash := decodedData.3;
            let code = Map.get(exVar.codeStore, bhash, calleeCodeHash);
            switch (code) {
              case (null) {};
              case (?code_) {
                calleeCode := Array.thaw<Nat8>(code_);
              };
            };
          };
        };
        // check for any code changes during the current execution
        var codeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(calleeAddress), Array.freeze<Nat8>(calleeCode)));
        for (change in Map.entries(exVar.codeAdditions)) {
          if (change.0 == codeChangeKey) {
            switch (change.1.newValue) {
              case (null) {
                calleeCode := Array.init<Nat8>(0, 0);
              };
              case (?newCode) {
                calleeCode := Array.thaw<Nat8>(newCode);
                codeChangeKey := getCodeHash(Array.append<Nat8>(Blob.toArray(calleeAddress), newCode));
              };
            };
          };
        };
        // remove callee code
        let newCodeChangeKey = getCodeHash(Array.append<Nat8>(Blob.toArray(calleeAddress), Array.freeze<Nat8>(calleeCode)));
        let newCodeChange: T.CodeChange = {
          key = newCodeChangeKey;
          originalValue = Array.freeze<Nat8>(calleeCode);
          newValue = null;//Option.make([] : [T.OpCode]);
        };
        Map.set(exVar.codeAdditions, bhash, newCodeChangeKey, newCodeChange);
        Map.set(exVar.codeStore, bhash, getCodeHash([] : [T.OpCode]), [] : [T.OpCode]);
        // calculate gas
        var dynamicGas = 0;
        if (accountIsEmpty) {
          dynamicGas := 25000;
        };
        let newGas: Int = exVar.totalGas - 5000 - dynamicGas; // warm/cold address distinction not in this version
        if (newGas < 0) {
          return #err("Out of gas")
          } else {
          exVar.totalGas := Int.abs(newGas);
          return #ok(exVar);
        };
      };
    };
  };


  // Other

  let op_20_KECCAK256 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
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



  // Unused
  let op_0C_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_0D_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_0E_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_0F_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_1E_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_1F_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_21_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_22_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_23_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_24_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_25_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_26_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_27_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_28_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_29_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2A_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2B_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2C_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2D_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2E_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2F_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4B_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4C_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4D_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4E_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4F_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AD_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B0_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B1_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B2_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B3_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B4_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BD_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C0_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C1_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C2_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C3_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C4_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CD_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D0_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D1_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D2_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D3_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D4_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DD_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E0_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E1_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E2_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E3_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E4_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_ED_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_F6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_F7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_F8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_F9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> { #err("") };


  public func engine(): T.Engine {[
    op_00_STOP, op_01_ADD, op_02_MUL, op_03_SUB, op_04_DIV,op_05_SDIV,
    op_06_MOD, op_07_SMOD, op_08_ADDMOD, op_09_MULMOD, op_0A_EXP,
    op_0B_SIGNEXTEND, op_0C_, op_0D_, op_0E_, op_0F_, op_10_LT, op_11_GT,
    op_12_SLT, op_13_SGT, op_14_EQ, op_15_ISZERO, op_16_AND, op_17_OR,
    op_18_XOR, op_19_NOT, op_1A_BYTE, op_1B_SHL, op_1C_SHR, op_1D_SAR,
    op_1E_, op_1F_, op_20_KECCAK256, op_21_, op_22_, op_23_, op_24_, op_25_,
    op_26_, op_27_, op_28_, op_29_, op_2A_, op_2B_, op_2C_, op_2D_, op_2E_,
    op_2F_, op_30_ADDRESS, op_31_BALANCE, op_32_ORIGIN, op_33_CALLER,
    op_34_CALLVALUE, op_35_CALLDATALOAD, op_36_CALLDATASIZE, op_37_CALLDATACOPY,
    op_38_CODESIZE, op_39_CODECOPY, op_3A_GASPRICE, op_3B_EXTCODESIZE,
    op_3C_EXTCODECOPY, op_3D_RETURNDATASIZE, op_3E_RETURNDATACOPY,
    op_3F_EXTCODEHASH, op_40_BLOCKHASH, op_41_COINBASE, op_42_TIMESTAMP,
    op_43_NUMBER, op_44_DIFFICULTY, op_45_GASLIMIT, op_46_CHAINID,
    op_47_SELFBALANCE, op_48_BASEFEE, op_49_BLOBHASH, op_4A_BLOBBASEFEE, op_4B_,
    op_4C_, op_4D_, op_4E_, op_4F_, op_50_POP, op_51_MLOAD, op_52_MSTORE,
    op_53_MSTORE8, op_54_SLOAD, op_55_SSTORE, op_56_JUMP, op_57_JUMPI, op_58_PC,
    op_59_MSIZE, op_5A_GAS, op_5B_JUMPDEST, op_5C_TLOAD, op_5D_TSTORE,
    op_5E_MCOPY, op_5F_PUSH0, op_60_PUSH1, op_61_PUSH2, op_62_PUSH3,
    op_63_PUSH4, op_64_PUSH5, op_65_PUSH6, op_66_PUSH7, op_67_PUSH8,
    op_68_PUSH9, op_69_PUSH10, op_6A_PUSH11, op_6B_PUSH12, op_6C_PUSH13,
    op_6D_PUSH14, op_6E_PUSH15, op_6F_PUSH16, op_70_PUSH17, op_71_PUSH18,
    op_72_PUSH19, op_73_PUSH20, op_74_PUSH21, op_75_PUSH22, op_76_PUSH23,
    op_77_PUSH24, op_78_PUSH25, op_79_PUSH26, op_7A_PUSH27, op_7B_PUSH28,
    op_7C_PUSH29, op_7D_PUSH30, op_7E_PUSH31, op_7F_PUSH32, op_80_DUP1,
    op_81_DUP2, op_82_DUP3, op_83_DUP4, op_84_DUP5, op_85_DUP6, op_86_DUP7,
    op_87_DUP8, op_88_DUP9, op_89_DUP10, op_8A_DUP11, op_8B_DUP12, op_8C_DUP13,
    op_8D_DUP14, op_8E_DUP15, op_8F_DUP16, op_90_SWAP1, op_91_SWAP2,
    op_92_SWAP3, op_93_SWAP4, op_94_SWAP5, op_95_SWAP6, op_96_SWAP7,
    op_97_SWAP8, op_98_SWAP9, op_99_SWAP10, op_9A_SWAP11, op_9B_SWAP12,
    op_9C_SWAP13, op_9D_SWAP14, op_9E_SWAP15, op_9F_SWAP16, op_A0_LOG0,
    op_A1_LOG1, op_A2_LOG2, op_A3_LOG3, op_A4_LOG4, op_A5_, op_A6_, op_A7_,
    op_A8_, op_A9_, op_AA_, op_AB_, op_AC_, op_AD_, op_AE_, op_AF_, op_B0_,
    op_B1_, op_B2_, op_B3_, op_B4_, op_B5_, op_B6_, op_B7_, op_B8_, op_B9_,
    op_BA_, op_BB_, op_BC_, op_BD_, op_BE_, op_BF_, op_C0_, op_C1_, op_C2_,
    op_C3_, op_C4_, op_C5_, op_C6_, op_C7_, op_C8_, op_C9_, op_CA_, op_CB_,
    op_CC_, op_CD_, op_CE_, op_CF_, op_D0_, op_D1_, op_D2_, op_D3_, op_D4_,
    op_D5_, op_D6_, op_D7_, op_D8_, op_D9_, op_DA_, op_DB_, op_DC_, op_DD_,
    op_DE_, op_DF_, op_E0_, op_E1_, op_E2_, op_E3_, op_E4_, op_E5_, op_E6_,
    op_E7_, op_E8_, op_E9_, op_EA_, op_EB_, op_EC_, op_ED_, op_EE_, op_EF_,
    op_F0_CREATE, op_F1_CALL, op_F2_CALLCODE, op_F3_RETURN, op_F4_DELEGATECALL,
    op_F5_CREATE2, op_F6_, op_F7_, op_F8_, op_F9_, op_FA_STATICCALL, op_FB_TXHASH,
    op_FC_CHAINID, op_FD_REVERT, op_FE_INVALID, op_FF_SELFDESTRUCT
  ];
  };
};
