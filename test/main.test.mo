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
    gasLimitTx = 2000;
    callee = "\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb";
    incomingEth = 0;
    dataTx = "\00\ee";
};

let dummyCallerState: T.CallerState = {
    balance = 50000;
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

await test("SDIV: 10 / -2", func() : async () {
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

await test("MOD: (2**160-5) % (2**80-127)", func() : async () {
    let context = await testOpCodes(
        [(0x69,null), // PUSH10 0xFFFFFFFFFFFFFFFFFF81
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0x81,null),
        (0x73,null),  // PUSH20 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFB,null), 
        (0x06,null)]  // MOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x3efc]);
});

await test("SMOD: 10 % -3", func() : async () {
    let context = await testOpCodes(
        [(0x7F,null),             // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFD,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD
        (0x60,null), (10,null),   // PUSH1 10
        (0x07,null)]              // SMOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

await test("SMOD: -10 % -3", func() : async () {
    let context = await testOpCodes(
        [(0x7F,null),             // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFD,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD
        (0x7F,null),             // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xF8,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8
        (0x07,null)]              // SMOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe]); // -2
});

await test("ADDMOD: ((2**256 - 1) + 20) % 8", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (8,null),   // PUSH1 8
        (0x60,null), (20,null),   // PUSH2 20
        (0x7F,null),              // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        (0x08,null)]              // ADDMOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});

await test("MULMOD: ((2**256-1) * (2**256-2)) % 12", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (12,null),  // PUSH1 12
        (0x7F,null),              // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFE,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE
        (0x7F,null),              // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        (0x09,null)]              // MULMOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [6]);
});

await test("EXP: 10 ** 20", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (20,null), // PUSH2 20
        (0x60,null), (10,null),  // PUSH2 10
        (0x0A,null)]             // EXP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [100_000_000_000_000_000_000]);
});

await test("EXP: 999 ** 2000", func() : async () {
    let context = await testOpCodes(
        [(0x61,null), (0x07,null), (0xD0,null), // PUSH2 0x07D0
        (0x61,null), (0x03,null), (0xE7,null),  // PUSH2 0x03E7
        (0x0A,null)]                            // EXP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x8c06c92f7b72b6bf4d280304f7b2545e50ce90e3b62a53cd97b7f849be413181]);
});

await test("EXP: 0xD3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD3 ** 0xD1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD1", func() : async () {
    let context = await testOpCodes(
        [(0x7F,null),              // PUSH32
        (0xD1,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xD1,null), // 0xD1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD1
        (0x7F,null),              // PUSH32
        (0xD3,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xD3,null), // 0xD3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD3
        (0x0A,null)]                            // EXP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x479dbf07c921bcfbea701ae69aa74de4c0efa9e82a4257f644b3480e1393a393]);
});

await test("SIGNEXTEND: 4 bytes, 0xFF123456", func() : async () {
    let context = await testOpCodes(
        [(0x63,null),                                       // PUSH4
        (0xFF,null), (0x12,null), (0x34,null), (0x56,null), // 0xFF123456
        (0x60,null), (3,null),                              // PUSH1 3
        (0x0B,null)]                                        // SIGNEXTEND
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffff123456]);
});

await test("LT: 1000 < 2000 (true)", func() : async () {
    let context = await testOpCodes(
        [(0x61,null), (0x07,null), (0xD0,null), // PUSH2 0x07D0
        (0x61,null), (0x03,null), (0xE8,null),  // PUSH2 0x03E8
        (0x10,null)]                            // LT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

await test("GT: 1000 > 2000 (false)", func() : async () {
    let context = await testOpCodes(
        [(0x61,null), (0x07,null), (0xD0,null), // PUSH2 0x07D0
        (0x61,null), (0x03,null), (0xE8,null),  // PUSH2 0x03E8
        (0x11,null)]                            // GT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

await test("SLT: 1000 < -2000 (false)", func() : async () {
    let context = await testOpCodes(
        [(0x7F,null),             // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0x38,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        (0x61,null),              // PUSH2
        (0x03,null), (0xE8,null), // 0x03E8
        (0x12,null)]              // SLT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

await test("SGT: 1000 > -2000 (true)", func() : async () {
    let context = await testOpCodes(
        [(0x7F,null),             // PUSH32
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0x38,null), // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        (0x61,null),              // PUSH2
        (0x03,null), (0xE8,null), // 0x03E8
        (0x13,null)]              // SGT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

await test("EQ: 1000 == 2000 (false)", func() : async () {
    let context = await testOpCodes(
        [(0x61,null), (0x07,null), (0xD0,null), // PUSH2 0x07D0
        (0x61,null), (0x03,null), (0xE8,null),  // PUSH2 0x03E8
        (0x14,null)]                            // EQ
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

await test("EQ: 1000 == 1000 (true)", func() : async () {
    let context = await testOpCodes(
        [(0x61,null), (0x03,null), (0xE8,null), // PUSH2 0x03E8
        (0x61,null), (0x03,null), (0xE8,null),  // PUSH2 0x03E8
        (0x14,null)]                            // EQ
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

await test("ISZERO: 1000 (false)", func() : async () {
    let context = await testOpCodes(
        [(0x61,null), (0x03,null), (0xE8,null), // PUSH2 0x03E8
        (0x15,null)]                            // ISZERO
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

await test("ISZERO: 0 (true)", func() : async () {
    let context = await testOpCodes(
        [(0x60,null), (0,null), // PUSH1 0
        (0x15,null)]            // ISZERO
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

await test("AND: 0xFF00FF & 0xF0F0F0", func() : async () {
    let context = await testOpCodes(
        [(0x62,null), (0xFF,null), (0x00,null), (0xFF,null), // PUSH3 0xFF00FF
        (0x62,null), (0xF0,null), (0xF0,null), (0xF0,null),  // PUSH3 0xF0F0F0
        (0x16,null)]                                         // AND
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xf000f0]);
});

await test("OR: 0xFF00FF | 0xF0F0F0", func() : async () {
    let context = await testOpCodes(
        [(0x62,null), (0xFF,null), (0x00,null), (0xFF,null), // PUSH3 0xFF00FF
        (0x62,null), (0xF0,null), (0xF0,null), (0xF0,null),  // PUSH3 0xF0F0F0
        (0x17,null)]                                         // OR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfff0ff]);
});

await test("XOR: 0xFF00FF ^ 0xF0F0F0", func() : async () {
    let context = await testOpCodes(
        [(0x62,null), (0xFF,null), (0x00,null), (0xFF,null), // PUSH3 0xFF00FF
        (0x62,null), (0xF0,null), (0xF0,null), (0xF0,null),  // PUSH3 0xF0F0F0
        (0x18,null)]                                         // XOR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x0ff00f]);
});

await test("NOT: ~ 0xF0F0F0", func() : async () {
    let context = await testOpCodes(
        [(0x62,null), (0xF0,null), (0xF0,null), (0xF0,null), // PUSH3 0xF0F0F0
        (0x19,null)]                                         // NOT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0f0f0f]);
});

await test("BYTE: 0xF1F2F3, offset = 30", func() : async () {
    let context = await testOpCodes(
        [(0x62,null), (0xF1,null), (0xF2,null), (0xF3,null), // PUSH3 0xF1F2F3
        (0x60,null), (30,null),                              // PUSH1 30
        (0x1A,null)]                                         // BYTE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xf2]);
});

await test("SHL: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : async () {
    let context = await testOpCodes(
        [(0x7F,null),             // PUSH32
        (0xFF,null), (0x00,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFE,null), (0x38,null), // 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        (0x60,null), (4,null),    // PUSH1 4
        (0x1B,null)]              // SHL
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xf00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe380]);
});

await test("SHR: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : async () {
    let context = await testOpCodes(
        [(0x7F,null),             // PUSH32
        (0xFF,null), (0x00,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFE,null), (0x38,null), // 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        (0x60,null), (4,null),    // PUSH1 4
        (0x1C,null)]              // SHR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xff00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe3]);
});

await test("SAR: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : async () {
    let context = await testOpCodes(
        [(0x7F,null),             // PUSH32
        (0xFF,null), (0x00,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null), (0xFF,null),
        (0xFE,null), (0x38,null), // 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        (0x60,null), (4,null),    // PUSH1 4
        (0x1D,null)]              // SAR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfff00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe3]);
});
