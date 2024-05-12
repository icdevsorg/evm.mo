import Array "mo:base/Array";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map

module {
  public type Address = Blob;
  public type Byte = Nat8;
  public type Word = Nat; // 256-bit for EVM compliance. Op codes will need to validate that results do not exceed 256-bit numbers and take overflows into consideration
  public type OpCode = (Nat8,?Blob); // Considering opcodes range from 0x00 to 0xFF. Plus a set of bytes that can be included

  // A simplified representation of the stack element in EVM. Redundant if EVMStack is used.
  //public type StackElement = Nat; // May need to represent 256-bit integers.

  // A simplified structure for representing EVM memory.
  // Uses https://github.com/research-ag/vector
  public type Memory = Vec<Byte>;

  // Represents the EVM storage, mapping 32-byte keys to 32-byte values.
  public type Storage = Map<[Nat8], [Nat8]>;

  public type LogEntry = {
    topics: Vec<Blob>; // Topics are usually the hashed event signature and indexed parameters
    data: Blob; // Non-indexed event parameters
  };

  public type Logs = Vec<LogEntry>;

  public type StorageSlotChange = {
    key: Blob; // Storage key, typically a 32-byte array.
    originalValue: ?[Nat8]; // Optional, represents the value before the change. `None` can indicate the slot was empty.
    newValue: ?[Nat8]; // Optional, represents the value after the change. `None` can indicate a deletion.
  };

  public type CodeChange = {
    key: Blob; // Storage key, typically a 32-byte array.
    originalValue: Array<OpCode>; // Optional, represents the value before the change. `None` can indicate the slot was empty.
    newValue: ?Array<OpCode>; // Optional, represents the value after the change. `None` can indicate a deletion.
  }; // Code may not be changeable...only deletable

  public type BalanceChange = {
    from: Blob;
    to: Blob;
    amount: Nat;
  };

  // A structure representing an EVM-specific stack.
  public class EVMStack() {
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
  public type ExecutionContext = {
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
    code: Array<Opcode>; // empty for externally owned accounts
    storage: Storage; // empty for externally owned accounts
  };

  public type CalleeState = {
    balance: Nat;
    nonce: Nat;
    code: Array<Opcode>;
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