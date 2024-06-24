import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Trie "mo:base/Trie";
import Debug "mo:base/Debug";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map
import EVMStack "evmStack";
import T "types";

actor {
  
  type Result<Ok, Err> = { #ok: Ok; #err: Err};
  type Engine = [(T.ExecutionContext, T.ExecutionVariables) -> Result<T.ExecutionVariables, Text>];
  type Vec<X> = Vec.Vector<X>;
  type Map<K, V> = Map.Map<K, V>;
  type Trie<K, V> = Trie.Trie<K, V>;

  public func stateTransition(
    tx: T.Transaction,
    callerState: T.CallerState,
    calleeState: T.CalleeState,
    gasPrice: Nat,
    blockHashes: [(Nat, Blob)], // changed from Vec<(Nat, Blob)> to Array
    accounts: Trie<Blob, Blob>,
    blockInfo: T.BlockInfo
  ) : async T.ExecutionContext {
    // check Transaction has right number of values => will trap if not
    // check signature is valid => not applicable for this version
    // check that nonce matches nonce in sender's account => TODO
    // Calculate the transaction fee as STARTGAS(=gasLimitTx) * GASPRICE,
    let fee: Nat = tx.gasLimitTx * tx.gasPriceTx;
    // and determine the sending address from the signature.
    // Subtract the fee from the sender's account balance and increment the sender's nonce. If there is not enough balance to spend, return an error.
    var balanceChanges = Vec.new<T.BalanceChange>();
    assert (fee + tx.incomingEth <= callerState.balance);
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = blockInfo.blockCoinbase;
      amount = fee;
    });
    // Initialize GAS = STARTGAS, and take off a certain quantity of gas per byte to pay for the bytes in the transaction
    let remainingGas = fee; // gas per byte not included in this version
    // Transfer the transaction value from the sender's account to the receiving account.
    // Check that ((T.CallerState.balance - fee) > tx.incomingEth) => included above for this version
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = tx.callee;
      amount = tx.incomingEth;
    });
    // If the receiving account does not yet exist, create it. => TODO

    let exCon: T.ExecutionContext = {
      origin = tx.caller;
      code = calleeState.code;
      programCounter = 0; 
      stack = [];
      memory = [];
      contractStorage = calleeState.storage; 
      caller = tx.caller;
      callee = tx.callee;
      currentGas = fee;
      gasPrice = gasPrice;
      incomingEth = tx.incomingEth; 
      balanceChanges = Vec.toArray<T.BalanceChange>(balanceChanges); 
      storageChanges = [];
      codeAdditions = []; 
      blockHashes = blockHashes; 
      codeStore = []; 
      storageStore = [];
      accounts = accounts; 
      logs = []; 
      totalGas = remainingGas;
      gasRefund = 0;
      returnValue = null; 
      blockInfo = {
        number = blockInfo.blockNumber; 
        gasLimit = blockInfo.blockGasLimit; 
        difficulty = blockInfo.blockDifficulty; 
        timestamp = blockInfo.blockTimestamp; 
        coinbase = blockInfo.blockCoinbase;
        chainId = blockInfo.chainId;
      };
      calldata = tx.dataTx; 
    };

    let exVar: T.ExecutionVariables = {
      var programCounter = 0; 
      var stack = EVMStack.EVMStack();
      var memory = Vec.new<Nat8>();
      var contractStorage = calleeState.storage; 
      var balanceChanges = balanceChanges; 
      var storageChanges = Map.new<Blob, T.StorageSlotChange>();
      var codeAdditions = Map.new<Blob, T.CodeChange>(); 
      var codeStore = Map.new<Blob, [T.OpCode]>(); 
      var storageStore = Map.new<Blob, Blob>();
      var logs = Vec.new<T.LogEntry>();
      var totalGas = remainingGas;
    };

    // If the receiving account is a contract, run the contract's code either to completion or until the execution runs out of gas.
    if (calleeState.code != []) {
      executeCode(exCon, exVar);
    } else {
      exCon;
    };
    // If the value transfer failed because the sender did not have enough money (TODO), or the code execution ran out of gas, revert all state changes except the payment of the fees, and add the fees to the miner's account.
    // Otherwise, refund the fees for all remaining gas to the sender, and send the fees paid for gas consumed to the miner.
  };

  func executeCode(exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : T.ExecutionContext {
    let codeSize = Array.size(exCon.code);
    while (exVar.programCounter < codeSize) {
      // get current instruction from code[programCounter]
      let instruction = exCon.code[exVar.programCounter].0;
      // execute instruction via OPCODE functions
      switch (engine[Nat8.toNat(instruction)](exCon, exVar)) {
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

    let newExCon: T.ExecutionContext = {
      origin = exCon.origin;
      code = exCon.code;
      programCounter = exVar.programCounter; 
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
      storageStore = Map.toArray<Blob, Blob>(exVar.storageStore);
      accounts = exCon.accounts; 
      logs = Vec.toArray<T.LogEntry>(exVar.logs); 
      totalGas = exVar.totalGas;
      gasRefund = exCon.gasRefund;
      returnValue = null; 
      blockInfo = exCon.blockInfo;
      calldata = exCon.calldata; 
    };
    newExCon;
  };

  func revert(exCon: T.ExecutionContext) : T.ExecutionVariables {
    // revert all state changes except payment of fees
    var balanceChanges = Vec.new<T.BalanceChange>();
    Vec.add(balanceChanges, {
      from = exCon.origin;
      to = exCon.blockInfo.coinbase;
      amount = exCon.currentGas;
    });
    let newExVar: T.ExecutionVariables = {
      var programCounter = Array.size(exCon.code);
      var stack = EVMStack.EVMStack();
      var memory = Vec.new<Nat8>();
      var contractStorage = exCon.contractStorage; 
      var balanceChanges = balanceChanges; 
      var storageChanges = Map.new<Blob, T.StorageSlotChange>();
      var codeAdditions = Map.new<Blob, T.CodeChange>(); 
      var codeStore = Map.new<Blob, [T.OpCode]>(); 
      var storageStore = Map.new<Blob, Blob>();
      var logs = Vec.new<T.LogEntry>();
      var totalGas = 0;
    };
    newExVar;
  };

  // OPCODE FUNCTIONS

  // Basic Math and Bitwise Logic

  let op_01_ADD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> {
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
                exVar.totalGas -= 3;
                // return new execution context variables
                return #ok(exVar);
              };
            };
          };
        };
      };
    };
  };

  let op_02_MUL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> {
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
                exVar.totalGas -= 5;
                return #ok(exVar);
              };
            };
          };
        };
      };
    };
  };

  let op_03_SUB = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            let result = (a - b) % 2**256;
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                exVar.totalGas -= 3;
                return #ok(exVar);
              };
            };
          };
        };
      };
    };
  };

  let op_04_DIV = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var result = 0;
            if (b == 0) {
              result := 0;
            } else {
              result := (Nat.div(a, b));
            };
            switch (exVar.stack.push(result)) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                exVar.totalGas -= 5;
                return #ok(exVar);
              };
            };
          };
        };
      };
    };
  };

  let op_05_SDIV = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(a)) {
        var a_mod = a % 2**256;
        if (a_mod >= 2**255) { a_mod -= 2**256 };
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(b)) {
            var b_mod = b % 2**256;
            if (b_mod >= 2**255) { b_mod -= 2**256 };
            var result: Int = 0;
            if (b_mod == 0) {
              result := 0;
            } else {
              result := (Int.div(a_mod, b_mod));
              if (result < 0) { result += 2**256 };
            };
            switch (exVar.stack.push(Int.abs(result))) {
              case (#err(e)) { return #err(e) };
              case (#ok(_)) {
                exVar.totalGas -= 5;
                return #ok(exVar);
              };
            };
          };
        };
      };
    };
  };

  let op_06_MOD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_07_SMOD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_08_ADDMOD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_09_MULMOD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_0A_EXP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_0B_SIGNEXTEND = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_10_LT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_11_GT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_12_SLT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_13_SGT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_14_EQ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_15_ISZERO = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_16_AND = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_17_OR = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_18_XOR = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_19_NOT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_1A_BYTE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_1B_SHL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_1C_SHR = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_1D_SAR = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };


  // Environmental Information and Block Information

  let op_30_ADDRESS = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_31_BALANCE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_32_ORIGIN = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_33_CALLER = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_34_CALLVALUE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_35_CALLDATALOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_36_CALLDATASIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_37_CALLDATACOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_38_CODESIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_39_CODECOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_3A_GASPRICE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_3B_EXTCODESIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_3C_EXTCODECOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_3D_RETURNDATASIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_3E_RETURNDATACOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_3F_EXTCODEHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_40_BLOCKHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_41_COINBASE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_42_TIMESTAMP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_43_NUMBER = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_44_PREVRANDAO = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_45_GASLIMIT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_46_CHAINID = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_47_SELFBALANCE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_48_BASEFEE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };


  // Memory Operations

  let op_50_POP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_51_MLOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_52_MSTORE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_53_MSTORE8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_54_SLOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_55_SSTORE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_56_JUMP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_57_JUMPI = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_58_PC = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_59_MSIZE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_5A_GAS = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_5B_JUMPDEST = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };


  // Push Operations, Duplication Operations, Exchange Operations
  
  let op_5F_PUSH0 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_60_PUSH1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_61_PUSH2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_62_PUSH3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_63_PUSH4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_64_PUSH5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_65_PUSH6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_66_PUSH7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_67_PUSH8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_68_PUSH9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_69_PUSH10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_6A_PUSH11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_6B_PUSH12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_6C_PUSH13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_6D_PUSH14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_6E_PUSH15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_6F_PUSH16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_70_PUSH17 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_71_PUSH18 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_72_PUSH19 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_73_PUSH20 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_74_PUSH21 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_75_PUSH22 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_76_PUSH23 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_77_PUSH24 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_78_PUSH25 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_79_PUSH26 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_7A_PUSH27 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_7B_PUSH28 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_7C_PUSH29 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_7D_PUSH30 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_7E_PUSH31 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_7F_PUSH32 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_80_DUP1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_81_DUP2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_82_DUP3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_83_DUP4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_84_DUP5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_85_DUP6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_86_DUP7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_87_DUP8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_88_DUP9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_89_DUP10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_8A_DUP11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_8B_DUP12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_8C_DUP13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_8D_DUP14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_8E_DUP15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_8F_DUP16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_90_SWAP1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_91_SWAP2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_92_SWAP3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_93_SWAP4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_94_SWAP5 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_95_SWAP6 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_96_SWAP7 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_97_SWAP8 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_98_SWAP9 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_99_SWAP10 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_9A_SWAP11 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_9B_SWAP12 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_9C_SWAP13 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_9D_SWAP14 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_9E_SWAP15 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_9F_SWAP16 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };


  // Logging Operations

  let op_A0_LOG0 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_A1_LOG1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_A2_LOG2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_A3_LOG3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_A4_LOG4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };


  // Execution and System Operations
  
  let op_00_STOP = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_F0_CREATE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_F1_CALL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_F2_CALLCODE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_F3_RETURN = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_F4_DELEGATECALL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_F5_CREATE2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_FA_STATICCALL = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_FB_TXHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_FC_CHAINID = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_FD_REVERT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_FE_INVALID = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_FF_SELFDESTRUCT = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };


  // Other

  let op_20_KECCAK256 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_49_BLOBHASH = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_4A_BLOBBASEFEE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_5C_TLOAD = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_5D_TSTORE = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };

  let op_5E_MCOPY = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };


  // Unused
  let op_0C_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_0D_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_0E_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_0F_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_1E_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_1F_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_21_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_22_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_23_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_24_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_25_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_26_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_27_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_28_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_29_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2A_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2B_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2C_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2D_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2E_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_2F_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4B_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4C_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4D_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4E_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_4F_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_A9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AD_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_AF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B0_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B1_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B2_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B3_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B4_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_B9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BD_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_BF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C0_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C1_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C2_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C3_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C4_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_C9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CD_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_CF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D0_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D1_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D2_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D3_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D4_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_D9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DD_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_DF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E0_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E1_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E2_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E3_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E4_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E5_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_E9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EA_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EB_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EC_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_ED_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EE_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_EF_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_F6_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_F7_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_F8_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };
  let op_F9_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : Result<T.ExecutionVariables, Text> { #err("") };


  let engine: Engine = [
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
    op_43_NUMBER, op_44_PREVRANDAO, op_45_GASLIMIT, op_46_CHAINID,
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
