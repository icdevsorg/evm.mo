import { test; skip } "mo:test/async"; // see https://mops.one/test

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

let dummyTransaction: T.Transaction = {
    caller = "\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa";
    nonce = 2;
    gasPriceTx = 5;
    gasLimitTx = 100;
    callee = "\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb";
    incomingEth = 0;
    dataTx = "\00\ee";
};

let dummyCallerState: T.CallerState = {
    balance = 5000;
    nonce = 1;
    code = [];
    storage = Trie.empty();
};

let dummyBlockInfo: T.BlockInfo = {
    blockNumber = 1_000_000;
    blockGasLimit = 30_000_000;
    blockDifficulty = 1_000_000_000_000;
    blockTimestamp = 1_500_000_000;
    blockCoinbase = "\00\ff";
    chainId = 1;
};

func testOpCodes(code: [T.OpCode]) : async T.ExecutionContext {
    let context = await stateTransition(
        dummyTransaction,
        dummyCallerState,
        {
            balance = 0;
            nonce = 0;
            code = code;
            storage = Trie.empty();
        },
        5,
        [],
        Trie.empty(),
        dummyBlockInfo
    );
    context;
};

await test("ADD: 1 + 2", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (2,null), (0x60,null), (1,null), (0x01,null)] // PUSH1 2 PUSH1 1 ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});

await test("ADD: (2**256-3) + 5", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (5,null),    // PUSH1 5
        (0x7F,null),               // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFD,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD
        (0x01,null)]              // ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [2]);
});

await test("ADD: stack should underflow", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (2,null), (0x01,null)] // PUSH1 2 ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == []);
});

await test("MUL: 1000 * 2000", func() : async () {
    let context = await testOpCodes(
        [(0x61,null), (0x07,null), (0xD0,null), // PUSH2 0x07D0
        (0x61,null), (0x03,null), (0xE8,null),  // PUSH2 0x03E8
        (0x02,null)]                                 // MUL
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [2_000_000]);
});

await test("MUL: (2**80-6) * (2**160-6)", func() : async () {
    let context = await testOpCodes(
        [(0x73,null), // PUSH20 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFA
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFA,null), // 
        (0x69,null), // PUSH10 0xFFFFFFFFFFFFFFFFFFFA
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFA,null), 
        (0x02,null)] // MUL
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfffffffffffffffffff9fffffffffffffffffffa00000000000000000024]);
});

await test("SUB: 8 - 20", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (20,null), (0x60,null), (8,null), (0x03,null)] // PUSH1 20 PUSH1 8 SUB
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [(2**256 - 12)]);
});

await test("DIV: 20 / 3", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (3,null), (0x60,null), (20,null), (0x04,null)] // PUSH1 3 PUSH1 20 DIV
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [6]);
});

await test("DIV: 4 / 0", func() : async () {
    let context = await testOpCodes(
        [(0x5F,null), (0x60,null), (4,null), (0x04,null)] // PUSH0 PUSH1 4 DIV
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

await test("SDIV: 10 / -2", func() : async () { // throws "execution error, arithmetic overflow"
    let context = await testOpCodes(
        [(0x7F,null),             // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFE,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE
        (0x60,null), (10,null),   // PUSH1 10
        (0x05,null)]              // SDIV
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb]);
});
