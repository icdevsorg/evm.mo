import Trie "mo:base/Trie";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map
import EVMStack "evmStack";

module {
  public type Address = Blob;
  public type Byte = Nat8;
  public type Word = Nat; // 256-bit for EVM compliance. Op codes will need to validate that results do not exceed 256-bit numbers and take overflows into consideration
  public type OpCode = Nat8; // Considering opcodes range from 0x00 to 0xFF. (Removed: Plus a set of bytes that can be included)
  public type EVMStack = EVMStack.EVMStack;

  type Vec<X> = Vec.Vector<X>;
  type Map<K, V> = Map.Map<K, V>;
  type Trie<K, V> = Trie.Trie<K, V>;

  // A simplified structure for representing EVM memory.
  // Uses https://github.com/research-ag/vector
  public type Memory = Vec<Nat8>;

  // Represents the EVM storage, mapping 32-byte keys to 32-byte values.
  public type Storage = Trie.Trie<[Nat8], [Nat8]>; // changed from Map<[Nat8], [Nat8]>

  public type LogEntry = {
    topics: [Blob]; // Changed from Vec<Blob>. Topics are usually the hashed event signature and indexed parameters
    data: Blob; // Non-indexed event parameters
  };

  public type Logs = Vec<LogEntry>;

  public type StorageSlotChange = {
    key: Blob; // Storage key, typically a 32-byte array.
    originalValue: ?[Nat8]; // Optional, represents the value before the change. `None` can indicate the slot was empty.
    newValue: ?[Nat8]; // Optional, represents the value after the change. `None` can indicate a deletion.
  };

  public type CodeChange = {
    // Key uses hash of (address + original code), or getCodeHash(Array.append<Nat8>(Blob.toArray(address), originalValue))
    // TODO - check that code only changes once, as otherwise this might not work.
    key: Blob; // Storage key, typically a 32-byte array.
    originalValue: [OpCode]; // Optional, represents the value before the change. `None` can indicate the slot was empty.
    newValue: ?[OpCode]; // Optional, represents the value after the change. `None` can indicate a deletion.
  }; // Code may not be changeable...only deletable

  public type BalanceChange = {
    from: Blob;
    to: Blob;
    amount: Nat;
  };

  // The execution context of an EVM call.
  public type ExecutionContext = {
    origin: Blob; //originator of the transaction
    code: [OpCode]; // Array of opcodes constituting the smart contract code.
    programCounter: Nat; // Points to the current instruction in the code.
    stack: [Nat]; //EVMStack; // The stack used for instruction params and return values.
    memory: [Byte]; //Memory; // Memory accessible during execution.
    contractStorage: Storage; // Persistent storage for smart contracts.
    caller: Address; // Address of the call initiator.
    callee: Address; // Address of the contract being executed.
    currentGas: Nat; // Amount of gas available for the current execution.
    gasPrice: Nat; // Current gas price.
    incomingEth: Nat; //amount of eth included with the call
    balanceChanges: [BalanceChange]; //Vec<BalanceChange>; //keep track of eth balance changes and commit at the end. Each new context will have to adjust balances based off of this array.
    storageChanges: [(Blob, StorageSlotChange)]; //Map<Blob, StorageSlotChange>;
    codeAdditions: [(Blob, CodeChange)]; //Map.Map<Blob, CodeChange>; //storage DB for EVM code stored by Hash Key
    blockHashes: [(Nat, Blob)]; //Vec<(Nat,Blob)>; //up to last 256 block numbers and hashs
    codeStore: [(Blob, [OpCode])]; //Map.Map<Blob, [OpCode]>; //storage DB for EVM code stored by Hash Key
    // storageStore is changed from Trie.Map<> to Trie.Trie<>
    storageStore: [(Blob, Blob)]; //storage DB for Contract Storage stored by Hash Key. CALL implementors will need to keep track of storage changes and revert storage if necessary.
    accounts: Trie<Blob,Blob>; //a merkle patricia tree storing [binary_nonce, binary_balance, storage_root, code_hash] as RLP encoded data - the account bounty hunter will need to create encoders/decoders for use with the trie - https://github.com/relaxed04/rlp-motoko - https://github.com/f0i/merkle-patricia-trie.mo
    logs: [LogEntry]; //Logs; //logs produced during execution
    totalGas: Nat; // Used for keeping track of gas
    gasRefund: Nat; // Used for keeping track of gas refunded
    returnData: ?Blob; // set for return
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

  public type ExecutionVariables = {
    var programCounter: Nat;
    var stack: EVMStack;
    var memory: Memory;
    var contractStorage: Storage;
    var balanceChanges: Vec<BalanceChange>;
    var storageChanges: Map<Blob, StorageSlotChange>;
    var codeAdditions: Map<Blob, CodeChange>;
    var codeStore: Map<Blob, [OpCode]>;
    // storageStore is changed from Trie.Map<> to Map.Map<>
    var storageStore: Map<Blob, Blob>;
    var logs: Logs;
    var totalGas: Nat;
    var returnData: ?Blob;
  };

  public type Transaction = {
    caller: Address; // The sender of the message, represented in a real transaction as ECDSA signature components v,r,s
    nonce: Nat; // A sequence number, issued by the caller, used to prevent message replay
    gasPriceTx: Nat; // The amount of ether (in wei) that the caller is willing to pay for each unit of gas
    gasLimitTx: Nat; // The maximum amount of gas (units?) the caller is willing to buy for this transaction
    callee: Address; // The recipient of the message
    incomingEth: Nat; // The amount of ether to transfer alongside the message
    dataTx: Blob; // An optional data field
  };

  public type CallerState = {
    balance: Nat;
    nonce: Nat;
    code: [OpCode]; // empty for externally owned accounts
    storage: Storage; // empty for externally owned accounts
  };

  public type CalleeState = {
    balance: Nat;
    nonce: Nat;
    code: [OpCode];
    storage: Storage;
  };

  public type BlockInfo = {
    blockNumber: Nat;
    blockGasLimit: Nat;
    blockDifficulty: Nat;
    blockTimestamp: Nat;
    blockCoinbase: Blob;
    chainId: Nat;
  };
};