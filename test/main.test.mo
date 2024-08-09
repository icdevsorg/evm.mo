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
    incomingEth = 123;
    dataTx = "\01\23\45\67\89\ab\cd\ef";
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
    blockCoinbase = "\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc";
    chainId = 1;
};

let hash999999 = "\ac\dc\46\01\86\f7\23\3c\92\7e\7d\b2\dc\c7\03\c0\e5\00\b6\53\ca\82\27\3b\7b\fa\d8\04\5d\85\a4\70" : Blob;

func testOpCodes(code: [T.OpCode]) : async T.ExecutionContext {
    let context = await stateTransition(
        dummyTransaction,
        dummyCallerState,
        {
            balance = 12345;
            nonce = 0;
            code = code;
            storage = Trie.empty();
        }, // calleeState
        5, // gasPrice
        [(999_999, hash999999)], // blockHashes
        Trie.empty(), // accounts
        dummyBlockInfo
    );
    context;
};

// Basic Math and Bitwise Logic

Debug.print(">");
Debug.print(">");
Debug.print(">  Basic Math and Bitwise Logic");
Debug.print(">");
Debug.print(">");

// 01 ADD
await test("ADD: 1 + 2", func() : async () {
    let context = await testOpCodes(
        [0x60, 2, 0x60, 1, 0x01] // PUSH1 2 PUSH1 1 ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});

await test("ADD: (2**256-3) + 5", func() : async () {
    let context = await testOpCodes(
        [0x60, 5,    // PUSH1 5
        0x7F,        // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFD, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD
        0x01]       // ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [2]);
});

await test("ADD: stack should underflow", func() : async () {
    let context = await testOpCodes(
        [0x60, 2, 0x01] // PUSH1 2 ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == []);
});

// 02 MUL
await test("MUL: 1000 * 2000", func() : async () {
    let context = await testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x02]              // MUL
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [2_000_000]);
});

await test("MUL: (2**80-6) * (2**160-6)", func() : async () {
    let context = await testOpCodes(
        [0x73,             // PUSH20 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFA
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFA,
        0x69,             // PUSH10 0xFFFFFFFFFFFFFFFFFFFA
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFA, 
        0x02]             // MUL
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfffffffffffffffffff9fffffffffffffffffffa00000000000000000024]);
});

// 03 SUB
await test("SUB: 8 - 20", func() : async () {
    let context = await testOpCodes(
        [0x60, 20, 0x60, 8, 0x03] // PUSH1 20 PUSH1 8 SUB
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [(2**256 - 12)]);
});

// 04 DIV
await test("DIV: 20 / 3", func() : async () {
    let context = await testOpCodes(
        [0x60, 3, 0x60, 20, 0x04] // PUSH1 3 PUSH1 20 DIV
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [6]);
});

await test("DIV: 4 / 0", func() : async () {
    let context = await testOpCodes(
        [0x5F, 0x60, 4, 0x04] // PUSH0 PUSH1 4 DIV
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// 05 SDIV
await test("SDIV: 10 / -2", func() : async () {
    let context = await testOpCodes(
        [0x7F,      // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFE, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE
        0x60, 10,   // PUSH1 10
        0x05]       // SDIV
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb]);
});

// 06 MOD
await test("MOD: (2**160-5) % (2**80-127)", func() : async () {
    let context = await testOpCodes(
        [0x69,         // PUSH10 0xFFFFFFFFFFFFFFFFFF81
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0x81,
        0x73,          // PUSH20 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFB, 
        0x06]          // MOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x3efc]);
});

// 07 SMOD
await test("SMOD: 10 % -3", func() : async () {
    let context = await testOpCodes(
        [0x7F,      // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFD, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD
        0x60, 10,   // PUSH1 10
        0x07]       // SMOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

await test("SMOD: -10 % -3", func() : async () {
    let context = await testOpCodes(
        [0x7F,      // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFD, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD
        0x7F,       // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xF8, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8
        0x07]       // SMOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe]); // -2
});

// 08 ADDMOD
await test("ADDMOD: ((2**256 - 1) + 20) % 8", func() : async () {
    let context = await testOpCodes(
        [0x60, 8,   // PUSH1 8
        0x60, 20,   // PUSH2 20
        0x7F,       // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        0x08]       // ADDMOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});

// 09 MULMOD
await test("MULMOD: ((2**256-1) * (2**256-2)) % 12", func() : async () {
    let context = await testOpCodes(
        [0x60, 12,  // PUSH1 12
        0x7F,       // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFE, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE
        0x7F,       // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        0x09]       // MULMOD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [6]);
});

// 0A EXP
await test("EXP: 10 ** 20", func() : async () {
    let context = await testOpCodes(
        [0x60, 20, // PUSH2 20
        0x60, 10,  // PUSH2 10
        0x0A]      // EXP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [100_000_000_000_000_000_000]);
});

await test("EXP: 999 ** 2000", func() : async () {
    let context = await testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE7,  // PUSH2 0x03E7
        0x0A]              // EXP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x8c06c92f7b72b6bf4d280304f7b2545e50ce90e3b62a53cd97b7f849be413181]);
});

await test("EXP: 0xD3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD3 ** 0xD1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD1", func() : async () {
    let context = await testOpCodes(
        [0x7F,      // PUSH32
        0xD1, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xD1, // 0xD1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD1
        0x7F,       // PUSH32
        0xD3, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xD3, // 0xD3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD3
        0x0A]       // EXP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x479dbf07c921bcfbea701ae69aa74de4c0efa9e82a4257f644b3480e1393a393]);
});

// 0B SIGNEXTEND
await test("SIGNEXTEND: 4 bytes, 0xFF123456", func() : async () {
    let context = await testOpCodes(
        [0x63,                  // PUSH4
        0xFF, 0x12, 0x34, 0x56, // 0xFF123456
        0x60, 3,                // PUSH1 3
        0x0B]                   // SIGNEXTEND
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffff123456]);
});

// 10 LT
await test("LT: 1000 < 2000 (true)", func() : async () {
    let context = await testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x10]              // LT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 11 GT
await test("GT: 1000 > 2000 (false)", func() : async () {
    let context = await testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x11]              // GT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// 12 SLT
await test("SLT: 1000 < -2000 (false)", func() : async () {
    let context = await testOpCodes(
        [0x7F,      // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0x38, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        0x61,       // PUSH2
        0x03, 0xE8, // 0x03E8
        0x12]       // SLT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// 13 SGT
await test("SGT: 1000 > -2000 (true)", func() : async () {
    let context = await testOpCodes(
        [0x7F,       // PUSH32
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0x38, // 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        0x61,       // PUSH2
        0x03, 0xE8, // 0x03E8
        0x13]       // SGT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 14 EQ
await test("EQ: 1000 == 2000 (false)", func() : async () {
    let context = await testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x14]              // EQ
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

await test("EQ: 1000 == 1000 (true)", func() : async () {
    let context = await testOpCodes(
        [0x61, 0x03, 0xE8, // PUSH2 0x03E8
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x14]              // EQ
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 15 ISZERO
await test("ISZERO: 1000 (false)", func() : async () {
    let context = await testOpCodes(
        [0x61, 0x03, 0xE8, // PUSH2 0x03E8
        0x15]              // ISZERO
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

await test("ISZERO: 0 (true)", func() : async () {
    let context = await testOpCodes(
        [0x60, 0, // PUSH1 0
        0x15]     // ISZERO
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 16 AND
await test("AND: 0xFF00FF & 0xF0F0F0", func() : async () {
    let context = await testOpCodes(
        [0x62, 0xFF, 0x00, 0xFF, // PUSH3 0xFF00FF
        0x62, 0xF0, 0xF0, 0xF0,  // PUSH3 0xF0F0F0
        0x16]                    // AND
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xf000f0]);
});

// 17 OR
await test("OR: 0xFF00FF | 0xF0F0F0", func() : async () {
    let context = await testOpCodes(
        [0x62, 0xFF, 0x00, 0xFF, // PUSH3 0xFF00FF
        0x62, 0xF0, 0xF0, 0xF0,  // PUSH3 0xF0F0F0
        0x17]                    // OR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfff0ff]);
});

// 18 XOR
await test("XOR: 0xFF00FF ^ 0xF0F0F0", func() : async () {
    let context = await testOpCodes(
        [0x62, 0xFF, 0x00, 0xFF, // PUSH3 0xFF00FF
        0x62, 0xF0, 0xF0, 0xF0,  // PUSH3 0xF0F0F0
        0x18]                    // XOR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x0ff00f]);
});

// 19 NOT
await test("NOT: ~ 0xF0F0F0", func() : async () {
    let context = await testOpCodes(
        [0x62, 0xF0, 0xF0, 0xF0, // PUSH3 0xF0F0F0
        0x19]                    // NOT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0f0f0f]);
});

// 1A BYTE
await test("BYTE: 0xF1F2F3, offset = 30", func() : async () {
    let context = await testOpCodes(
        [0x62, 0xF1, 0xF2, 0xF3, // PUSH3 0xF1F2F3
        0x60, 30,                // PUSH1 30
        0x1A]                    // BYTE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xf2]);
});

// 1B SHL
await test("SHL: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : async () {
    let context = await testOpCodes(
        [0x7F,             // PUSH32
        0xFF, 0x00, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFE, 0x38,        // 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        0x60, 4,           // PUSH1 4
        0x1B]              // SHL
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xf00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe380]);
});

// 1C SHR
await test("SHR: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : async () {
    let context = await testOpCodes(
        [0x7F,             // PUSH32
        0xFF, 0x00, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFE, 0x38,        // 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        0x60, 4,           // PUSH1 4
        0x1C]              // SHR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xff00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe3]);
});

// 1D SAR
await test("SAR: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : async () {
    let context = await testOpCodes(
        [0x7F,             // PUSH32
        0xFF, 0x00, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFE, 0x38,        // 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38      
        0x60, 4,           // PUSH1 4
        0x1D]              // SAR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfff00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe3]);
});

// Environmental Information and Block Information

Debug.print(">");
Debug.print(">");
Debug.print(">  Environmental Information and Block Information");
Debug.print(">");
Debug.print(">");

// 30 ADDRESS
await test("ADDRESS", func() : async () {
    let context = await testOpCodes(
        [0x30]    // ADDRESS
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb]);
});

// 31 BALANCE
await test("BALANCE: 0x00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb", func() : async () {
    let context = await testOpCodes(
        [0x73,                          // PUSH20
        0x00, 0xbb, 0x00, 0xbb, 0x00,   // 00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb
        0xbb, 0x00, 0xbb, 0x00, 0xbb,
        0x00, 0xbb, 0x00, 0xbb, 0x00,
        0xbb, 0x00, 0xbb, 0x00, 0xbb,
        0x31]                           // BALANCE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [12345 + 123]);
});

// 32 ORIGIN
await test("ORIGIN", func() : async () {
    let context = await testOpCodes(
        [0x32]    // ORIGIN
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa]);
});

// 33 CALLER
await test("CALLER", func() : async () {
    let context = await testOpCodes(
        [0x33]    // CALLER
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa]);
});

// 34 CALLVALUE
await test("CALLVALUE", func() : async () {
    let context = await testOpCodes(
        [0x34]    // CALLVALUE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [123]);
});

// 35 CALLDATALOAD
await test("CALLDATALOAD: 4", func() : async () {
    let context = await testOpCodes(
        [0x60, 3,  // PUSH1 3
        0x35]      // CALLDATALOAD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x6789abcdef000000000000000000000000000000000000000000000000000000]);
});

// 36 CALLDATASIZE
await test("CALLDATASIZE", func() : async () {
    let context = await testOpCodes(
        [0x36]    // CALLDATASIZE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [8]);
});

// 37 CALLDATACOPY
await test("CALLDATACOPY: destOffset = 0, offset = 3, size = 5", func() : async () {
    let context = await testOpCodes(
        [0x60, 5,  // PUSH1 5
        0x60, 3,   // PUSH1 3
        0x5F,      // PUSH0
        0x37]      // CALLDATACOPY
    );
    let result = context.memory;
    Debug.print(debug_show(result));
    assert(result == [0x67, 0x89, 0xab, 0xcd, 0xef]);
});

// 38 CODESIZE
await test("CODESIZE", func() : async () {
    let context = await testOpCodes(
        [0x38]    // CODESIZE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 39 CODECOPY
await test("CODECOPY: destOffset = 0, offset = 3, size = 5", func() : async () {
    let context = await testOpCodes(
        [0x69,                        // PUSH10
        0x01, 0x23, 0x45, 0x67, 0x89,
        0xab, 0xcd, 0xef, 0x01, 0x23, // 0x012345689abcdef0123
        0x60, 5,                      // PUSH1 5
        0x60, 3,                      // PUSH1 3
        0x5F,                         // PUSH0
        0x39]                         // CODECOPY
    );
    let result = context.memory;
    Debug.print(debug_show(result));
    assert(result == [0x45, 0x67, 0x89, 0xab, 0xcd]);
});

// 3A GASPRICE
await test("GASPRICE", func() : async () {
    let context = await testOpCodes(
        [0x3a]    // GASPRICE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [5]);
});

// 3B EXTCODESIZE
await test("EXTCODESIZE: 0x00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb", func() : async () {
    let context = await testOpCodes(
        [0x73,                          // PUSH20
        0x00, 0xbb, 0x00, 0xbb, 0x00,   // 00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb
        0xbb, 0x00, 0xbb, 0x00, 0xbb,
        0x00, 0xbb, 0x00, 0xbb, 0x00,
        0xbb, 0x00, 0xbb, 0x00, 0xbb,
        0x3b]                           // EXTCODESIZE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [22]);
});

await test("EXTCODESIZE: 0x00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa", func() : async () {
    let context = await testOpCodes(
        [0x73,                          // PUSH20
        0x00, 0xaa, 0x00, 0xaa, 0x00,   // 00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa
        0xaa, 0x00, 0xaa, 0x00, 0xaa,
        0x00, 0xaa, 0x00, 0xaa, 0x00,
        0xaa, 0x00, 0xaa, 0x00, 0xaa,
        0x3b]                           // EXTCODESIZE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// 3C EXTCODECOPY
await test(
    "EXTCODECOPY: address: 0x00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb, destOffset = 0, offset = 3, size = 5",
    func() : async () {
    let context = await testOpCodes(
        [0x69,                        // PUSH10
        0x01, 0x23, 0x45, 0x67, 0x89, // 0x012345689abcdef0123
        0xab, 0xcd, 0xef, 0x01, 0x23,
        0x60, 5,                      // PUSH1 5
        0x60, 3,                      // PUSH1 3
        0x5F,                         // PUSH0
        0x73,                         // PUSH20
        0x00, 0xbb, 0x00, 0xbb, 0x00, // 00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb
        0xbb, 0x00, 0xbb, 0x00, 0xbb,
        0x00, 0xbb, 0x00, 0xbb, 0x00,
        0xbb, 0x00, 0xbb, 0x00, 0xbb,
        0x3c]                         // EXTCODECOPY
    );
    let result = context.memory;
    Debug.print(debug_show(result));
    assert(result == [0x45, 0x67, 0x89, 0xab, 0xcd]);
});

// 3D RETURNDATASIZE
// TODO - requires Execution and System Operations functions to be in place

// 3E RETURNDATACOPY
// TODO - requires Execution and System Operations functions to be in place

// 3F EXTCODEHASH
await test("EXTCODEHASH: 0x00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa", func() : async () {
    let context = await testOpCodes(
        [0x73,                          // PUSH20
        0x00, 0xaa, 0x00, 0xaa, 0x00,   // 00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa
        0xaa, 0x00, 0xaa, 0x00, 0xaa,
        0x00, 0xaa, 0x00, 0xaa, 0x00,
        0xaa, 0x00, 0xaa, 0x00, 0xaa,
        0x3f]                           // EXTCODEHASH
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    // should return the empty hash
    assert(result == [0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]);
});

// 40 BLOCKHASH
await test("BLOCKHASH: 999999", func() : async () {
    let context = await testOpCodes(
        [0x62,               // PUSH3
        0x0f, 0x42, 0x3f,    // 0f423f
        0x40]                // BLOCKHASH
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xacdc460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470]);
});

// 41 COINBASE
await test("CALLER", func() : async () {
    let context = await testOpCodes(
        [0x41]    // COINBASE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x00cc00cc00cc00cc00cc00cc00cc00cc00cc00cc]);
});

// 42 TIMESTAMP
await test("TIMESTAMP", func() : async () {
    let context = await testOpCodes(
        [0x42]    // TIMESTAMP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1_500_000_000]);
});

// 43 NUMBER
await test("NUMBER", func() : async () {
    let context = await testOpCodes(
        [0x43]    // NUMBER
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1_000_000]);
});

// 44 DIFFICULTY
await test("DIFFICULTY", func() : async () {
    let context = await testOpCodes(
        [0x44]    // DIFFICULTY
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1_000_000_000_000]);
});

// 45 GASLIMIT
await test("CALLER", func() : async () {
    let context = await testOpCodes(
        [0x45]    // GASLIMIT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [30_000_000]);
});

// 46 CHAINID
await test("CHAINID", func() : async () {
    let context = await testOpCodes(
        [0x46]    // CHAINID
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 47 SELFBALANCE
await test("SELFBALANCE", func() : async () {
    let context = await testOpCodes(
        [0x47]    // SELFBALANCE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [50000 - 2000 * 5 - 123]);
});

// 48 BASEFEE
// Base fee has not been included in the defined execution context.
await test("BASEFEE", func() : async () {
    let context = await testOpCodes(
        [0x48]    // BASEFEE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});
