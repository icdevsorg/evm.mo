import D "mo:base/Debug";
import { test } "mo:test"; // see https://mops.one/test
import Array "mo:base/Array";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map

import Types "./types";

class EVMStack = Types.EVMStack;
type ExecutionContext = Types.ExecutionContext;
type Transaction = Types.Transaction;
type CallerState = Types.CallerState;
type CalleeState = Types.CalleeState;
type BlockInfo = Types.BlockInfo;

let defaultBlockInfo: BlockInfo = {
    blockNumber = 1_000_000;
    blockGasLimit = 30_000_000;
    blockDifficulty = 1_000_000_000_000;
    blockTimestamp = 1_500_000_000;
    blockCoinbase = "\00\ff";
    chainId = 1;
};

func initiateCall(
    tx: Transaction,
    callerState: CallerState,
    calleeState: CalleeState,
    gasPrice: Nat,
    blockHashes: Vec<(Nat, Blob)>,
    accounts: Trie.Trie<Blob, Blob>,
    blockInfo: BlockInfo
) : ExecutionContext {
};