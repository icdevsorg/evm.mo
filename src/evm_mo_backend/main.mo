// Note this is still a work in progress and code is not yet functional.

import Array "mo:base/Array";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map
// any other imports needed

actor {
  type Address = Blob;
  type Byte = Nat8;
  type Word = Nat; // 256-bit for EVM compliance. Op codes will need to validate that results do not exceed 256-bit numbers and take overflows into consideration
  type OpCode = (Nat8,?Blob); // Considering opcodes range from 0x00 to 0xFF. Plus a set of bytes that can be included

  // A simplified representation of the stack element in EVM. Redundant if EVMStack is used.
  //type StackElement = Nat; // May need to represent 256-bit integers.

  // A simplified structure for representing EVM memory.
  // Uses https://github.com/research-ag/vector
  type Memory = Vec<Byte>;

  // Represents the EVM storage, mapping 32-byte keys to 32-byte values.
  type Storage = Map<[Nat8], [Nat8]>;

  type LogEntry = {
    topics: Vec<Blob>; // Topics are usually the hashed event signature and indexed parameters
    data: Blob; // Non-indexed event parameters
  };

  type Logs = Vec<LogEntry>;

  type StorageSlotChange = {
    key: Blob; // Storage key, typically a 32-byte array.
    originalValue: ?[Nat8]; // Optional, represents the value before the change. `None` can indicate the slot was empty.
    newValue: ?[Nat8]; // Optional, represents the value after the change. `None` can indicate a deletion.
  };

  type CodeChange = {
    key: Blob; // Storage key, typically a 32-byte array.
    originalValue: Array<OpCode>; // Optional, represents the value before the change. `None` can indicate the slot was empty.
    newValue: ?Array<OpCode>; // Optional, represents the value after the change. `None` can indicate a deletion.
  }; // Code may not be changeable...only deletable

  type BalanceChange = {
    from: Blob;
    to: Blob;
    amount: Nat;
  };

  // A structure representing an EVM-specific stack.
  class EVMStack() {
    var stack = Array.init<Nat>(1024,0);
    var _size: Nat = 0;

    public func push(X: Nat) {
      assert(_size < 1024);
      stack[_size] := X;
      _size += 1;
    };

    public func pop() : Nat {
      assert(_size > 0);
      _size -= 1;
      stack[_size];
    };

    public func peek(pos: Nat) : Nat {
      assert(pos < _size); // pos = 0 for top item
      stack[_size - pos - 1];
    };

    public func poke(pos: Nat, X: Nat) {
      assert(pos < _size); // pos = 0 for top item
      stack[_size - pos - 1] := X;
    };
  };

  // The execution context of an EVM call.
  type ExecutionContext = {
    origin: Blob; //originator of the transaction
    code: Array<OpCode>; // Array of opcodes constituting the smart contract code.
    programCounter: Nat; // Points to the current instruction in the code.
    stack: EVMStack; // The stack used for instruction params and return values.
    memory: Memory; // Memory accessible during execution.
    contractStorage: Storage; // Persistent storage for smart contracts.
    caller: Address; // Address of the call initiator.
    callee: Address; // Address of the contract being executed.
    currentGas: Nat; // Amount of gas available for the current execution.
    gasPrice: Nat; // Current gas price.
    incomingEth: Nat; //amount of eth included with the call
    balanceChanges: Vec<BalanceChange>; //keep track of eth balance changes and commit at the end. Each new context will have to adjust balances based off of this array.
    storageChanges: Map<(Blob, StorageSlotChange)>;
    codeAdditions: Map.Map<Blob, CodeChange>; //storage DB for EVM code stored by Hash Key
    blockHashes: Vec<(Nat,Blob)>; //up to last 256 block numbers and hashs
    codeStore: Map.Map<Blob, Array<OpCode>>; //storage DB for EVM code stored by Hash Key
    storageStore: Trie.Map<Blob, Blob>; //storage DB for Contract Storage stored by Hash Key. CALL implementors will need to keep track of storage changes and revert storage if necessary.
    accounts: Trie.Trie<Blob,Blob>; //a merkle patricia tree storing [binary_nonce, binary_balance, storage_root, code_hash] as RLP encoded data - the account bounty hunter will need to create encoders/decoders for use with the trie - https://github.com/relaxed04/rlp-motoko - https://github.com/f0i/merkle-patricia-trie.mo
    logs: Logs; //logs produced during execution
    var totalGas: Nat; // Used for keeping track of gas
    var gasRefund: Nat; // Used for keeping track of gas refunded
    var returnValue: ?Blob; // set for return
    blockInfo: {
      number: Nat; //current block number
      gasLimit: Nat; //current block gas limit
      difficulty: Nat; //current block difficulty
      timestamp: Nat; //current block timestamp
      coinbase: Blob;
      chainId: Nat;
    };
    calldata: Blob; // Input data for the contract execution
  };

  // Your op code functions should take in the execution context as an input variable and update it as is demanded by the op code.

  type Transaction = {
    caller: Address; // The sender of the message, represented in a real transaction as ECDSA signature components v,r,s
    nonce: Nat; // A sequence number, issued by the caller, used to prevent message replay
    gasPriceTx: Nat; // The amount of ether (in wei) that the caller is willing to pay for each unit of gas
    gasLimitTx: Nat; // The maximum amount of gas (units?) the caller is willing to buy for this transaction
    callee: Address; // The recipient of the message
    incomingEth: Nat; // The amount of ether to transfer alongside the message
    dataTx: Blob; // An optional data field
  };

  type CallerState = {
    balance: Nat;
    nonce: Nat;
    code: Array<Opcode>; // empty for externally owned accounts
    storage: Storage; // empty for externally owned accounts
  };

  type CalleeState = {
    balance: Nat;
    nonce: Nat;
    code: Array<Opcode>;
    storage: Storage;
  };

  type BlockInfo = {
    blockNumber: Nat;
    blockGasLimit: Nat;
    blockDifficulty: Nat;
    blockTimestamp: Nat;
    blockCoinbase: Blob;
    chainId: Nat;
  };

  type Engine = [(ExecutionContext) -> ExecutionContext];

  public func stateTransition(
    tx: Transaction,
    callerState: CallerState,
    calleeState: CalleeState,
    gasPrice: Nat,
    blockHashes: Vec<(Nat, Blob)>,
    accounts: Trie.Trie<Blob, Blob>,
    blockInfo: BlockInfo
  ) : async ExecutionContext {
    // check transaction has right number of values => will trap if not
    // check signature is valid => not applicable for this version
    // check that nonce matches nonce in sender's account => TODO
    // Calculate the transaction fee as STARTGAS(=gasLimitTx) * GASPRICE,
    let fee: Nat = tx.gasLimitTx * tx.gasPrice;
    // and determine the sending address from the signature.
    // Subtract the fee from the sender's account balance and increment the sender's nonce. If there is not enough balance to spend, return an error.
    balanceChanges = Vec.new<BalanceChange>();
    assert (fee <= callerState.balance);
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = blockInfo.blockCoinbase;
      amount = fee;
    });
    // Initialize GAS = STARTGAS, and take off a certain quantity of gas per byte to pay for the bytes in the transaction.
    var remainingGas = fee;
    // Transfer the transaction value from the sender's account to the receiving account.
    // Check that (callerState.balance - fee) > tx.incomingEth. From this point on we need something other than `assert` for error handling.
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = tx.callee;
      amount = tx.incomingEth;
    })
    // If the receiving account does not yet exist, create it. => TODO
    // If the receiving account is a contract, run the contract's code either to completion or until the execution runs out of gas. (executeCode inputs would include gasLimitTx, code, calldata, contractStorage, etc.)
    if (calleeState.code != []) {
      let exCon: ExecutionContext = {
        origin = tx.caller;
        code = calleeState.code;
        programCounter = 0; 
        stack = EVMStack();
        memory = Memory.new();
        contractStorage = calleeState.storage; 
        caller = tx.caller;
        callee = tx.callee;
        currentGas = fee;
        gasPrice = gasPrice;
        incomingEth = tx.incomingEth; 
        balanceChanges = balanceChanges; 
        storageChanges = Map.new<(Blob, StorageSlotChange)>();
        codeAdditions = Map.Map.new<Blob, CodeChange>(); 
        blockHashes = blockHashes; 
        codeStore = Map.Map.new<Blob, Array<OpCode>>(); 
        storageStore = Trie.empty();
        accounts = accounts; 
        logs = Vec.new<LogEntry>(); 
        totalGas = currentGas;
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
      executeCode( exCon );
    };
    // If the value transfer failed because the sender did not have enough money, or the code execution ran out of gas, revert all state changes except the payment of the fees, and add the fees to the miner's account.
    // Otherwise, refund the fees for all remaining gas to the sender, and send the fees paid for gas consumed to the miner.
  };

  public func executeCode(exCon: ExecutionContext) : ExecutionContext {
    let codeSize = Array.size(code);
    while (exCon.programCounter < codeSize) {
      // get current instruction from code[programCounter]
      let instruction = code[exCon.programCounter].0;
      // execute instruction via OPCODE functions
      let output = engine[instruction](exCon);
      if (output.totalGas < 0) {
        // terminate execution and run out-of-gas sequence
      } else {
        exCon := output;
        exCon.programCounter += 1;
      }
    };
    exCon;
  };

  // ALL THE OPCODE FUNCTIONS

  // Basic Math and Bitwise Logic

  let op_01_ADD = func (exCon: executionContext) : executionContext {
    // pop two values from the stack; traps if stack is empty
    let a: Int = exCon.stack.pop(); // needs error handling
    let b: Int = exCon.stack.pop(); // needs error handling
    // add them
    let result = a + b;
    // check for result overflow
    result := result % 2**256;
    // check for stack overflow - TODO
    // push result to stack
    exCon.stack.push(result); // needs error handling
    exCon.totalGas -= 3;
    // return new execution context
    exCon;
  };

  let op_02_MUL = func (exCon: executionContext) : executionContext {};

  let op_03_SUB = func (exCon: executionContext) : executionContext {};

  let op_04_DIV = func (exCon: executionContext) : executionContext {};

  let op_05_SDIV = func (exCon: executionContext) : executionContext {};

  let op_06_MOD = func (exCon: executionContext) : executionContext {};

  let op_07_SMOD = func (exCon: executionContext) : executionContext {};

  let op_08_ADDMOD = func (exCon: executionContext) : executionContext {};

  let op_09_MULMOD = func (exCon: executionContext) : executionContext {};

  let op_0A_EXP = func (exCon: executionContext) : executionContext {};

  let op_0B_SIGNEXTEND = func (exCon: executionContext) : executionContext {};

  let op_10_LT = func (exCon: executionContext) : executionContext {};

  let op_11_GT = func (exCon: executionContext) : executionContext {};

  let op_12_SLT = func (exCon: executionContext) : executionContext {};

  let op_13_SGT = func (exCon: executionContext) : executionContext {};

  let op_14_EQ = func (exCon: executionContext) : executionContext {};

  let op_15_ISZERO = func (exCon: executionContext) : executionContext {};

  let op_16_AND = func (exCon: executionContext) : executionContext {};

  let op_17_OR = func (exCon: executionContext) : executionContext {};

  let op_18_XOR = func (exCon: executionContext) : executionContext {};

  let op_19_NOT = func (exCon: executionContext) : executionContext {};

  let op_1A_BYTE = func (exCon: executionContext) : executionContext {};

  let op_1B_SHL = func (exCon: executionContext) : executionContext {};

  let op_1C_SHR = func (exCon: executionContext) : executionContext {};

  let op_1D_SAR = func (exCon: executionContext) : executionContext {};


  // Environmental Information and Block Information

  let op_30_ADDRESS = func (exCon: executionContext) : executionContext {};

  let op_31_BALANCE = func (exCon: executionContext) : executionContext {};

  let op_32_ORIGIN = func (exCon: executionContext) : executionContext {};

  let op_33_CALLER = func (exCon: executionContext) : executionContext {};

  let op_34_CALLVALUE = func (exCon: executionContext) : executionContext {};

  let op_35_CALLDATALOAD = func (exCon: executionContext) : executionContext {};

  let op_36_CALLDATASIZE = func (exCon: executionContext) : executionContext {};

  let op_37_CALLDATACOPY = func (exCon: executionContext) : executionContext {};

  let op_38_CODESIZE = func (exCon: executionContext) : executionContext {};

  let op_39_CODECOPY = func (exCon: executionContext) : executionContext {};

  let op_3A_GASPRICE = func (exCon: executionContext) : executionContext {};

  let op_3B_EXTCODESIZE = func (exCon: executionContext) : executionContext {};

  let op_3C_EXTCODECOPY = func (exCon: executionContext) : executionContext {};

  let op_3D_RETURNDATASIZE = func (exCon: executionContext) : executionContext {};

  let op_3E_RETURNDATACOPY = func (exCon: executionContext) : executionContext {};

  let op_3F_EXTCODEHASH = func (exCon: executionContext) : executionContext {};

  let op_40_BLOCKHASH = func (exCon: executionContext) : executionContext {};

  let op_41_COINBASE = func (exCon: executionContext) : executionContext {};

  let op_42_TIMESTAMP = func (exCon: executionContext) : executionContext {};

  let op_43_NUMBER = func (exCon: executionContext) : executionContext {};

  let op_44_PREVRANDAO = func (exCon: executionContext) : executionContext {};

  let op_45_GASLIMIT = func (exCon: executionContext) : executionContext {};

  let op_46_CHAINID = func (exCon: executionContext) : executionContext {};

  let op_47_SELFBALANCE = func (exCon: executionContext) : executionContext {};

  let op_48_BASEFEE = func (exCon: executionContext) : executionContext {};


  // Memory Operations

  let op_50_POP = func (exCon: executionContext) : executionContext {};

  let op_51_MLOAD = func (exCon: executionContext) : executionContext {};

  let op_52_MSTORE = func (exCon: executionContext) : executionContext {};

  let op_53_MSTORE8 = func (exCon: executionContext) : executionContext {};

  let op_54_SLOAD = func (exCon: executionContext) : executionContext {};

  let op_55_SSTORE = func (exCon: executionContext) : executionContext {};

  let op_56_JUMP = func (exCon: executionContext) : executionContext {};

  let op_57_JUMPI = func (exCon: executionContext) : executionContext {};

  let op_58_PC = func (exCon: executionContext) : executionContext {};

  let op_59_MSIZE = func (exCon: executionContext) : executionContext {};

  let op_5A_GAS = func (exCon: executionContext) : executionContext {};

  let op_5B_JUMPDEST = func (exCon: executionContext) : executionContext {};


  // Push Operations, Duplication Operations, Exchange Operations
  
  let op_5F_PUSH0 = func (exCon: executionContext) : executionContext {};

  let op_60_PUSH1 = func (exCon: executionContext) : executionContext {};

  let op_61_PUSH2 = func (exCon: executionContext) : executionContext {};

  let op_62_PUSH3 = func (exCon: executionContext) : executionContext {};

  let op_63_PUSH4 = func (exCon: executionContext) : executionContext {};

  let op_64_PUSH5 = func (exCon: executionContext) : executionContext {};

  let op_65_PUSH6 = func (exCon: executionContext) : executionContext {};

  let op_66_PUSH7 = func (exCon: executionContext) : executionContext {};

  let op_67_PUSH8 = func (exCon: executionContext) : executionContext {};

  let op_68_PUSH9 = func (exCon: executionContext) : executionContext {};

  let op_69_PUSH10 = func (exCon: executionContext) : executionContext {};

  let op_6A_PUSH11 = func (exCon: executionContext) : executionContext {};

  let op_6B_PUSH12 = func (exCon: executionContext) : executionContext {};

  let op_6C_PUSH13 = func (exCon: executionContext) : executionContext {};

  let op_6D_PUSH14 = func (exCon: executionContext) : executionContext {};

  let op_6E_PUSH15 = func (exCon: executionContext) : executionContext {};

  let op_6F_PUSH16 = func (exCon: executionContext) : executionContext {};

  let op_70_PUSH17 = func (exCon: executionContext) : executionContext {};

  let op_71_PUSH18 = func (exCon: executionContext) : executionContext {};

  let op_72_PUSH19 = func (exCon: executionContext) : executionContext {};

  let op_73_PUSH20 = func (exCon: executionContext) : executionContext {};

  let op_74_PUSH21 = func (exCon: executionContext) : executionContext {};

  let op_75_PUSH22 = func (exCon: executionContext) : executionContext {};

  let op_76_PUSH23 = func (exCon: executionContext) : executionContext {};

  let op_77_PUSH24 = func (exCon: executionContext) : executionContext {};

  let op_78_PUSH25 = func (exCon: executionContext) : executionContext {};

  let op_79_PUSH26 = func (exCon: executionContext) : executionContext {};

  let op_7A_PUSH27 = func (exCon: executionContext) : executionContext {};

  let op_7B_PUSH28 = func (exCon: executionContext) : executionContext {};

  let op_7C_PUSH29 = func (exCon: executionContext) : executionContext {};

  let op_7D_PUSH30 = func (exCon: executionContext) : executionContext {};

  let op_7E_PUSH31 = func (exCon: executionContext) : executionContext {};

  let op_7F_PUSH32 = func (exCon: executionContext) : executionContext {};

  let op_80_DUP1 = func (exCon: executionContext) : executionContext {};

  let op_81_DUP2 = func (exCon: executionContext) : executionContext {};

  let op_82_DUP3 = func (exCon: executionContext) : executionContext {};

  let op_83_DUP4 = func (exCon: executionContext) : executionContext {};

  let op_84_DUP5 = func (exCon: executionContext) : executionContext {};

  let op_85_DUP6 = func (exCon: executionContext) : executionContext {};

  let op_86_DUP7 = func (exCon: executionContext) : executionContext {};

  let op_87_DUP8 = func (exCon: executionContext) : executionContext {};

  let op_88_DUP9 = func (exCon: executionContext) : executionContext {};

  let op_89_DUP10 = func (exCon: executionContext) : executionContext {};

  let op_8A_DUP11 = func (exCon: executionContext) : executionContext {};

  let op_8B_DUP12 = func (exCon: executionContext) : executionContext {};

  let op_8C_DUP13 = func (exCon: executionContext) : executionContext {};

  let op_8D_DUP14 = func (exCon: executionContext) : executionContext {};

  let op_8E_DUP15 = func (exCon: executionContext) : executionContext {};

  let op_8F_DUP16 = func (exCon: executionContext) : executionContext {};

  let op_90_SWAP1 = func (exCon: executionContext) : executionContext {};

  let op_91_SWAP2 = func (exCon: executionContext) : executionContext {};

  let op_92_SWAP3 = func (exCon: executionContext) : executionContext {};

  let op_93_SWAP4 = func (exCon: executionContext) : executionContext {};

  let op_94_SWAP5 = func (exCon: executionContext) : executionContext {};

  let op_95_SWAP6 = func (exCon: executionContext) : executionContext {};

  let op_96_SWAP7 = func (exCon: executionContext) : executionContext {};

  let op_97_SWAP8 = func (exCon: executionContext) : executionContext {};

  let op_98_SWAP9 = func (exCon: executionContext) : executionContext {};

  let op_99_SWAP10 = func (exCon: executionContext) : executionContext {};

  let op_9A_SWAP11 = func (exCon: executionContext) : executionContext {};

  let op_9B_SWAP12 = func (exCon: executionContext) : executionContext {};

  let op_9C_SWAP13 = func (exCon: executionContext) : executionContext {};

  let op_9D_SWAP14 = func (exCon: executionContext) : executionContext {};

  let op_9E_SWAP15 = func (exCon: executionContext) : executionContext {};

  let op_9F_SWAP16 = func (exCon: executionContext) : executionContext {};


  // Logging Operations

  let op_A0_LOG0 = func (exCon: executionContext) : executionContext {};

  let op_A1_LOG1 = func (exCon: executionContext) : executionContext {};

  let op_A2_LOG2 = func (exCon: executionContext) : executionContext {};

  let op_A3_LOG3 = func (exCon: executionContext) : executionContext {};

  let op_A4_LOG4 = func (exCon: executionContext) : executionContext {};


  // Execution and System Operations
  
  let op_00_STOP = func (exCon: executionContext) : executionContext {};

  let op_F0_CREATE = func (exCon: executionContext) : executionContext {};

  let op_F1_CALL = func (exCon: executionContext) : executionContext {};

  let op_F2_CALLCODE = func (exCon: executionContext) : executionContext {};

  let op_F3_RETURN = func (exCon: executionContext) : executionContext {};

  let op_F4_DELEGATECALL = func (exCon: executionContext) : executionContext {};

  let op_F5_CREATE2 = func (exCon: executionContext) : executionContext {};

  let op_FA_STATICCALL = func (exCon: executionContext) : executionContext {};

  let op_FB_TXHASH = func (exCon: executionContext) : executionContext {};

  let op_FC_CHAINID = func (exCon: executionContext) : executionContext {};

  let op_FD_REVERT = func (exCon: executionContext) : executionContext {};

  let op_FE_INVALID = func (exCon: executionContext) : executionContext {};

  let op_FF_SELFDESTRUCT = func (exCon: executionContext) : executionContext {};


  // Other

  let op_20_KECCAK256 = func (exCon: executionContext) : executionContext {};

  let op_49_BLOBHASH = func (exCon: executionContext) : executionContext {};

  let op_4A_BLOBBASEFEE = func (exCon: executionContext) : executionContext {};

  let op_5C_TLOAD = func (exCon: executionContext) : executionContext {};

  let op_5D_TSTORE = func (exCon: executionContext) : executionContext {};

  let op_5E_MCOPY = func (exCon: executionContext) : executionContext {};


  // Unused
  let op_0C_ = func (exCon: executionContext) : executionContext {};
  let op_0D_ = func (exCon: executionContext) : executionContext {};
  let op_0E_ = func (exCon: executionContext) : executionContext {};
  let op_0F_ = func (exCon: executionContext) : executionContext {};
  let op_1E_ = func (exCon: executionContext) : executionContext {};
  let op_1F_ = func (exCon: executionContext) : executionContext {};
  let op_21_ = func (exCon: executionContext) : executionContext {};
  let op_22_ = func (exCon: executionContext) : executionContext {};
  let op_23_ = func (exCon: executionContext) : executionContext {};
  let op_24_ = func (exCon: executionContext) : executionContext {};
  let op_25_ = func (exCon: executionContext) : executionContext {};
  let op_26_ = func (exCon: executionContext) : executionContext {};
  let op_27_ = func (exCon: executionContext) : executionContext {};
  let op_28_ = func (exCon: executionContext) : executionContext {};
  let op_29_ = func (exCon: executionContext) : executionContext {};
  let op_2A_ = func (exCon: executionContext) : executionContext {};
  let op_2B_ = func (exCon: executionContext) : executionContext {};
  let op_2C_ = func (exCon: executionContext) : executionContext {};
  let op_2D_ = func (exCon: executionContext) : executionContext {};
  let op_2E_ = func (exCon: executionContext) : executionContext {};
  let op_2F_ = func (exCon: executionContext) : executionContext {};
  let op_4B_ = func (exCon: executionContext) : executionContext {};
  let op_4C_ = func (exCon: executionContext) : executionContext {};
  let op_4D_ = func (exCon: executionContext) : executionContext {};
  let op_4E_ = func (exCon: executionContext) : executionContext {};
  let op_4F_ = func (exCon: executionContext) : executionContext {};
  let op_A5_ = func (exCon: executionContext) : executionContext {};
  let op_A6_ = func (exCon: executionContext) : executionContext {};
  let op_A7_ = func (exCon: executionContext) : executionContext {};
  let op_A8_ = func (exCon: executionContext) : executionContext {};
  let op_A9_ = func (exCon: executionContext) : executionContext {};
  let op_AA_ = func (exCon: executionContext) : executionContext {};
  let op_AB_ = func (exCon: executionContext) : executionContext {};
  let op_AC_ = func (exCon: executionContext) : executionContext {};
  let op_AD_ = func (exCon: executionContext) : executionContext {};
  let op_AE_ = func (exCon: executionContext) : executionContext {};
  let op_AF_ = func (exCon: executionContext) : executionContext {};
  let op_B0_ = func (exCon: executionContext) : executionContext {};
  let op_B1_ = func (exCon: executionContext) : executionContext {};
  let op_B2_ = func (exCon: executionContext) : executionContext {};
  let op_B3_ = func (exCon: executionContext) : executionContext {};
  let op_B4_ = func (exCon: executionContext) : executionContext {};
  let op_B5_ = func (exCon: executionContext) : executionContext {};
  let op_B6_ = func (exCon: executionContext) : executionContext {};
  let op_B7_ = func (exCon: executionContext) : executionContext {};
  let op_B8_ = func (exCon: executionContext) : executionContext {};
  let op_B9_ = func (exCon: executionContext) : executionContext {};
  let op_BA_ = func (exCon: executionContext) : executionContext {};
  let op_BB_ = func (exCon: executionContext) : executionContext {};
  let op_BC_ = func (exCon: executionContext) : executionContext {};
  let op_BD_ = func (exCon: executionContext) : executionContext {};
  let op_BE_ = func (exCon: executionContext) : executionContext {};
  let op_BF_ = func (exCon: executionContext) : executionContext {};
  let op_C0_ = func (exCon: executionContext) : executionContext {};
  let op_C1_ = func (exCon: executionContext) : executionContext {};
  let op_C2_ = func (exCon: executionContext) : executionContext {};
  let op_C3_ = func (exCon: executionContext) : executionContext {};
  let op_C4_ = func (exCon: executionContext) : executionContext {};
  let op_C5_ = func (exCon: executionContext) : executionContext {};
  let op_C6_ = func (exCon: executionContext) : executionContext {};
  let op_C7_ = func (exCon: executionContext) : executionContext {};
  let op_C8_ = func (exCon: executionContext) : executionContext {};
  let op_C9_ = func (exCon: executionContext) : executionContext {};
  let op_CA_ = func (exCon: executionContext) : executionContext {};
  let op_CB_ = func (exCon: executionContext) : executionContext {};
  let op_CC_ = func (exCon: executionContext) : executionContext {};
  let op_CD_ = func (exCon: executionContext) : executionContext {};
  let op_CE_ = func (exCon: executionContext) : executionContext {};
  let op_CF_ = func (exCon: executionContext) : executionContext {};
  let op_D0_ = func (exCon: executionContext) : executionContext {};
  let op_D1_ = func (exCon: executionContext) : executionContext {};
  let op_D2_ = func (exCon: executionContext) : executionContext {};
  let op_D3_ = func (exCon: executionContext) : executionContext {};
  let op_D4_ = func (exCon: executionContext) : executionContext {};
  let op_D5_ = func (exCon: executionContext) : executionContext {};
  let op_D6_ = func (exCon: executionContext) : executionContext {};
  let op_D7_ = func (exCon: executionContext) : executionContext {};
  let op_D8_ = func (exCon: executionContext) : executionContext {};
  let op_D9_ = func (exCon: executionContext) : executionContext {};
  let op_DA_ = func (exCon: executionContext) : executionContext {};
  let op_DB_ = func (exCon: executionContext) : executionContext {};
  let op_DC_ = func (exCon: executionContext) : executionContext {};
  let op_DD_ = func (exCon: executionContext) : executionContext {};
  let op_DE_ = func (exCon: executionContext) : executionContext {};
  let op_DF_ = func (exCon: executionContext) : executionContext {};
  let op_E0_ = func (exCon: executionContext) : executionContext {};
  let op_E1_ = func (exCon: executionContext) : executionContext {};
  let op_E2_ = func (exCon: executionContext) : executionContext {};
  let op_E3_ = func (exCon: executionContext) : executionContext {};
  let op_E4_ = func (exCon: executionContext) : executionContext {};
  let op_E5_ = func (exCon: executionContext) : executionContext {};
  let op_E6_ = func (exCon: executionContext) : executionContext {};
  let op_E7_ = func (exCon: executionContext) : executionContext {};
  let op_E8_ = func (exCon: executionContext) : executionContext {};
  let op_E9_ = func (exCon: executionContext) : executionContext {};
  let op_EA_ = func (exCon: executionContext) : executionContext {};
  let op_EB_ = func (exCon: executionContext) : executionContext {};
  let op_EC_ = func (exCon: executionContext) : executionContext {};
  let op_ED_ = func (exCon: executionContext) : executionContext {};
  let op_EE_ = func (exCon: executionContext) : executionContext {};
  let op_EF_ = func (exCon: executionContext) : executionContext {};
  let op_F6_ = func (exCon: executionContext) : executionContext {};
  let op_F7_ = func (exCon: executionContext) : executionContext {};
  let op_F8_ = func (exCon: executionContext) : executionContext {};
  let op_F9_ = func (exCon: executionContext) : executionContext {};


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
