import Int "mo:base/Int";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Ecdsa "mo:libsecp256k1/Ecdsa";
import Signature "mo:libsecp256k1/Signature";
import Message "mo:libsecp256k1/Message";
import RecoveryId "mo:libsecp256k1/RecoveryId";
import Ecmult "mo:libsecp256k1/core/ecmult";
import Sha256 "mo:sha2/Sha256";
import Sha3 "mo:sha3/";
import Ripemd160 "mo:bitcoin/Ripemd160";
import T "types";

module {
    
    type PreCompile = [(T.ExecutionContext, T.ExecutionVariables, T.Engine) -> T.ExecutionVariables];
    type Point = ?(Nat, Nat);

    func modAdd(x: Nat, y: Nat, m: Nat): Nat {
        return (x + y) % m;
    };

    func modSub(x: Nat, y: Nat, m: Nat): Nat {
        return (x + m - y) % m;
    };

    func modMul(x: Nat, y: Nat, m: Nat): Nat {
        return (x * y) % m;
    };

    func modInv(x: Nat, m: Nat): Nat {
        // Modular inverse using Extended Euclidean Algorithm
        var a = 0;
        var b = m;
        var u = 1;
        var t = x;
        while (t > 0) {
            let q = b / t;
            //(t, a, b, u) := (b % t, u, t, a + (m - q) * u % m);
            let t1 = t;
            let a1 = a;
            t := b % t;
            a := u;
            b := t1;
            u := a1 + (m - q) * u % m;
        };
        return if (b == 1) a % m else 0; // Inverse exists only if greatest common denominator == 1
    };

    //modfied from https://forum.dfinity.org/t/reject-text-ic0503-canister-trapped-explicitly-bigint-function-error/26937/3
    func modPow(b: Nat, e: Nat, m: Nat) : Nat {
        var result: Nat = 1;
        var b_ = b;
        var e_ = e;
        b_ := b_ % m;
        while (e_ > 0){
            if(e_ % 2 == 1) result := (result * b_) % m;
            e_ := e_ / 2;
            b_ := (b_ * b_) % m
        };
        return result;
    };

    func pointAdd(P: Point, Q: Point, p: Nat): Point {
        switch (P, Q) {
            case (?(P1, P2), ?(Q1, Q2)) {
                let (x1, y1) = (P1, P2);
                let (x2, y2) = (Q1, Q2);
                if (x1 == x2 and y1 == (p - y2 % p)) return null; // Point at infinity
                let m = if (P == Q) {
                    modMul(3 * x1 * x1, modInv(2 * y1, p), p)
                } else {
                    modMul(modSub(y2, y1, p), modInv(modSub(x2, x1, p), p), p)
                };
                let x3 = modSub(modMul(m, m, p), modAdd(x1, x2, p), p);
                let y3 = modSub(modMul(m, modSub(x1, x3, p), p), y1, p);
                return ?(x3, y3);
            };
            case (?(_, _), null) { return P; };
            case (null, ?(_, _)) { return Q; };
            case (null, null) { return null; };
        }
    };

    func scalarMultiply(k: Nat, P: Point, p: Nat): Point {
        var Q: Point = null; // Point at infinity
        var R: Point = P;
        var scalar = k;
        while (scalar > 0) {
            if (scalar % 2 == 1) {
                Q := pointAdd(Q, R, p);
            };
            R := pointAdd(R, R, p);
            scalar := scalar / 2;
        };
        return Q;
    };

    func ecRecoverError(exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : T.ExecutionVariables {
        let newGas: Int = exVar.totalGas - 3000;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
            return exVar;
        };
    };

    // Pre-compiled contract functions

    let pc_00_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Unused function
        // Derive input data from calldata
        var pos: Nat = exCon.calldata.size();
        var data: Nat = 0;
        for (byte: Nat8 in exCon.calldata.vals()) {
          pos -= 1;
          data += Nat8.toNat(byte) * (256 ** pos);
        };
        // Calculate result
        var resultNat = data;
        // Calculate gas
        let data_word_size = (exCon.calldata.size() + 31) / 32;
        let newGas: Int = exVar.totalGas - 15 - 3 * data_word_size;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        let resultBuffer = Buffer.Buffer<Nat8>(4);
        while (resultNat > 0) {
            resultBuffer.add(Nat8.fromNat(resultNat % 256));
            resultNat /= 256;
        };
        Buffer.reverse(resultBuffer);
        let result = Blob.fromArray(Buffer.toArray<Nat8>(resultBuffer));
        exVar.returnData := Option.make(result);
        exVar
    };

    let pc_01_ecRecover = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Derive input data from calldata
        let inputArray = Blob.toArray(exCon.calldata);
        let hash = Array.subArray<Nat8>(inputArray, 0, 32);
        let v = Array.subArray<Nat8>(inputArray, 32, 32);
        let r = Array.subArray<Nat8>(inputArray, 64, 32);
        let s = Array.subArray<Nat8>(inputArray, 96, 32);
        // Calculate result
        // Modified from https://github.com/av1ctor/evm-txs.mo/blob/main/src/Address.mo
        let signature = Array.append<Nat8>(r, s);
        let recoveryId = v[31];
        let message = hash;
        let context = Ecmult.ECMultContext(null);
        var publicKeyArray = [] : [Nat8];
        switch(Signature.parse_standard(signature)) {
            case (#ok(signatureParsed)) {
                switch(RecoveryId.parse(recoveryId)) {
                    case (#ok(recoveryIdParsed)) {
                        let messageParsed = Message.parse(message);
                        switch(Ecdsa.recover_with_context(
                            messageParsed, signatureParsed, recoveryIdParsed, context)) {
                            case (#ok(publicKey)) {
                                publicKeyArray := publicKey.serialize_compressed();
                            };
                            case (#err(msg)) {
                                return ecRecoverError(exCon, exVar);
                            };
                        };
                    };
                    case (#err(msg)) {
                        return ecRecoverError(exCon, exVar);
                    };
                };
            };
            case (#err(msg)) {
                return ecRecoverError(exCon, exVar);
            };
        };
        var sha = Sha3.Keccak(256);
        sha.update(publicKeyArray);
        let keyHashArray = sha.finalize();
        let addressArray = Array.subArray<Nat8>(keyHashArray, 12, 20);
        let zeroArray = Array.freeze<Nat8>(Array.init<Nat8>(12, 0));
        let result = Blob.fromArray(Array.append<Nat8>(zeroArray, addressArray));
        // Calculate gas
        let newGas: Int = exVar.totalGas - 3000;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        exVar.returnData := Option.make(result);
        exVar
    };

    let pc_02_SHA2_256 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Calculate result
        let result = Sha256.fromBlob(#sha256, exCon.calldata);
        // Calculate gas
        let data_word_size = (exCon.calldata.size() + 31) / 32;
        let newGas: Int = exVar.totalGas - 60 - 12 * data_word_size;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        exVar.returnData := Option.make(result);
        exVar
    };

    let pc_03_RIPEMD_160 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Derive input data from calldata
        let data = Blob.toArray(exCon.calldata);
        // Calculate result
        let digest : Ripemd160.Digest = Ripemd160.Digest();
        digest.write(data);
        let resultArray : [Nat8] = digest.sum();
        let resultArray2 = Array.append<Nat8>([0,0,0,0,0,0,0,0,0,0,0,0], resultArray);
        // Calculate gas
        let data_word_size = (exCon.calldata.size() + 31) / 32;
        let newGas: Int = exVar.totalGas - 600 - 120 * data_word_size;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        let result = Blob.fromArray(resultArray2);
        exVar.returnData := Option.make(result);
        exVar
    };

    let pc_04_identity = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Calculate result
        let result = exCon.calldata;
        // Calculate gas
        let data_word_size = (exCon.calldata.size() + 31) / 32;
        let newGas: Int = exVar.totalGas - 15 - 3 * data_word_size;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        exVar.returnData := Option.make(result);
        exVar
    };

    let pc_05_modexp = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Not completed yet
        exVar
    };

    let pc_06_ecAdd = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Not completed yet
        exVar
    };

    let pc_07_ecMul = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Not completed yet
        exVar
    };

    let pc_08_ecPairing = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Not completed yet
        exVar
    };

    let pc_09_blake2f = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Not completed yet
        exVar
    };


    public let callPreCompile: PreCompile = [
            pc_00_,
            pc_01_ecRecover,
            pc_02_SHA2_256,
            pc_03_RIPEMD_160,
            pc_04_identity,
            pc_05_modexp,
            pc_06_ecAdd,
            pc_07_ecMul,
            pc_08_ecPairing,
            pc_09_blake2f
    ];

}