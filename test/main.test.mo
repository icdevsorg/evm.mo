import { test; skip } "mo:test"; // see https://mops.one/test

import { stateTransition; engine } "../src/evm_mo_backend/main";

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
    gasLimitTx = 100_000;
    callee = "\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb";
    incomingEth = 123;
    dataTx = "\01\23\45\67\89\ab\cd\ef";
};

let dummyCallerState: T.CallerState = {
    balance = 550_000;
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

func testOpCodes(code: [T.OpCode]) : T.ExecutionContext {
    let context = stateTransition(
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
        dummyBlockInfo,
        engine()

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
test("ADD: 1 + 2", func() : () {
    let context = testOpCodes(
        [0x60, 2, 0x60, 1, 0x01] // PUSH1 2 PUSH1 1 ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});

test("ADD: (2**256-3) + 5", func() : () {
    let context = testOpCodes(
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

test("ADD: stack should underflow", func() : () {
    let context = testOpCodes(
        [0x60, 2, 0x01] // PUSH1 2 ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == []);
});

// 02 MUL
test("MUL: 1000 * 2000", func() : () {
    let context = testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x02]              // MUL
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [2_000_000]);
});

test("MUL: (2**80-6) * (2**160-6)", func() : () {
    let context = testOpCodes(
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
test("SUB: 8 - 20", func() : () {
    let context = testOpCodes(
        [0x60, 20, 0x60, 8, 0x03] // PUSH1 20 PUSH1 8 SUB
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [(2**256 - 12)]);
});

// 04 DIV
test("DIV: 20 / 3", func() : () {
    let context = testOpCodes(
        [0x60, 3, 0x60, 20, 0x04] // PUSH1 3 PUSH1 20 DIV
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [6]);
});

test("DIV: 4 / 0", func() : () {
    let context = testOpCodes(
        [0x5F, 0x60, 4, 0x04] // PUSH0 PUSH1 4 DIV
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// 05 SDIV
test("SDIV: 10 / -2", func() : () {
    let context = testOpCodes(
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
test("MOD: (2**160-5) % (2**80-127)", func() : () {
    let context = testOpCodes(
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
test("SMOD: 10 % -3", func() : () {
    let context = testOpCodes(
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

test("SMOD: -10 % -3", func() : () {
    let context = testOpCodes(
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
test("ADDMOD: ((2**256 - 1) + 20) % 8", func() : () {
    let context = testOpCodes(
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
test("MULMOD: ((2**256-1) * (2**256-2)) % 12", func() : () {
    let context = testOpCodes(
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
test("EXP: 10 ** 20", func() : () {
    let context = testOpCodes(
        [0x60, 20, // PUSH2 20
        0x60, 10,  // PUSH2 10
        0x0A]      // EXP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [100_000_000_000_000_000_000]);
});

test("EXP: 999 ** 2000", func() : () {
    let context = testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE7,  // PUSH2 0x03E7
        0x0A]              // EXP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x8c06c92f7b72b6bf4d280304f7b2545e50ce90e3b62a53cd97b7f849be413181]);
});

test("EXP: 0xD3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD3 ** 0xD1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD1", func() : () {
    let context = testOpCodes(
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
test("SIGNEXTEND: 4 bytes, 0xFF123456", func() : () {
    let context = testOpCodes(
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
test("LT: 1000 < 2000 (true)", func() : () {
    let context = testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x10]              // LT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 11 GT
test("GT: 1000 > 2000 (false)", func() : () {
    let context = testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x11]              // GT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// 12 SLT
test("SLT: 1000 < -2000 (false)", func() : () {
    let context = testOpCodes(
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
test("SGT: 1000 > -2000 (true)", func() : () {
    let context = testOpCodes(
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
test("EQ: 1000 == 2000 (false)", func() : () {
    let context = testOpCodes(
        [0x61, 0x07, 0xD0, // PUSH2 0x07D0
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x14]              // EQ
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

test("EQ: 1000 == 1000 (true)", func() : () {
    let context = testOpCodes(
        [0x61, 0x03, 0xE8, // PUSH2 0x03E8
        0x61, 0x03, 0xE8,  // PUSH2 0x03E8
        0x14]              // EQ
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 15 ISZERO
test("ISZERO: 1000 (false)", func() : () {
    let context = testOpCodes(
        [0x61, 0x03, 0xE8, // PUSH2 0x03E8
        0x15]              // ISZERO
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

test("ISZERO: 0 (true)", func() : () {
    let context = testOpCodes(
        [0x60, 0, // PUSH1 0
        0x15]     // ISZERO
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 16 AND
test("AND: 0xFF00FF & 0xF0F0F0", func() : () {
    let context = testOpCodes(
        [0x62, 0xFF, 0x00, 0xFF, // PUSH3 0xFF00FF
        0x62, 0xF0, 0xF0, 0xF0,  // PUSH3 0xF0F0F0
        0x16]                    // AND
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xf000f0]);
});

// 17 OR
test("OR: 0xFF00FF | 0xF0F0F0", func() : () {
    let context = testOpCodes(
        [0x62, 0xFF, 0x00, 0xFF, // PUSH3 0xFF00FF
        0x62, 0xF0, 0xF0, 0xF0,  // PUSH3 0xF0F0F0
        0x17]                    // OR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xfff0ff]);
});

// 18 XOR
test("XOR: 0xFF00FF ^ 0xF0F0F0", func() : () {
    let context = testOpCodes(
        [0x62, 0xFF, 0x00, 0xFF, // PUSH3 0xFF00FF
        0x62, 0xF0, 0xF0, 0xF0,  // PUSH3 0xF0F0F0
        0x18]                    // XOR
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x0ff00f]);
});

// 19 NOT
test("NOT: ~ 0xF0F0F0", func() : () {
    let context = testOpCodes(
        [0x62, 0xF0, 0xF0, 0xF0, // PUSH3 0xF0F0F0
        0x19]                    // NOT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0f0f0f]);
});

// 1A BYTE
test("BYTE: 0xF1F2F3, offset = 30", func() : () {
    let context = testOpCodes(
        [0x62, 0xF1, 0xF2, 0xF3, // PUSH3 0xF1F2F3
        0x60, 30,                // PUSH1 30
        0x1A]                    // BYTE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xf2]);
});

// 1B SHL
test("SHL: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : () {
    let context = testOpCodes(
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
test("SHR: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : () {
    let context = testOpCodes(
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
test("SAR: 0xFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE38, shift = 4", func() : () {
    let context = testOpCodes(
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
test("ADDRESS", func() : () {
    let context = testOpCodes(
        [0x30]    // ADDRESS
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb]);
});

// 31 BALANCE
test("BALANCE: 0x00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb", func() : () {
    let context = testOpCodes(
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
test("ORIGIN", func() : () {
    let context = testOpCodes(
        [0x32]    // ORIGIN
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa]);
});

// 33 CALLER
test("CALLER", func() : () {
    let context = testOpCodes(
        [0x33]    // CALLER
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa]);
});

// 34 CALLVALUE
test("CALLVALUE", func() : () {
    let context = testOpCodes(
        [0x34]    // CALLVALUE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [123]);
});

// 35 CALLDATALOAD
test("CALLDATALOAD: 4", func() : () {
    let context = testOpCodes(
        [0x60, 3,  // PUSH1 3
        0x35]      // CALLDATALOAD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x6789abcdef000000000000000000000000000000000000000000000000000000]);
});

// 36 CALLDATASIZE
test("CALLDATASIZE", func() : () {
    let context = testOpCodes(
        [0x36]    // CALLDATASIZE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [8]);
});

// 37 CALLDATACOPY
test("CALLDATACOPY: destOffset = 0, offset = 3, size = 5", func() : () {
    let context = testOpCodes(
        [0x60, 5,  // PUSH1 5
        0x60, 3,   // PUSH1 3
        0x5F,      // PUSH0
        0x37]      // CALLDATACOPY
    );
    let result = context.memory;
    Debug.print(debug_show(result));
    assert(result == [0x67, 0x89, 0xab, 0xcd, 0xef, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
});

// 38 CODESIZE
test("CODESIZE", func() : () {
    let context = testOpCodes(
        [0x38]    // CODESIZE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 39 CODECOPY
test("CODECOPY: destOffset = 0, offset = 3, size = 5", func() : () {
    let context = testOpCodes(
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
    assert(result == [0x45, 0x67, 0x89, 0xab, 0xcd, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
});

// 3A GASPRICE
test("GASPRICE", func() : () {
    let context = testOpCodes(
        [0x3a]    // GASPRICE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [5]);
});

// 3B EXTCODESIZE
test("EXTCODESIZE: 0x00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb", func() : () {
    let context = testOpCodes(
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

test("EXTCODESIZE: 0x00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa", func() : () {
    let context = testOpCodes(
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
test(
    "EXTCODECOPY: address: 0x00bb00bb00bb00bb00bb00bb00bb00bb00bb00bb, destOffset = 0, offset = 3, size = 5",
    func() : () {
    let context = testOpCodes(
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
    assert(result == [0x45, 0x67, 0x89, 0xab, 0xcd, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
});

// 3D RETURNDATASIZE
// TODO - requires Execution and System Operations functions to be in place

// 3E RETURNDATACOPY
// TODO - requires Execution and System Operations functions to be in place

// 3F EXTCODEHASH
test("EXTCODEHASH: 0x00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa", func() : () {
    let context = testOpCodes(
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
test("BLOCKHASH: 999999", func() : () {
    let context = testOpCodes(
        [0x62,               // PUSH3
        0x0f, 0x42, 0x3f,    // 0f423f
        0x40]                // BLOCKHASH
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0xacdc460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470]);
});

// 41 COINBASE
test("CALLER", func() : () {
    let context = testOpCodes(
        [0x41]    // COINBASE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x00cc00cc00cc00cc00cc00cc00cc00cc00cc00cc]);
});

// 42 TIMESTAMP
test("TIMESTAMP", func() : () {
    let context = testOpCodes(
        [0x42]    // TIMESTAMP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1_500_000_000]);
});

// 43 NUMBER
test("NUMBER", func() : () {
    let context = testOpCodes(
        [0x43]    // NUMBER
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1_000_000]);
});

// 44 DIFFICULTY
test("DIFFICULTY", func() : () {
    let context = testOpCodes(
        [0x44]    // DIFFICULTY
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1_000_000_000_000]);
});

// 45 GASLIMIT
test("CALLER", func() : () {
    let context = testOpCodes(
        [0x45]    // GASLIMIT
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [30_000_000]);
});

// 46 CHAINID
test("CHAINID", func() : () {
    let context = testOpCodes(
        [0x46]    // CHAINID
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [1]);
});

// 47 SELFBALANCE
test("SELFBALANCE", func() : () {
    let context = testOpCodes(
        [0x47]    // SELFBALANCE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [550000 - 100000 * 5 - 123]);
});

// 48 BASEFEE
// Base fee has not been included in the defined execution context.
test("BASEFEE", func() : () {
    let context = testOpCodes(
        [0x48]    // BASEFEE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

Debug.print(">");
Debug.print(">");
Debug.print(">  Memory Operations");
Debug.print(">");
Debug.print(">");

// 50 POP
test("POP", func() : () {
    let context = testOpCodes(
        [0x62,               // PUSH3
        0x12, 0x34, 0x56,    // 0x123456
        0x62,                // PUSH3
        0x78, 0x90, 0xab,    // 0x7890ab
        0x50]                // POP
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x123456]);
});

// 51 MLOAD
test("MLOAD: 0", func() : () {
    let context = testOpCodes(
        [0x62,               // PUSH3
        0x12, 0x34, 0x56,    // 0x123456
        0x60, 0,             // PUSH1 0
        0x52,                // MSTORE
        0x60, 0,             // PUSH1 0
        0x51]                // MLOAD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x123456]);
});

// 52 MSTORE
test("MSTORE: 0, 0x123456", func() : () {
    let context = testOpCodes(
        [0x62,               // PUSH3
        0x12, 0x34, 0x56,    // 0x123456
        0x60, 0,             // PUSH1 0
        0x52]                // MSTORE
    );
    let result = context.memory;
    Debug.print(debug_show(result));
    assert(result == [0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0x12, 0x34, 0x56]);
});

// 53 MSTORE8
test("MSTORE8: 5, 0xff", func() : () {
    let context = testOpCodes(
        [0x60, 0xff,  // PUSH1 0xff
        0x60, 5,      // PUSH1 5
        0x53]         // MSTORE8
    );
    let result = context.memory;
    Debug.print(debug_show(result));
    assert(result == [0, 0, 0, 0, 0, 0xff, 0, 0,
                     0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0, 0, 0]);
});

// 54 SLOAD &
// 55 SSTORE
test("SSTORE: (42, 0x123456); SLOAD", func() : () {
    let context = testOpCodes(
        [0x62,               // PUSH3
        0x12, 0x34, 0x56,    // 0x123456
        0x60, 42,            // PUSH1 42
        0x55,                // SSTORE
        0x60, 42,            // PUSH1 42
        0x54]                // SLOAD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x123456]);
});

// 56 JUMP
test("JUMP: 10", func() : () {
    let context = testOpCodes(
        [0x60, 10,              // PUSH1 10
        0x56,                   // JUMP
        0x50, 0x50, 0x50, 0x50, // POP (x7 as dummy code)
        0x50, 0x50, 0x50,
        0x5b,                   // JUMPDEST
        0x60, 2,                // PUSH1 2
        0x60, 1,                // PUSH1 1
        0x01]                   // ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});

// 57 JUMPI
test("JUMPI: 12, 1", func() : () {
    let context = testOpCodes(
        [0x60, 1,               // PUSH1 1
        0x60, 12,               // PUSH1 11
        0x57,                   // JUMPI
        0x50, 0x50, 0x50, 0x50, // POP (x7 as dummy code)
        0x50, 0x50, 0x50,
        0x5b,                   // JUMPDEST
        0x60, 2,                // PUSH1 2
        0x60, 1,                // PUSH1 1
        0x01]                   // ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});

// 58 PC
test("PC", func() : () {
    let context = testOpCodes(
        [0x60, 2,               // PUSH1 2
        0x60, 1,                // PUSH1 1
        0x01,                   // ADD
        0x58]                   // PC
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3, 5]);
});

// 59 MSIZE
test("MSIZE", func() : () {
    let context = testOpCodes(
        [0x62,               // PUSH3
        0x12, 0x34, 0x56,    // 0x123456
        0x60, 2,             // PUSH1 2
        0x52,                // MSTORE
        0x59]                // MSIZE
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [64]);
});

// 5A GAS
test("GAS", func() : () {
    let context = testOpCodes(
        [0x5f,   // PUSH0
        0x5a]    // GAS
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0, 100000 - 2 - 2]);
});

// 5B JUMPDEST
// Tested in 56 & 57 above
test("JUMPDEST", func() : () {
    let context = testOpCodes(
        [0x5b,    // JUMPDEST
        0x5f]     // PUSH0
    );
    Debug.print("JUMPDEST was tested with JUMP and JUMPI above.");
    Debug.print("This simply tests that the opcode by itself runs without error.");
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// Dynamic gas cost & gas refund mechanism
test("Dynamic gas cost & gas refund", func() : () {
    let context = testOpCodes(
        [0x62,               // PUSH3
        0x12, 0x34, 0x56,    // 0x123456
        0x60, 42,            // PUSH1 42
        0x55,                // SSTORE
        0x62,                // PUSH3
        0x12, 0x34, 0x56,    // 0x123456
        0x60, 42,            // PUSH1 42
        0x55,                // SSTORE
        0x60, 0,             // PUSH1 0
        0x60, 42,            // PUSH1 42
        0x55]                // SSTORE
    );
    let expectedGasCost = 3 + 3 + 20000 + 3 + 3 + 100 + 3 + 3 + 100;
    var expectedGasRefund = 0 + 0 + 19900;
    if (expectedGasRefund > expectedGasCost / 5) {
      expectedGasRefund := expectedGasCost / 5;
    };
    let gasSpent = context.currentGas - context.totalGas;
    Debug.print(debug_show("Expected gas cost", expectedGasCost));
    Debug.print(debug_show(("Expected gas refund", expectedGasRefund)));
    Debug.print(debug_show(("Gas spent", gasSpent)));
    Debug.print(debug_show(("Gas refund", context.gasRefund)));
    assert((expectedGasCost == gasSpent) and (expectedGasRefund == context.gasRefund));
});

// Push Operations, Duplication Operations, Exchange Operations

Debug.print(">");
Debug.print(">");
Debug.print(">  Push, Duplication and Exchange Operations");
Debug.print(">");
Debug.print(">");

// 5F PUSH0
test("PUSH0", func() : () {
    let context = testOpCodes(
        [0x5f]  // PUSH0
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// 5F-7F PUSH various
test("PUSH0, PUSH1, PUSH2, PUSH6, PUSH12, PUSH32", func() : () {
    let context = testOpCodes(
        [0x5f,                  // PUSH0
        0x60, 1,                // PUSH1 1
        0x61, 2, 0,             // PUSH2 0x0200
        0x65, 3, 0, 0, 0, 0, 0, // PUSH6 0x030000000000
        0x6b,                   // PUSH12
        4, 0, 0, 0, 0, 0,       // 0x040000000000000000000000
        0, 0, 0, 0, 0, 0,
        0x7f,                   // PUSH32
        5, 0, 0, 0, 0, 0, 0, 0, // 0x0500000000000000000000000000000000000000000000000000000000000000
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0]
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0, 1, 0x0200, 0x030000000000, 0x040000000000000000000000,
    0x0500000000000000000000000000000000000000000000000000000000000000]);
});

// 80 DUP1
test("DUP1", func() : () {
    let context = testOpCodes(
        [0x5f,                  // PUSH0
        0x60, 1,                // PUSH1 1
        0x61, 2, 0,             // PUSH2 0x0200
        0x65, 3, 0, 0, 0, 0, 0, // PUSH6 0x030000000000
        0x6b,                   // PUSH12
        4, 0, 0, 0, 0, 0,       // 0x040000000000000000000000
        0, 0, 0, 0, 0, 0,
        0x7f,                   // PUSH32
        5, 0, 0, 0, 0, 0, 0, 0, // 0x0500000000000000000000000000000000000000000000000000000000000000
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0x80]                     // DUP1
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0, 1, 0x0200, 0x030000000000, 0x040000000000000000000000,
    0x0500000000000000000000000000000000000000000000000000000000000000,
    0x0500000000000000000000000000000000000000000000000000000000000000]);
});

// 83 DUP4
test("DUP4", func() : () {
    let context = testOpCodes(
        [0x5f,                  // PUSH0
        0x60, 1,                // PUSH1 1
        0x61, 2, 0,             // PUSH2 0x0200
        0x65, 3, 0, 0, 0, 0, 0, // PUSH6 0x030000000000
        0x6b,                   // PUSH12
        4, 0, 0, 0, 0, 0,       // 0x040000000000000000000000
        0, 0, 0, 0, 0, 0,
        0x7f,                   // PUSH32
        5, 0, 0, 0, 0, 0, 0, 0, // 0x0500000000000000000000000000000000000000000000000000000000000000
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0x83]                     // DUP4
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0, 1, 0x0200, 0x030000000000, 0x040000000000000000000000,
    0x0500000000000000000000000000000000000000000000000000000000000000, 0x0200]);
});

// 87 DUP8
test("DUP8 (should throw error)", func() : () {
    let context = testOpCodes(
        [0x5f,                  // PUSH0
        0x60, 1,                // PUSH1 1
        0x61, 2, 0,             // PUSH2 0x0200
        0x65, 3, 0, 0, 0, 0, 0, // PUSH6 0x030000000000
        0x6b,                   // PUSH12
        4, 0, 0, 0, 0, 0,       // 0x040000000000000000000000
        0, 0, 0, 0, 0, 0,
        0x7f,                   // PUSH32
        5, 0, 0, 0, 0, 0, 0, 0, // 0x0500000000000000000000000000000000000000000000000000000000000000
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0x87]                     // DUP7
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == []);
});

// 8F DUP16
test("DUP1", func() : () {
    let context = testOpCodes(
        [0x60, 16, // PUSH1 16
        0x60, 15,  // PUSH1 15
        0x60, 14,  // PUSH1 14
        0x60, 13,  // PUSH1 13
        0x60, 12,  // PUSH1 12
        0x60, 11,  // PUSH1 11
        0x60, 10,  // PUSH1 10
        0x60, 9,   // PUSH1 9
        0x60, 8,   // PUSH1 8
        0x60, 7,   // PUSH1 7
        0x60, 6,   // PUSH1 6
        0x60, 5,   // PUSH1 5
        0x60, 4,   // PUSH1 4
        0x60, 3,   // PUSH1 3
        0x60, 2,   // PUSH1 2
        0x60, 1,   // PUSH1 1
        0x8f]      // DUP16
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 16]);
});

// 90 SWAP1
test("SWAP1", func() : () {
    let context = testOpCodes(
        [0x60, 16, // PUSH1 16
        0x60, 15,  // PUSH1 15
        0x60, 14,  // PUSH1 14
        0x60, 13,  // PUSH1 13
        0x60, 12,  // PUSH1 12
        0x60, 11,  // PUSH1 11
        0x60, 10,  // PUSH1 10
        0x60, 9,   // PUSH1 9
        0x60, 8,   // PUSH1 8
        0x60, 7,   // PUSH1 7
        0x60, 6,   // PUSH1 6
        0x60, 5,   // PUSH1 5
        0x60, 4,   // PUSH1 4
        0x60, 3,   // PUSH1 3
        0x60, 2,   // PUSH1 2
        0x60, 1,   // PUSH1 1
        0x90]      // SWAP1
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 1, 2]);
});

// 9A SWAP11
test("SWAP11", func() : () {
    let context = testOpCodes(
        [0x60, 16, // PUSH1 16
        0x60, 15,  // PUSH1 15
        0x60, 14,  // PUSH1 14
        0x60, 13,  // PUSH1 13
        0x60, 12,  // PUSH1 12
        0x60, 11,  // PUSH1 11
        0x60, 10,  // PUSH1 10
        0x60, 9,   // PUSH1 9
        0x60, 8,   // PUSH1 8
        0x60, 7,   // PUSH1 7
        0x60, 6,   // PUSH1 6
        0x60, 5,   // PUSH1 5
        0x60, 4,   // PUSH1 4
        0x60, 3,   // PUSH1 3
        0x60, 2,   // PUSH1 2
        0x60, 1,   // PUSH1 1
        0x9a]      // SWAP11
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [16, 15, 14, 13, 1, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 12]);
});

// 9F SWAP16
test("SWAP16 (should throw error)", func() : () {
    let context = testOpCodes(
        [0x60, 16, // PUSH1 16
        0x60, 15,  // PUSH1 15
        0x60, 14,  // PUSH1 14
        0x60, 13,  // PUSH1 13
        0x60, 12,  // PUSH1 12
        0x60, 11,  // PUSH1 11
        0x60, 10,  // PUSH1 10
        0x60, 9,   // PUSH1 9
        0x60, 8,   // PUSH1 8
        0x60, 7,   // PUSH1 7
        0x60, 6,   // PUSH1 6
        0x60, 5,   // PUSH1 5
        0x60, 4,   // PUSH1 4
        0x60, 3,   // PUSH1 3
        0x60, 2,   // PUSH1 2
        0x60, 1,   // PUSH1 1
        0x9f]      // SWAP16
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == []);
});

// A0 LOG0
test("LOG0", func() : () {
    let context = testOpCodes(
        [0x7f,                          // PUSH32
        1, 2, 3, 4, 5, 6, 7, 8,         // 0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20
        9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32,
        0x60, 0,                        // PUSH1 0
        0x52,                           // MSTORE
        0x60, 6,                        // PUSH1 6
        0x60, 4,                        // PUSH1 4
        0xa0]                           // LOG0
    );
    let result = context.logs;
    Debug.print(debug_show(result));
    assert(result == { topics = [] : [Blob]; data = "\04\05\06\07\08\09" : Blob });
});

// A1 LOG1
test("LOG1", func() : () {
    let context = testOpCodes(
        [0x7f,                          // PUSH32
        1, 2, 3, 4, 5, 6, 7, 8,         // 0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20
        9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32,
        0x60, 0,                        // PUSH1 0
        0x52,                           // MSTORE
        0x67,                           // PUSH8
        0x12, 0x34, 0x56, 0x78,         // 0x1234567890abcdef
        0x90, 0xab, 0xcd, 0xef,
        0x60, 6,                        // PUSH1 6
        0x60, 4,                        // PUSH1 4
        0xa1]                           // LOG1
    );
    let result = context.logs;
    Debug.print(debug_show(result));
    assert(result == { topics = ["\12\34\56\78\90\ab\cd\ef"] : [Blob]; data = "\04\05\06\07\08\09" : Blob });
});

// A2 LOG2
test("LOG1", func() : () {
    let context = testOpCodes(
        [0x7f,                          // PUSH32
        1, 2, 3, 4, 5, 6, 7, 8,         // 0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20
        9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32,
        0x60, 0,                        // PUSH1 0
        0x52,                           // MSTORE
        0x67,                           // PUSH8
        0x13, 0x57, 0x9a, 0xce,         // 0x13579ace24680bdf
        0x24, 0x68, 0x0b, 0xdf,
        0x67,                           // PUSH8
        0x12, 0x34, 0x56, 0x78,         // 0x1234567890abcdef
        0x90, 0xab, 0xcd, 0xef,
        0x60, 6,                        // PUSH1 6
        0x60, 4,                        // PUSH1 4
        0xa2]                           // LOG2
    );
    let result = context.logs;
    Debug.print(debug_show(result));
    assert(result == {
        topics = [
            "\12\34\56\78\90\ab\cd\ef",
            "\13\57\9a\ce\24\68\0b\df"
        ] : [Blob];
        data = "\04\05\06\07\08\09" : Blob
    });
});

// A3 LOG3
test("LOG3", func() : () {
    let context = testOpCodes(
        [0x7f,                          // PUSH32
        1, 2, 3, 4, 5, 6, 7, 8,         // 0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20
        9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32,
        0x60, 0,                        // PUSH1 0
        0x52,                           // MSTORE
        0x67,                           // PUSH8
        0xfe, 0xdc, 0xba, 0x09,         // 0xfedcba0987654321
        0x87, 0x65, 0x43, 0x21,
        0x67,                           // PUSH8
        0x13, 0x57, 0x9a, 0xce,         // 0x13579ace24680bdf
        0x24, 0x68, 0x0b, 0xdf,
        0x67,                           // PUSH8
        0x12, 0x34, 0x56, 0x78,         // 0x1234567890abcdef
        0x90, 0xab, 0xcd, 0xef,
        0x60, 6,                        // PUSH1 6
        0x60, 4,                        // PUSH1 4
        0xa3]                           // LOG3
    );
    let result = context.logs;
    Debug.print(debug_show(result));
    assert(result == {
        topics = [
            "\12\34\56\78\90\ab\cd\ef",
            "\13\57\9a\ce\24\68\0b\df",
            "\fe\dc\ba\09\87\65\43\21"
        ] : [Blob];
        data = "\04\05\06\07\08\09" : Blob
    });
});

// A4 LOG4
test("LOG4", func() : () {
    let context = testOpCodes(
        [0x7f,                          // PUSH32
        1, 2, 3, 4, 5, 6, 7, 8,         // 0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20
        9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32,
        0x60, 0,                        // PUSH1 0
        0x52,                           // MSTORE
        0x7f,                           // PUSH32
        0x01, 0x23, 0x45, 0x67,         // 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
        0x89, 0xab, 0xcd, 0xef,
        0x01, 0x23, 0x45, 0x67,
        0x89, 0xab, 0xcd, 0xef,
        0x01, 0x23, 0x45, 0x67,
        0x89, 0xab, 0xcd, 0xef,
        0x01, 0x23, 0x45, 0x67,
        0x89, 0xab, 0xcd, 0xef,
        0x67,                           // PUSH8
        0xfe, 0xdc, 0xba, 0x09,         // 0xfedcba0987654321
        0x87, 0x65, 0x43, 0x21,
        0x67,                           // PUSH8
        0x13, 0x57, 0x9a, 0xce,         // 0x13579ace24680bdf
        0x24, 0x68, 0x0b, 0xdf,
        0x67,                           // PUSH8
        0x12, 0x34, 0x56, 0x78,         // 0x1234567890abcdef
        0x90, 0xab, 0xcd, 0xef,
        0x60, 16,                       // PUSH1 16
        0x60, 4,                        // PUSH1 4
        0xa4]                           // LOG4
    );
    let result = context.logs;
    Debug.print(debug_show(result));
    assert(result == {
        topics = [
            "\12\34\56\78\90\ab\cd\ef",
            "\13\57\9a\ce\24\68\0b\df",
            "\fe\dc\ba\09\87\65\43\21",
            "\01\23\45\67\89\ab\cd\ef\01\23\45\67\89\ab\cd\ef\01\23\45\67\89\ab\cd\ef\01\23\45\67\89\ab\cd\ef"
        ] : [Blob];
        data = "\04\05\06\07\08\09\0a\0b\0c\0d\0e\0f\10\11\12\13" : Blob
    });
});
