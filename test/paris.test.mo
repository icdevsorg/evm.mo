import { test; skip } "mo:test/async";
import Debug "mo:base/Debug";

import { stateTransition; engine } "../src/evm_mo_backend/main";

import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Vec "mo:vector";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Trie "mo:base/Trie";
import Map "mo:map/Map";

// Import our shared types and dummy implementations
import T "../src/evm_mo_backend/types";
import EVMStack "../src/evm_mo_backend/evmStack";

// Import our new opcode implementations
import {op_5C_TLOAD} "../src/evm_mo_backend/op_5C_TLOAD";
import {op_5D_TSTORE} "../src/evm_mo_backend/op_5D_TSTORE";
import {op_5E_MCOPY}  "../src/evm_mo_backend/op_5E_MCOPY";
import {op_4A_BLOBBASEFEE} "../src/evm_mo_backend/op_4A_BLOBBASEFEE";

// Dummy definitions for testing

// Dummy transaction, caller, block info and engine
let dummyTransaction: T.Transaction = {
   caller = "\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa\00\aa";
    nonce = 2;
    gasPriceTx = 5;
    gasLimitTx = 1_100_000;
    callee = "\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb\00\bb";
    incomingEth = 123;
    dataTx = "\01\23\45\67\89\ab\cd\ef";
};

let dummyCallerState: T.CallerState = {
  balance = 11_550_000;
    nonce = 1;
    code = [];
    storage = Trie.empty();
};

let hash999999 = "\ac\dc\46\01\86\f7\23\3c\92\7e\7d\b2\dc\c7\03\c0\e5\00\b6\53\ca\82\27\3b\7b\fa\d8\04\5d\85\a4\70" : Blob;

let dummyBlockInfo = {
  blockNumber = 1_000_000;
    blockGasLimit = 30_000_000;
    blockDifficulty = 1_000_000_000_000;
    blockTimestamp = 1_500_000_000;
    blockCoinbase = Blob.fromArray([0x00, 0xcc, 0x00, 0xcc, 0x00, 0xcc, 0x00, 0xcc, 0x00, 0xcc, 0x00, 0xcc, 0x00, 0xcc, 0x00, 0xcc, 0x00, 0xcc, 0x00, 0xcc]);
    chainId = 1;
    blockCommitments = [hash999999];
};



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


// Test for BLOBBASEFEE opcode
await test("BLOBBASEFEE Opcode Test", func () : async () {
  
  // Call our opcode
  let context = await testOpCodes(
    [0x4A]    // BlobBaseFee
  );
  let result = context.stack;
  //Debug.print(debug_show(result));
  assert(result == [0]);
});

// Test for TLOAD opcode
await test("TLOAD Opcode Test", func () : async () {
  let context = await testOpCodes(
  [0x62,               // PUSH3
  0x12, 0x34, 0x56,    // 0x123456
  0x60, 42,            // PUSH1 42
  0x5D,                // TSTORE
  0x60, 42,            // PUSH1 42
  0x5C]                // SLOAD
    );
    let result = context.stack;
    Debug.print(debug_show(result));
    assert(result == [0x123456]);
});


// Test for MCOPY opcode
await test("MCOPY Opcode Test", func () : async () {
  let context = await testOpCodes(
[ 0x62,               // PUSH3
0x12, 0x34, 0x56,    // 0x123456
0x60, 0,             // PUSH1 0 -- destination for MSTORE
0x52,                // MSTORE


      // MCOPY parameters:
      0x60, 32,           // PUSH1 32 -- destination offset for MCOPY (copy to offset 32)
      0x60, 0,            // PUSH1 0  -- source offset for MCOPY
      0x60, 32,           // PUSH1 32 -- length (copy 32 bytes)
      0x5E,               // MCOPY
    
      0x60, 32,           // PUSH1 32 -- memory offset from which to load
      0x51                // MLOAD
    ]
);
Debug.print(debug_show(context.stack));
Debug.print(debug_show(context.memory));


 //Debug.print(debug_show(result));
 assert(context.memory.size() == 64);
 assert(context.stack == [0x123456]);

});


// Test for BLOBHASH opcode
await test("BLOBHASH Opcode Test", func () : async () {
  let context = await testOpCodes(
    [ 0x60, 0,// Push1 Index 0 opcode
      0x49   // BLOBHASH opcode
    ]    
  );
Debug.print(debug_show(context.stack));
Debug.print(debug_show(context.memory));


 //Debug.print(debug_show(result));
 assert(context.stack == [hash999999]);

});
