import { test; skip } "mo:test/async"; // see https://mops.one/test

import { stateTransition; engine } "../src/evm_mo_backend/main";

import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Vec "mo:vector";
import Map "mo:map/Map";
import EVMStack "../src/evm_mo_backend/evmStack";
import T "../src/evm_mo_backend/types";
import { decodeAccount } "../src/evm_mo_backend/rlp";

type Key<K> = Trie.Key<K>;
func key(n: Blob) : Key<Blob> { { hash = Blob.hash(n); key = n } };

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
    assert(result == [0x67, 0x89, 0xab, 0xcd, 0xef, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
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
    assert(result == [0x45, 0x67, 0x89, 0xab, 0xcd, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
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
    assert(result == [550000 - 100000 * 5 - 123]);
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

Debug.print(">");
Debug.print(">");
Debug.print(">  Memory Operations");
Debug.print(">");
Debug.print(">");

// 50 POP
await test("POP", func() : async () {
    let context = await testOpCodes(
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
await test("MLOAD: 0", func() : async () {
    let context = await testOpCodes(
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
await test("MSTORE: 0, 0x123456", func() : async () {
    let context = await testOpCodes(
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
await test("MSTORE8: 5, 0xff", func() : async () {
    let context = await testOpCodes(
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
await test("SSTORE: (42, 0x123456); SLOAD", func() : async () {
    let context = await testOpCodes(
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
await test("JUMP: 10", func() : async () {
    let context = await testOpCodes(
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
await test("JUMPI: 12, 1", func() : async () {
    let context = await testOpCodes(
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
await test("PC", func() : async () {
    let context = await testOpCodes(
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
await test("MSIZE", func() : async () {
    let context = await testOpCodes(
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
await test("GAS", func() : async () {
    let context = await testOpCodes(
        [0x5f,   // PUSH0
        0x5a]    // GAS
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0, 100000 - 2 - 2]);
});

// 5B JUMPDEST
// Tested in 56 & 57 above
await test("JUMPDEST", func() : async () {
    let context = await testOpCodes(
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
await test("Dynamic gas cost & gas refund", func() : async () {
    let context = await testOpCodes(
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
await test("PUSH0", func() : async () {
    let context = await testOpCodes(
        [0x5f]  // PUSH0
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0]);
});

// 5F-7F PUSH various
await test("PUSH0, PUSH1, PUSH2, PUSH6, PUSH12, PUSH32", func() : async () {
    let context = await testOpCodes(
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
await test("DUP1", func() : async () {
    let context = await testOpCodes(
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
await test("DUP4", func() : async () {
    let context = await testOpCodes(
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
await test("DUP8 (should throw error)", func() : async () {
    let context = await testOpCodes(
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
await test("DUP1", func() : async () {
    let context = await testOpCodes(
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
await test("SWAP1", func() : async () {
    let context = await testOpCodes(
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
await test("SWAP11", func() : async () {
    let context = await testOpCodes(
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
await test("SWAP16 (should throw error)", func() : async () {
    let context = await testOpCodes(
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
await test("LOG0", func() : async () {
    let context = await testOpCodes(
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
await test("LOG1", func() : async () {
    let context = await testOpCodes(
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
await test("LOG1", func() : async () {
    let context = await testOpCodes(
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
await test("LOG3", func() : async () {
    let context = await testOpCodes(
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
await test("LOG4", func() : async () {
    let context = await testOpCodes(
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

// Execution and System Operations

Debug.print(">");
Debug.print(">");
Debug.print(">  Execution and System Operations");
Debug.print(">");
Debug.print(">");

// 00 STOP
await test("STOP", func() : async () {
    let context = await testOpCodes(
        [0x60, 2,  // PUSH1 2
        0x60, 1,   // PUSH1 1
        0x01,      // ADD
        0x00,      // STOP
        0x60, 5,   // PUSH1 5
        0x01]      // ADD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [3]);
});

// F0 CREATE
await test("CREATE: value = 9, no code", func() : async () {
    let context = await testOpCodes(
        [0x60, 0,  // PUSH1 0
        0x60, 0,   // PUSH1 0
        0x60, 9,   // PUSH1 9
        0xf0]      // CREATE
    );
    let result = context.stack;
    let addressBuffer = Buffer.Buffer<Nat8>(20);
    for (i in Iter.revRange(19, 0)) {
      addressBuffer.add(Nat8.fromNat((result[0] % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
    };
    let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
    var code = [] : [T.OpCode];
    var balance = 0;
    let accountData = Trie.get(context.accounts, key address, Blob.equal);
    switch (accountData) {
      case (null) {};
      case (?data) {
        let decodedData = decodeAccount(data);
        balance := decodedData.1;
        let codeHash = decodedData.3;
        for (val in context.codeStore.vals()) {
          if (val.0 == codeHash){ code := val.1 };
        };
      };
    };
    Debug.print(debug_show("Address:", address));
    Debug.print(debug_show("Balance:", balance));
    Debug.print(debug_show("Code:", code));
    assert(result[0] > 0 and balance == 9 and Array.equal(code, [], Nat8.equal));
});

await test("CREATE: value = 0, code = FFFFFFFF", func() : async () {
    let context = await testOpCodes(
        [0x6c,                        // PUSH13
        0x63, 0xff, 0xff, 0xff, 0xff, // 0x63FFFFFFFF6000526004601CF3
        0x60, 0x00, 0x52, 0x60, 0x04,
        0x60, 0x1c, 0xf3,
        0x60, 0,                      // PUSH1 0
        0x52,                         // MSTORE
        0x60, 13,                     // PUSH1 13
        0x60, 19,                     // PUSH1 19
        0x60, 0,                      // PUSH1 0
        0xf0]                         // CREATE
    );
    let result = context.stack;
    let addressBuffer = Buffer.Buffer<Nat8>(20);
    for (i in Iter.revRange(19, 0)) {
      addressBuffer.add(Nat8.fromNat((result[0] % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
    };
    let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
    var code = [] : [T.OpCode];
    var balance = 0;
    let accountData = Trie.get(context.accounts, key address, Blob.equal);
    switch (accountData) {
      case (null) {};
      case (?data) {
        let decodedData = decodeAccount(data);
        balance := decodedData.1;
        let codeHash = decodedData.3;
        for (val in context.codeStore.vals()) {
          if (val.0 == codeHash){ code := val.1 };
        };
      };
    };
    Debug.print(debug_show("Address:", address));
    Debug.print(debug_show("Balance:", balance));
    Debug.print(debug_show("Code:", code));
    assert(result[0] > 0 and balance == 0 and Array.equal(code, [255, 255, 255, 255] : [Nat8], Nat8.equal));
});

// F1 CALL

await test("CALL: return 0xabcd", func() : async () {
    let context = await testOpCodes(
        [0x77, //     PUSH24
        //            [
        0x6e, //        PUSH15
        //              [
        0x60, 0xab, //    PUSH1 0xAB
        0x60, 0, //       PUSH1 0
        0x53, //          MSTORE8
        0x60, 0xcd, //    PUSH1 0xCD
        0x60, 1, //       PUSH1 1
        0x53, //          MSTORE8
        0x60, 2, //       PUSH1 2
        0x60, 0, //       PUSH1 0
        0xf3, //          RETURN
        //              ] // returns 0xabcd
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 15, //    PUSH1 15
        0x60, 17, //    PUSH1 17
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 24, //  PUSH1 24 // size
        0x60, 8, //   PUSH1 8 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 2, //   PUSH1 2 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x60, 0, //   PUSH1 0 // value
        0x85, //      DUP6 // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf1] //      CALL
    );
    let result = context.stack[1];
    let memory = context.memory;
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Memory:", memory));
    assert(result == 1 and memory[0] == 0xab and memory[1] == 0xcd);
});

await test("CALL: return value from storage slot 0", func() : async () {
    let context = await testOpCodes(
        [0x73, //     PUSH20
        //            [
        0x6a, //        PUSH11
        //              [
        0x60, 0, //       PUSH1 0
        0x54, //          SLOAD
        0x60, 0, //       PUSH1 0
        0x52, //          MSTORE
        0x60, 32, //      PUSH1 32
        0x60, 0, //       PUSH1 0
        0xf3, //          RETURN
        //              ] // returns value from storage slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 11, //    PUSH1 11
        0x60, 21, //    PUSH1 21
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 20, //  PUSH1 20 // size
        0x60, 12, //  PUSH1 12 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 42, //  PUSH1 42
        0x60, 0, //   PUSH1 0
        0x55, //      SSTORE
        0x60, 32, //  PUSH1 32 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x60, 0, //   PUSH1 0 // value
        0x85, //      DUP6    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf1] //      CALL
    );
    let result = context.stack[1];
    let memory = context.memory;
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Memory:", memory));
    assert(result == 1 and memory[31] == 0);
});

await test("CALL: store 42 in slot 0", func() : async () {
    let context = await testOpCodes(
        [0x6d, //     PUSH14
        //            [
        0x64, //        PUSH5
        //              [
        0x60, 42, //      PUSH1 42
        0x60, 0, //       PUSH1 0
        0x55, //          SSTORE
        //              ] // stores 42 in slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 5, //     PUSH1 5
        0x60, 27, //    PUSH1 27
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 14, //  PUSH1 14 // size
        0x60, 18, //  PUSH1 18 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 0, //   PUSH1 0 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x60, 0, //   PUSH1 0 // value
        0x85, //      DUP6    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf1] //      CALL
    );
    let result = context.stack[1];
    let storage = context.contractStorage;
    let key0 : Blob = "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00";
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Storage:", storage));
    assert(result == 1 and Trie.get(storage, key key0, Blob.equal) == null);
});

// F2 CALLCODE
await test("CALLCODE: return value from storage slot 0", func() : async () {
    let context = await testOpCodes(
        [0x73, //     PUSH20
        //            [
        0x6a, //        PUSH11
        //              [
        0x60, 0, //       PUSH1 0
        0x54, //          SLOAD
        0x60, 0, //       PUSH1 0
        0x52, //          MSTORE
        0x60, 32, //      PUSH1 32
        0x60, 0, //       PUSH1 0
        0xf3, //          RETURN
        //              ] // returns value from storage slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 11, //    PUSH1 11
        0x60, 21, //    PUSH1 21
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 20, //  PUSH1 20 // size
        0x60, 12, //  PUSH1 12 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 42, //  PUSH1 42
        0x60, 0, //   PUSH1 0
        0x55, //      SSTORE
        0x60, 32, //  PUSH1 32 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x60, 0, //   PUSH1 0 // value
        0x85, //      DUP6    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf2] //      CALLCODE
    );
    let result = context.stack[1];
    let memory = context.memory;
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Memory:", memory));
    assert(result == 1 and memory[31] == 42);
});

await test("CALLCODE: store 42 in slot 0", func() : async () {
    let context = await testOpCodes(
        [0x6d, //     PUSH14
        //            [
        0x64, //        PUSH5
        //              [
        0x60, 42, //      PUSH1 42
        0x60, 0, //       PUSH1 0
        0x55, //          SSTORE
        //              ] // stores 42 in slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 5, //     PUSH1 5
        0x60, 27, //    PUSH1 27
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 14, //  PUSH1 14 // size
        0x60, 18, //  PUSH1 18 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 0, //   PUSH1 0 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x60, 0, //   PUSH1 0 // value
        0x85, //      DUP6    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf2] //      CALLCODE
    );
    let result = context.stack[1];
    let storage = context.contractStorage;
    let key0 : Blob = "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00";
    var storage_0 : Nat8 = 0;
    switch (Trie.get(storage, key key0, Blob.equal)) {
        case (null) {};
        case (?slot0) {
            storage_0 := slot0[31];
        };
    };
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Storage:", storage));
    assert(result == 1 and storage_0 == 42);
});

// F3 RETURN
await test("RETURN", func() : async () {
    let context = await testOpCodes(
        [0x60, 0xab, //   PUSH1 0xAB
        0x60, 0, //       PUSH1 0
        0x53, //          MSTORE8
        0x60, 0xcd, //    PUSH1 0xCD
        0x60, 1, //       PUSH1 1
        0x53, //          MSTORE8
        0x60, 2, //       PUSH1 2
        0x60, 0, //       PUSH1 0
        0xf3] //          RETURN
    );
    let returnDataOpt = context.returnData;
    var returnData = "" : Blob;
    switch (returnDataOpt) {
        case (null) {};
        case (?data) {
            returnData := data;
        };
    };
    Debug.print(debug_show("Return data:", returnData));
    assert(returnData == "\AB\CD");
});

// F4 DELEGATECALL
await test("DELEGATECALL: store 42 in slot 0", func() : async () {
    let context = await testOpCodes(
        [0x6d, //     PUSH14
        //            [
        0x64, //        PUSH5
        //              [
        0x60, 42, //      PUSH1 42
        0x60, 0, //       PUSH1 0
        0x55, //          SSTORE
        //              ] // stores 42 in slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 5, //     PUSH1 5
        0x60, 27, //    PUSH1 27
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 14, //  PUSH1 14 // size
        0x60, 18, //  PUSH1 18 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 0, //   PUSH1 0 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x84, //      DUP5    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf4] //      DELEGATECALL
    );
    let result = context.stack[1];
    let storage = context.contractStorage;
    let key0 : Blob = "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00";
    var storage_0 : Nat8 = 0;
    switch (Trie.get(storage, key key0, Blob.equal)) {
        case (null) {};
        case (?slot0) {
            storage_0 := slot0[31];
        };
    };
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Storage:", storage));
    assert(result == 1 and storage_0 == 42);
});

// F5 CREATE2
await test("CREATE2: value = 0, code = FFFFFFFF, salt = 42", func() : async () {
    let context = await testOpCodes(
        [0x6c,                        // PUSH13
        0x63, 0xff, 0xff, 0xff, 0xff, // 0x63FFFFFFFF6000526004601CF3
        0x60, 0x00, 0x52, 0x60, 0x04,
        0x60, 0x1c, 0xf3,
        0x60, 0,                      // PUSH1 0
        0x52,                         // MSTORE
        0x60, 42,                     // PUSH1 42
        0x60, 13,                     // PUSH1 13
        0x60, 19,                     // PUSH1 19
        0x60, 0,                      // PUSH1 0
        0xf5]                         // CREATE2
    );
    let result = context.stack;
    let addressBuffer = Buffer.Buffer<Nat8>(20);
    for (i in Iter.revRange(19, 0)) {
      addressBuffer.add(Nat8.fromNat((result[0] % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
    };
    let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
    var code = [] : [T.OpCode];
    var balance = 0;
    let accountData = Trie.get(context.accounts, key address, Blob.equal);
    switch (accountData) {
      case (null) {};
      case (?data) {
        let decodedData = decodeAccount(data);
        balance := decodedData.1;
        let codeHash = decodedData.3;
        for (val in context.codeStore.vals()) {
          if (val.0 == codeHash){ code := val.1 };
        };
      };
    };
    Debug.print(debug_show("Address:", address));
    Debug.print(debug_show("Balance:", balance));
    Debug.print(debug_show("Code:", code));
    assert(result[0] > 0 and balance == 0 and Array.equal(code, [255, 255, 255, 255] : [Nat8], Nat8.equal));
});

await test("CREATE2: same parameters twice (should fail)", func() : async () {
    let context = await testOpCodes(
        [0x6c,                        // PUSH13
        0x63, 0xff, 0xff, 0xff, 0xff, // 0x63FFFFFFFF6000526004601CF3
        0x60, 0x00, 0x52, 0x60, 0x04,
        0x60, 0x1c, 0xf3,
        0x60, 0,                      // PUSH1 0
        0x52,                         // MSTORE
        0x60, 42,                     // PUSH1 42
        0x60, 13,                     // PUSH1 13
        0x60, 19,                     // PUSH1 19
        0x60, 0,                      // PUSH1 0
        0xf5,                         // CREATE2
        0x50,                         // POP
        0x60, 42,                     // PUSH1 42
        0x60, 13,                     // PUSH1 13
        0x60, 19,                     // PUSH1 19
        0x60, 0,                      // PUSH1 0
        0xf5]                         // CREATE2
    );
    let result = context.stack;
    let addressBuffer = Buffer.Buffer<Nat8>(20);
    for (i in Iter.revRange(19, 0)) {
      addressBuffer.add(Nat8.fromNat((result[0] % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
    };
    let address = Blob.fromArray(Buffer.toArray<Nat8>(addressBuffer));
    var code = [] : [T.OpCode];
    var balance = 0;
    let accountData = Trie.get(context.accounts, key address, Blob.equal);
    switch (accountData) {
      case (null) {};
      case (?data) {
        let decodedData = decodeAccount(data);
        balance := decodedData.1;
        let codeHash = decodedData.3;
        for (val in context.codeStore.vals()) {
          if (val.0 == codeHash){ code := val.1 };
        };
      };
    };
    Debug.print(debug_show("Stack:", result));
    Debug.print(debug_show("Address:", address));
    Debug.print(debug_show("Balance:", balance));
    Debug.print(debug_show("Code:", code));
    assert(result[0] == 0 and balance == 0 and Array.equal(code, [] : [Nat8], Nat8.equal));
});

// FA STATICCALL
await test("STATICCALL: store 42 in slot 0 (call should fail)", func() : async () {
    let context = await testOpCodes(
        [0x6d, //     PUSH14
        //            [
        0x64, //        PUSH5
        //              [
        0x60, 42, //      PUSH1 42
        0x60, 0, //       PUSH1 0
        0x55, //          SSTORE
        //              ] // stores 42 in slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 5, //     PUSH1 5
        0x60, 27, //    PUSH1 27
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 14, //  PUSH1 14 // size
        0x60, 18, //  PUSH1 18 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 0, //   PUSH1 0 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x84, //      DUP5    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xfa] //      STATICCALL
    );
    let result = context.stack[1];
    let storage = context.contractStorage;
    let key0 : Blob = "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00";
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Storage:", storage));
    assert(result == 0 and Trie.get(storage, key key0, Blob.equal) == null);
});

// FD REVERT
await test("(REVERT - prior to calling)", func() : async () {
    let context = await testOpCodes(
        [0x62,                  // PUSH3
        0x12, 0x34, 0x56,       // 0x123456
        0x60, 42,               // PUSH1 42
        0x55,                   // SSTORE
        0x67,                   // PUSH8
        1, 2, 3, 4, 5, 6, 7, 8, // 0x0102030405060708
        0x60, 0,                // PUSH1 0
        0x52,                   // MSTORE
        0x67,                   // PUSH8
        0x12, 0x34, 0x56, 0x78, // 0x1234567890abcdef
        0x90, 0xab, 0xcd, 0xef,
        0x60, 8,                // PUSH1 8
        0x60, 24,               // PUSH1 24
        0xa1,                   // LOG1
        0x60, 0,                // PUSH1 0
        0x60, 0,                // PUSH1 0
        0x60, 9,                // PUSH1 9
        0xf0]                   // CREATE
    );
    let stack = context.stack;
    let storage = context.contractStorage;
    let logs = context.logs;
    let accounts = context.accounts;
    Debug.print(debug_show("Stack:", stack));
    Debug.print(debug_show("Storage:", storage));
    Debug.print(debug_show("Logs:", logs));  
    Debug.print("Accounts:");
    var i = 0;
    for ((k,v) in Trie.iter(accounts)) {
        i += 1;
        Debug.print(debug_show(i, k));
    };
    assert(true);
});

await test("REVERT", func() : async () {
    let context = await testOpCodes(
        [0x62,                  // PUSH3
        0x12, 0x34, 0x56,       // 0x123456
        0x60, 42,               // PUSH1 42
        0x55,                   // SSTORE
        0x67,                   // PUSH8
        1, 2, 3, 4, 5, 6, 7, 8, // 0x0102030405060708
        0x60, 0,                // PUSH1 0
        0x52,                   // MSTORE
        0x67,                   // PUSH8
        0x12, 0x34, 0x56, 0x78, // 0x1234567890abcdef
        0x90, 0xab, 0xcd, 0xef,
        0x60, 8,                // PUSH1 8
        0x60, 24,               // PUSH1 24
        0xa1,                   // LOG1
        0x60, 0,                // PUSH1 0
        0x60, 0,                // PUSH1 0
        0x60, 9,                // PUSH1 9
        0xf0,                   // CREATE
        0x60, 8,                // PUSH1 8
        0x60, 24,               // PUSH1 24
        0xfd,                   // REVERT
        0x60, 42]               // PUSH1 42 // shouldn't be pushed
    );
    let stack = context.stack;
    let storage = context.contractStorage;
    let logs = context.logs;
    let accounts = context.accounts;
    let returnData = context.returnData;
    Debug.print(debug_show("Stack:", stack));
    Debug.print(debug_show("Storage:", storage));
    Debug.print(debug_show("Logs:", logs));  
    Debug.print("Accounts:");
    var i = 0;
    for ((k,v) in Trie.iter(accounts)) {
        i += 1;
        Debug.print(debug_show(i, k));
    };
    Debug.print(debug_show("Return data:", returnData));
    assert(stack == [] and Trie.size(storage) == 0 and logs == [] and Trie.size(accounts) == 3 and returnData == ?"\01\02\03\04\05\06\07\08");
});

await test("REVERT: within subcontext", func() : async () {
    let context = await testOpCodes(
        [0x72, //     PUSH19
        //            [
        0x69, //        PUSH10
        //              [
        0x60, 42, //      PUSH1 42
        0x60, 0, //       PUSH1 0
        0x55, //          SSTORE
        0x60, 0, //       PUSH1 0
        0x60, 0, //       PUSH1 0
        0xfd, //          REVERT
        //              ] // stores 42 in slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 10, //    PUSH1 10
        0x60, 22, //    PUSH1 22
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 19, //  PUSH1 19 // size
        0x60, 13, //  PUSH1 13 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 0, //   PUSH1 0 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x60, 0, //   PUSH1 0 // value
        0x85, //      DUP6    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf2] //      CALLCODE
    );
    let result = context.stack[1];
    let storage = context.contractStorage;
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Storage:", storage));
    assert(result == 0 and Trie.size(storage) == 0);
});

// FE INVALID
await test("INVALID", func() : async () {
    let context = await testOpCodes(
        [0x60, 2, // PUSH1 2
        0x60, 1, //  PUSH1 1
        0xfe] //     INVALID
    );
    let result = context.stack;
    Debug.print(debug_show("Stack:", result));
    assert(result == []);
});

await test("INVALID: within subcontext", func() : async () {
    let context = await testOpCodes(
        [0x6e, //     PUSH15
        //            [
        0x65, //        PUSH6
        //              [
        0x60, 42, //      PUSH1 42
        0x60, 0, //       PUSH1 0
        0x55, //          SSTORE
        0xfe, //          INVALID
        //              ] // stores 42 in slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 6, //     PUSH1 6
        0x60, 26, //    PUSH1 26
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 15, //  PUSH1 15 // size
        0x60, 17, //  PUSH1 17 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 0, //   PUSH1 0 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x60, 0, //   PUSH1 0 // value
        0x85, //      DUP6    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf2] //      CALLCODE
    );
    let stack = context.stack;
    let result = context.stack[1];
    let storage = context.contractStorage;
    Debug.print(debug_show("Stack:", stack));
    Debug.print(debug_show("Result:", result));
    Debug.print(debug_show("Storage:", storage));
    assert(result == 0 and Trie.size(storage) == 0);
});

// FF SELFDESTRUCT
await test("SELFDESTRUCT", func() : async () {
    let context = await testOpCodes(
        [0x6f, //     PUSH16
        //            [
        0x66, //        PUSH7
        //              [
        0x60, 42, //      PUSH1 42
        0x60, 0, //       PUSH1 0
        0x55, //          SSTORE
        0x32, //          ORIGIN
        0xff, //          SELFDESTRUCT
        //              ] // stores 42 in slot 0
        0x60, 0, //     PUSH1 0
        0x52, //        MSTORE
        0x60, 7, //     PUSH1 7
        0x60, 25, //    PUSH1 25
        0xf3, //        RETURN
        //            ] // returns code
        0x60, 0, //   PUSH1 0
        0x52, //      MSTORE
        0x60, 16, //  PUSH1 16 // size
        0x60, 16, //  PUSH1 16 // offset
        0x60, 0, //   PUSH1 0 // value
        0xf0, //      CREATE
        0x60, 0, //   PUSH1 0 // retSize
        0x60, 0, //   PUSH1 0 // retOffset
        0x60, 0, //   PUSH1 0 // argsSize
        0x60, 0, //   PUSH1 0 // argsOffset
        0x60, 0, //   PUSH1 0 // value
        0x85, //      DUP6    // address
        0x61, //      PUSH2 0xFFFF // gas
        0xff, 0xff,
        0xf1] //      CALL
    );
    let storage = context.contractStorage;
    let accounts = context.accounts;
    Debug.print(debug_show("Storage:", storage));
    Debug.print("Accounts:");
    var i = 0;
    for ((k,v) in Trie.iter(accounts)) {
        i += 1;
        Debug.print(debug_show(i, k));
    };
    assert(Trie.size(storage) == 0 and Trie.size(accounts) == 3);
});
