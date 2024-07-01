//import Result "mo:base/Result";
import { test } "mo:test/async"; // see https://mops.one/test

import { stateTransition } "../src/evm_mo_backend/main";

import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Trie "mo:base/Trie";
import Debug "mo:base/Debug";
import Vec "mo:vector";
import Map "mo:map/Map";
import EVMStack "../src/evm_mo_backend/evmStack";
import T "../src/evm_mo_backend/types";

let defaultTransaction: T.Transaction = {
    caller = "\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa";
    nonce = 2;
    gasPriceTx = 5;
    gasLimitTx = 100;
    callee = "\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb";
    incomingEth = 0;
    dataTx = "\00\ee";
};

let defaultCallerState: T.CallerState = {
    balance = 5000;
    nonce = 1;
    code = [];
    storage = Trie.empty();
};

let defaultCalleeState: T.CalleeState = {
    balance = 0;
    nonce = 0;
    code = [(0x60,null), (2,null), (0x60,null), (1,null), (0x01,null)]; // 1 + 2 = ?
    storage = Trie.empty();
};

let defaultBlockInfo: T.BlockInfo = {
    blockNumber = 1_000_000;
    blockGasLimit = 30_000_000;
    blockDifficulty = 1_000_000_000_000;
    blockTimestamp = 1_500_000_000;
    blockCoinbase = "\00\ff";
    chainId = 1;
};

func testOpCodes(code: [T.OpCode]) : async T.ExecutionContext {
    let context = await stateTransition(
        defaultTransaction,
        defaultCallerState,
        {
            balance = 0;
            nonce = 0;
            code = code;
            storage = Trie.empty();
        },
        5,
        [],
        Trie.empty(),
        defaultBlockInfo
    );
    context;
};

test("1 + 2 = 3", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (2,null), (0x60,null), (1,null), (0x01,null)] // 1 + 2 = ?
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});
