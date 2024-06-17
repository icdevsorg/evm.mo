// Note this is still a work in progress and code is not yet functional.

import Array "mo:base/Array";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map
// any other imports needed

import Types "./types";

actor {

  class EVMStack = Types.EVMStack;
  type ExecutionContext = Types.ExecutionContext;
  type Transaction = Types.Transaction;
  type CallerState = Types.CallerState;
  type CalleeState = Types.CalleeState;
  type BlockInfo = Types.BlockInfo;

  type Engine = [(ExecutionContext) -> async ExecutionContext];

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
    let exCon.balanceChanges = Vec.new<BalanceChange>();
    assert (fee + tx.incomingEth <= callerState.balance);
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = blockInfo.blockCoinbase;
      amount = fee;
    });
    // Initialize GAS = STARTGAS, and take off a certain quantity of gas per byte to pay for the bytes in the transaction.
    var remainingGas = fee;
    // Transfer the transaction value from the sender's account to the receiving account.
    // Check that ((callerState.balance - fee) > tx.incomingEth) => included above for this version
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = tx.callee;
      amount = tx.incomingEth;
    })
    // If the receiving account does not yet exist, create it. => TODO

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

    // If the receiving account is a contract, run the contract's code either to completion or until the execution runs out of gas.
    if (calleeState.code != []) {
      executeCode( exCon );
    } else {
      exCon;
    };
    // If the value transfer failed because the sender did not have enough money (TODO), or the code execution ran out of gas, revert all state changes except the payment of the fees, and add the fees to the miner's account.
    // Otherwise, refund the fees for all remaining gas to the sender, and send the fees paid for gas consumed to the miner.
  };

  public func executeCode(exCon: ExecutionContext) : ExecutionContext {
    let codeSize = Array.size(exCon.code);
    while (exCon.programCounter < codeSize) {
      // get current instruction from code[programCounter]
      let instruction = code[exCon.programCounter].0;
      // execute instruction via OPCODE functions
      let output : ExecutionContext = try {
        await engine[instruction](exCon);
      } catch (e) {
        return revert(exCon);
      }
      if (output.totalGas < 0) {
        // terminate execution and run out-of-gas sequence
        return revert(exCon);
      } else {
        exCon := output;
        exCon.programCounter += 1;
      }
    };
    exCon;
  };

  public func revert(exCon: ExecutionContext) : ExecutionContext {
    // revert all state changes except payment of fees
    exCon.programCounter := Array.size(exCon.code);
    exCon.contractStorage := calleeState.storage;
    let exCon.balanceChanges = Vec.new<BalanceChange>();
    Vec.add(balanceChanges, {
      from = tx.caller;
      to = blockInfo.blockCoinbase;
      amount = fee;
    });
    let exCon.storageChanges = Map.new<(Blob, StorageSlotChange)>();
    let exCon.codeAdditions = Map.Map.new<Blob, CodeChange>(); 
    let exCon.codeStore = Map.Map.new<Blob, Array<OpCode>>(); 
    let exCon.storageStore = Trie.empty();
    // other changes to revert?
    exCon;
  };

  // OPCODE FUNCTIONS

  // Basic Math and Bitwise Logic

  let op_01_ADD = func (exCon: ExecutionContext) : async ExecutionContext {
    // pop two values from the stack; traps if stack is empty
    let a: Int = exCon.stack.pop();
    let b: Int = exCon.stack.pop();
    // add them
    let result = a + b;
    // check for result overflow
    result := result % 2**256;
    // check for stack overflow => will trap
    // push result to stack
    exCon.stack.push(result);
    exCon.totalGas -= 3;
    // return new execution context
    exCon;
  };

  let op_02_MUL = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_03_SUB = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_04_DIV = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_05_SDIV = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_06_MOD = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_07_SMOD = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_08_ADDMOD = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_09_MULMOD = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_0A_EXP = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_0B_SIGNEXTEND = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_10_LT = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_11_GT = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_12_SLT = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_13_SGT = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_14_EQ = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_15_ISZERO = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_16_AND = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_17_OR = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_18_XOR = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_19_NOT = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_1A_BYTE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_1B_SHL = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_1C_SHR = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_1D_SAR = func (exCon: ExecutionContext) : async ExecutionContext {};


  // Environmental Information and Block Information

  let op_30_ADDRESS = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_31_BALANCE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_32_ORIGIN = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_33_CALLER = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_34_CALLVALUE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_35_CALLDATALOAD = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_36_CALLDATASIZE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_37_CALLDATACOPY = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_38_CODESIZE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_39_CODECOPY = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_3A_GASPRICE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_3B_EXTCODESIZE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_3C_EXTCODECOPY = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_3D_RETURNDATASIZE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_3E_RETURNDATACOPY = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_3F_EXTCODEHASH = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_40_BLOCKHASH = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_41_COINBASE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_42_TIMESTAMP = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_43_NUMBER = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_44_PREVRANDAO = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_45_GASLIMIT = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_46_CHAINID = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_47_SELFBALANCE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_48_BASEFEE = func (exCon: ExecutionContext) : async ExecutionContext {};


  // Memory Operations

  let op_50_POP = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_51_MLOAD = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_52_MSTORE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_53_MSTORE8 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_54_SLOAD = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_55_SSTORE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_56_JUMP = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_57_JUMPI = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_58_PC = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_59_MSIZE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_5A_GAS = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_5B_JUMPDEST = func (exCon: ExecutionContext) : async ExecutionContext {};


  // Push Operations, Duplication Operations, Exchange Operations
  
  let op_5F_PUSH0 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_60_PUSH1 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_61_PUSH2 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_62_PUSH3 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_63_PUSH4 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_64_PUSH5 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_65_PUSH6 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_66_PUSH7 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_67_PUSH8 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_68_PUSH9 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_69_PUSH10 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_6A_PUSH11 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_6B_PUSH12 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_6C_PUSH13 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_6D_PUSH14 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_6E_PUSH15 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_6F_PUSH16 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_70_PUSH17 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_71_PUSH18 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_72_PUSH19 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_73_PUSH20 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_74_PUSH21 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_75_PUSH22 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_76_PUSH23 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_77_PUSH24 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_78_PUSH25 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_79_PUSH26 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_7A_PUSH27 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_7B_PUSH28 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_7C_PUSH29 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_7D_PUSH30 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_7E_PUSH31 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_7F_PUSH32 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_80_DUP1 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_81_DUP2 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_82_DUP3 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_83_DUP4 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_84_DUP5 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_85_DUP6 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_86_DUP7 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_87_DUP8 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_88_DUP9 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_89_DUP10 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_8A_DUP11 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_8B_DUP12 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_8C_DUP13 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_8D_DUP14 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_8E_DUP15 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_8F_DUP16 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_90_SWAP1 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_91_SWAP2 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_92_SWAP3 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_93_SWAP4 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_94_SWAP5 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_95_SWAP6 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_96_SWAP7 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_97_SWAP8 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_98_SWAP9 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_99_SWAP10 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_9A_SWAP11 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_9B_SWAP12 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_9C_SWAP13 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_9D_SWAP14 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_9E_SWAP15 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_9F_SWAP16 = func (exCon: ExecutionContext) : async ExecutionContext {};


  // Logging Operations

  let op_A0_LOG0 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_A1_LOG1 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_A2_LOG2 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_A3_LOG3 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_A4_LOG4 = func (exCon: ExecutionContext) : async ExecutionContext {};


  // Execution and System Operations
  
  let op_00_STOP = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_F0_CREATE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_F1_CALL = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_F2_CALLCODE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_F3_RETURN = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_F4_DELEGATECALL = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_F5_CREATE2 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_FA_STATICCALL = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_FB_TXHASH = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_FC_CHAINID = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_FD_REVERT = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_FE_INVALID = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_FF_SELFDESTRUCT = func (exCon: ExecutionContext) : async ExecutionContext {};


  // Other

  let op_20_KECCAK256 = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_49_BLOBHASH = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_4A_BLOBBASEFEE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_5C_TLOAD = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_5D_TSTORE = func (exCon: ExecutionContext) : async ExecutionContext {};

  let op_5E_MCOPY = func (exCon: ExecutionContext) : async ExecutionContext {};


  // Unused
  let op_0C_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_0D_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_0E_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_0F_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_1E_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_1F_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_21_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_22_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_23_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_24_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_25_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_26_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_27_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_28_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_29_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_2A_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_2B_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_2C_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_2D_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_2E_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_2F_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_4B_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_4C_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_4D_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_4E_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_4F_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_A5_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_A6_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_A7_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_A8_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_A9_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_AA_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_AB_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_AC_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_AD_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_AE_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_AF_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B0_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B1_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B2_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B3_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B4_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B5_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B6_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B7_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B8_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_B9_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_BA_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_BB_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_BC_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_BD_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_BE_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_BF_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C0_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C1_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C2_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C3_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C4_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C5_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C6_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C7_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C8_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_C9_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_CA_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_CB_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_CC_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_CD_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_CE_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_CF_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D0_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D1_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D2_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D3_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D4_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D5_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D6_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D7_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D8_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_D9_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_DA_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_DB_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_DC_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_DD_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_DE_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_DF_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E0_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E1_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E2_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E3_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E4_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E5_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E6_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E7_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E8_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_E9_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_EA_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_EB_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_EC_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_ED_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_EE_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_EF_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_F6_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_F7_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_F8_ = func (exCon: ExecutionContext) : async ExecutionContext {};
  let op_F9_ = func (exCon: ExecutionContext) : async ExecutionContext {};


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
