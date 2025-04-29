// This is intended as a temporary and rudimentary tool to test opcodes. It can
// be deployed locally as a canister. The public function accepts Text
// as its argument type.
//
// For example, `PUSH1 2 PUSH1 1 ADD` would be entered as
// `6002600101`.
//
// The public function returns a tuple containing the stack, memory, storage,
// transient storage and return data, each preceded by a descriptor.

import { stateTransition; engine } "../src/evm_mo_backend/main";

import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Trie "mo:base/Trie";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import T "../src/evm_mo_backend/types";
import { encode; decode } "mo:base16/Base16";

import {op_5C_TLOAD} "../src/evm_mo_backend/op_5C_TLOAD";
import {op_5D_TSTORE} "../src/evm_mo_backend/op_5D_TSTORE";
import {op_5E_MCOPY}  "../src/evm_mo_backend/op_5E_MCOPY";
import {op_4A_BLOBBASEFEE} "../src/evm_mo_backend/op_4A_BLOBBASEFEE";

actor {
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

    let dummyBlockInfo: T.BlockInfo = {
        blockNumber = 1_000_000;
        blockGasLimit = 30_000_000;
        blockDifficulty = 1_000_000_000_000;
        blockTimestamp = 1_500_000_000;
        blockCoinbase = "\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc\00\cc";
        blockCommitments = [hash999999];
        chainId = 1;
    };


    public func testBytecode(bytecode: Text) : async (
        Text, [Nat], Text, Text, Text, [(Text, Text)], Text, [(Text, Text)], Text, Text
        ) {
        var code: [T.OpCode] = [];

        switch (decode(bytecode)) {
            case (null) {
                Debug.print("Invalid bytecode");
            };
            case (?codeBlob) {
                code := Blob.toArray(codeBlob);
            };
        };

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

        let storage = Trie.toArray<Blob, [Nat8], (Text, Text)>(
            context.contractStorage,
            func (k, v) = (encode(k), encode(Blob.fromArray(v)))
        );

        Debug.print(debug_show(("tempMemory", context.tempMemory)));

        let transientStorage = Trie.toArray<Blob, [Nat8], (Text, Text)>(
            context.tempMemory,
            func (k, v) = (encode(k), encode(Blob.fromArray(v)))
        );

        Debug.print(debug_show(("tempMemory after", transientStorage)));

        var returnData: Text = "null";
        switch (context.returnData) {
            case (null) {};
            case (?rdata) {
                returnData := encode(rdata);
            };
        };

        (
            "\nSTACK: ", context.stack,
            "\nMEMORY: ", encode(Blob.fromArray(context.memory)),
            "\nSTORAGE: ", storage,
            "\nTRANSIENT STORAGE: ", transientStorage,
            "\nRETURN DATA: ", returnData
        );
    };
}