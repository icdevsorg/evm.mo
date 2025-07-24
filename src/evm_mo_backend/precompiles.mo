import Int "mo:base/Int";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import EvmTxsAddress "mo:evm-txs/Address";
import ArrayUtils "mo:evm-txs/utils/ArrayUtils";
import Ecmult "mo:libsecp256k1/core/ecmult";
import PreG "pre_g";
import Sha256 "mo:sha2/Sha256";
import Sha3 "mo:sha3/";
import Ripemd160 "mo:bitcoin/Ripemd160";
import Bn128 "bn128";
import Blake2 "blake2";
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
            let t1 = t;
            let a1 = a;
            t := b % t;
            a := u;
            b := t1;
            u := a1 + (m - q) * u % m;
        };
        return if (b == 1) a % m else 0; // Inverse exists only if greatest common denominator == 1
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

    func ecPairingError(exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : T.ExecutionVariables {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
    };

    func blake2fError(exCon: T.ExecutionContext, exVar: T.ExecutionVariables) : T.ExecutionVariables {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
    };

    func arrayToNat(arr: [Nat8]) : Nat {
        var pos: Nat = arr.size();
        var data: Nat = 0;
        for (byte: Nat8 in arr.vals()) {
            pos -= 1;
            data += Nat8.toNat(byte) * (256 ** pos);
        };
        data
    };

    // Function to convert Nat8 array to an array of little-endian 8-byte words
    func arrayN8toN64LE(arr: [Nat8]) : [Nat64] {
        var output = [] : [Nat64];
        if (arr.size() < 8) {
            return output;
        };
        for (i in Iter.range(0, arr.size() / 8 - 1)) {
            let subarr = Array.subArray<Nat8>(arr, i * 8, 8);
            var x = 0;
            for (j in Iter.range(0, 7)) {
                x += Nat8.toNat(subarr[j]) * 256 ** j;
            };
            output := Array.append<Nat64>(output, [Nat64.fromNat(x)]);
        };
        output
    };

    func bit_length(num: Nat) : Nat {
        if (num == 0) { return 1; };
        var bits = 0;
        var num_ = num;
        while (num_ > 0) {
            num_ /= 2;
            bits += 1;
        };
        bits
    };

    // Pre-compiled contract functions

    let pc_00_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Unused function, included as a place filler and as a template in case further precompiles need to be added
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
        var inputArray = Blob.toArray(exCon.calldata);
        if (inputArray.size() < 128) {
            inputArray := Array.append<Nat8>(inputArray, Array.freeze<Nat8>(Array.init<Nat8>(inputArray.size() - 128, 0)));
        };
        let hash = Array.subArray<Nat8>(inputArray, 0, 32);
        let v = Array.subArray<Nat8>(inputArray, 32, 32);
        let r = Array.subArray<Nat8>(inputArray, 64, 32);
        let s = Array.subArray<Nat8>(inputArray, 96, 32);
        // Calculate result
        if (Array.subArray<Nat8>(v, 0, 31) != Array.freeze<Nat8>(Array.init<Nat8>(31, 0))) {
            return ecRecoverError(exCon, exVar);
        };
        let signature = Array.append<Nat8>(r, s);
        let recoveryId = v[31];
        let message = hash;
        let context = Ecmult.ECMultContext(?Ecmult.loadPreG(PreG.pre_g));
        var addressArray = [] : [Nat8];
        let response = EvmTxsAddress.recover(signature, recoveryId - 27, message, context);
        switch (response) {
            case (#ok(addr)) {
                addressArray := ArrayUtils.fromText(addr);
            };
            case (#err(_)) {
                return ecRecoverError(exCon, exVar);
            };
        };
        let zeroArray = Array.freeze<Nat8>(Array.init<Nat8>(12, 0));
        let result = Blob.fromArray(Array.append<Nat8>(zeroArray, addressArray));
        // Calculate gas
        let newGas: Int = exVar.totalGas - 3000;
        if (newGas < 0) {
            Debug.print("out of gas");
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
        // Derive input data from calldata
        var inputArray = Blob.toArray(exCon.calldata);
        if (inputArray.size() < 96) {
            inputArray := Array.append<Nat8>(inputArray, Array.freeze<Nat8>(Array.init<Nat8>(inputArray.size() - 96, 0)));
        };
        var BSize: Nat = 0;
        var ESize: Nat = 0;
        var MSize: Nat = 0;
        var B: Nat = 0;
        var E: Nat = 0;
        var M: Nat = 0;
        var pos: Nat = 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 0, 32).vals()) {
          pos -= 1;
          BSize += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 32, 32).vals()) {
          pos -= 1;
          ESize += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 64, 32).vals()) {
          pos -= 1;
          MSize += Nat8.toNat(byte) * (256 ** pos);
        };
        let expectedSize = 96 + BSize + ESize + MSize;
        if (inputArray.size() < expectedSize) {
            inputArray := Array.append<Nat8>(inputArray, Array.freeze<Nat8>(Array.init<Nat8>(inputArray.size() - expectedSize, 0)));
        };
        pos := BSize;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 96, BSize).vals()) {
          pos -= 1;
          B += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := ESize;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 96 + BSize, ESize).vals()) {
          pos -= 1;
          E += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := MSize;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 96 + BSize + ESize, MSize).vals()) {
          pos -= 1;
          M += Nat8.toNat(byte) * (256 ** pos);
        };
        // Calculate result
        var result: Nat = 1;
        var b_ = B;
        var e_ = E;
        b_ := b_ % M;
        while (e_ > 0){
            if (e_ % 2 == 1) result := (result * b_) % M;
            e_ := e_ / 2;
            b_ := (b_ * b_) % M;
        };
        let resultBuffer = Buffer.Buffer<Nat8>(8);
        for (i in Iter.revRange(MSize - 1, 0)) {
            resultBuffer.add(Nat8.fromNat((result % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let resultBlob = Blob.fromArray(Buffer.toArray<Nat8>(resultBuffer));
        // Calculate gas
        let max_length = Nat.max(BSize, MSize);
        let words = (max_length + 7) / 8;
        let multiplication_complexity = words ** 2;
        var iteration_count = 0;
        if (ESize <= 32 and E == 0) { iteration_count := 0; };
        if (ESize <= 32 and E > 0) { iteration_count := bit_length(E) - 1 };
        if (ESize > 32) { iteration_count := (8 * (ESize - 32)) + bit_length(Nat.min(E, 2**256 - 1) - 1) };
        let calculate_iteration_count = Nat.max(iteration_count, 1);
        let dynamic_gas = Nat.max(200, multiplication_complexity * calculate_iteration_count / 3);        
        let newGas: Int = exVar.totalGas - dynamic_gas;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        exVar.returnData := Option.make(resultBlob);
        exVar
    };

    let pc_06_ecAdd = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Derive input data from calldata
        var inputArray = Blob.toArray(exCon.calldata);
        if (inputArray.size() < 128) {
            inputArray := Array.append<Nat8>(inputArray, Array.freeze<Nat8>(Array.init<Nat8>(inputArray.size() - 128, 0)));
        };
        var x1: Nat = 0;
        var y1: Nat = 0;
        var x2: Nat = 0;
        var y2: Nat = 0;
        var pos: Nat = 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 0, 32).vals()) {
          pos -= 1;
          x1 += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 32, 32).vals()) {
          pos -= 1;
          y1 += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 64, 32).vals()) {
          pos -= 1;
          x2 += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 96, 32).vals()) {
          pos -= 1;
          y2 += Nat8.toNat(byte) * (256 ** pos);
        };
        // Calculate result
        let P = Option.make((x1, y1));
        let Q = Option.make((x2, y2));
        let p = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        let resultPoint = pointAdd(P, Q, p);
        var x = 0;
        var y = 0;
        switch (resultPoint) {
            case (?R) {
                x := R.0;
                y := R.1;
            };
            case (null) {}; // point at infinity
        };
        // Calculate gas
        let newGas: Int = exVar.totalGas - 150;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        let resultBuffer = Buffer.Buffer<Nat8>(32);
        for (i in Iter.revRange(31, 0)) {
            resultBuffer.add(Nat8.fromNat((x % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        for (i in Iter.revRange(31, 0)) {
            resultBuffer.add(Nat8.fromNat((y % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let result = Blob.fromArray(Buffer.toArray<Nat8>(resultBuffer));
        exVar.returnData := Option.make(result);
        exVar
    };

    let pc_07_ecMul = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Derive input data from calldata
        var inputArray = Blob.toArray(exCon.calldata);
        if (inputArray.size() < 96) {
            inputArray := Array.append<Nat8>(inputArray, Array.freeze<Nat8>(Array.init<Nat8>(inputArray.size() - 96, 0)));
        };
        var x1: Nat = 0;
        var y1: Nat = 0;
        var s: Nat = 0;
        var pos: Nat = 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 0, 32).vals()) {
          pos -= 1;
          x1 += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 32, 32).vals()) {
          pos -= 1;
          y1 += Nat8.toNat(byte) * (256 ** pos);
        };
        pos := 32;
        for (byte: Nat8 in Array.subArray<Nat8>(inputArray, 64, 32).vals()) {
          pos -= 1;
          s += Nat8.toNat(byte) * (256 ** pos);
        };
        // Calculate result
        let P = Option.make((x1, y1));
        let p = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        let resultPoint = scalarMultiply(s, P, p);
        var x = 0;
        var y = 0;
        switch (resultPoint) {
            case (?Q) {
                x := Q.0;
                y := Q.1;
            };
            case (null) {}; // point at infinity
        };
        // Calculate gas
        let newGas: Int = exVar.totalGas - 6000;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        let resultBuffer = Buffer.Buffer<Nat8>(32);
        for (i in Iter.revRange(31, 0)) {
            resultBuffer.add(Nat8.fromNat((x % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        for (i in Iter.revRange(31, 0)) {
            resultBuffer.add(Nat8.fromNat((y % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        let result = Blob.fromArray(Buffer.toArray<Nat8>(resultBuffer));
        exVar.returnData := Option.make(result);
        exVar
    };

    let pc_08_ecPairing = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        // Get input data from calldata
        let inputArray = Blob.toArray(exCon.calldata);
        let inputLength = inputArray.size();
        if (inputLength % 192 != 0) {
            return ecPairingError(exCon, exVar);
        };
        // Calculate gas
        let dynamic_gas = (inputLength / 192) * 34000;
        let newGas: Int = exVar.totalGas - 45000 - dynamic_gas;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Calculate result
        var x1 = 0; var y1 = 0; var x2_i = 0;
        var x2_r = 0; var y2_i = 0; var y2_r = 0;
        let field_modulus = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        let curve_order = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        var exponent = Bn128.FQ12_one;
        let b2 = [
            19485874751759354771024239261021720505790618469301721065564631296452457478373,
            266929791119991161246907387137283842545076965332900288569378510910307636690
        ];
        var result = "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob;
        for (i in Iter.range(0, inputLength / 192 - 1)) {
            let startIndex = i * 192;
            let x1_bytes = Array.subArray<Nat8>(inputArray, startIndex, 32);
            let y1_bytes = Array.subArray<Nat8>(inputArray, startIndex + 32, 32);
            let x2_i_bytes = Array.subArray<Nat8>(inputArray, startIndex + 64, 32);
            let x2_r_bytes = Array.subArray<Nat8>(inputArray, startIndex + 96, 32);
            let y2_i_bytes = Array.subArray<Nat8>(inputArray, startIndex + 128, 32);
            let y2_r_bytes = Array.subArray<Nat8>(inputArray, startIndex + 160, 32);
            x1 := arrayToNat(x1_bytes);
            y1 := arrayToNat(y1_bytes);
            x2_i := arrayToNat(x2_i_bytes);
            x2_r := arrayToNat(x2_r_bytes);
            y2_i := arrayToNat(y2_i_bytes);
            y2_r := arrayToNat(y2_r_bytes);
            for (val in Iter.fromArray([x1, y1, x2_i, x2_r, y2_i, y2_r])) {
                if (val > field_modulus) {
                    Debug.print("Point co-ordinate exceeds field modulus");
                    return ecPairingError(exCon, exVar);
                };
            };
            var p1 = (1, 1, 0);
            if (x1 != 0 or y1 != 0) {
                p1 := (x1, y1, 1);
                if (not Bn128.isOnCurve(p1, 3)) {
                    Debug.print("Point 1 is not on curve");
                    return ecPairingError(exCon, exVar);
                };
            };
            let fq2_x = [x2_r, x2_i];
            let fq2_y = [y2_r, y2_i];
            var p2 = (Bn128.FQ2_one, Bn128.FQ2_one, Bn128.FQ2_zero);
            if (fq2_x != Bn128.FQ2_zero or fq2_y != Bn128.FQ2_zero) {
                p2 := (fq2_x, fq2_y, Bn128.FQ2_one);
                if (not Bn128.isOnCurveFq2(p2, b2)) {
                    Debug.print("Point 2 is not on curve");
                    return ecPairingError(exCon, exVar);
                };
            };
            let pairing = Bn128.pairing(p2, p1, false);
            exponent := Bn128.FQ12(exponent).mul(pairing);
        };
        if (Bn128.finalExponentiate(exponent) == Bn128.FQ12_one) {
            result := "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\01";
        };
        // Place result in return data
        exVar.returnData := Option.make(result);
        exVar
    };

    let pc_09_blake2f = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : T.ExecutionVariables {
        var inputArray = Blob.toArray(exCon.calldata);
        if (inputArray.size() != 213) {
            return blake2fError(exCon, exVar);
        };
        let rounds = arrayToNat(Array.subArray<Nat8>(inputArray, 0, 4));
        let hArr = Array.subArray<Nat8>(inputArray, 4, 64);
        let h = arrayN8toN64LE(hArr);
        let mArr = Array.subArray<Nat8>(inputArray, 68, 128);
        let m = arrayN8toN64LE(mArr);
        let tArr = Array.subArray<Nat8>(inputArray, 196, 16);
        let t = arrayN8toN64LE(tArr);
        let f = inputArray[212];
        // Calculate result
        // Returns an array of little-endian 8-byte words
        let resultArrN64 = Blake2.F(rounds, h, m, t, f);
        // Calculate gas
        let newGas: Int = exVar.totalGas - rounds;
        if (newGas < 0) {
            exVar.programCounter := exCon.code.size() + 2;
            exVar.totalGas := 0;
            return exVar;
        } else {
            exVar.totalGas := Int.abs(newGas);
        };
        // Place result in return data
        let resultBuffer = Buffer.Buffer<Nat8>(8);
        for (i in Iter.range(0,7)) {
            let val = Nat64.toNat(resultArrN64[i]);
            for (j in Iter.range(0,7)) {
                resultBuffer.add(Nat8.fromNat(val / 256 ** j % 256));
            };
        };
        let result = Blob.fromArray(Buffer.toArray<Nat8>(resultBuffer));
        exVar.returnData := Option.make(result);
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