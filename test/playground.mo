// This is intended as a temporary and rudimentary tool to test opcodes. It can
// be deployed locally as a canister. The public function accepts [(Nat8,?Blob)]
// as its argument type.
//
// For example, `PUSH1 2 PUSH1 1 ADD` would be entered as
// `[(0x60,null), (2,null), (0x60,null), (1,null), (0x01,null)]`.
//
// The public function returns the stack as a [Nat] type.

import { stateTransition } "../src/evm_mo_backend/main";

import Nat "mo:base/Nat";
import Trie "mo:base/Trie";
import T "types";

actor {
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

    public func testOpCodes(code: [T.OpCode]) : async [Nat] {
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
        context.stack;
    };
}