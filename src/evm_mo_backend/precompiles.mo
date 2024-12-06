import Int "mo:base/Int";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Sha256 "mo:sha2/Sha256"; // see https://mops.one/sha2
import Ripemd160 "mo:bitcoin/Ripemd160";
import Affine "mo:bitcoin/ec/Affine";
import Curves "mo:bitcoin/ec/Curves";
import T "types";

module {
    
    type PreCompile = [(T.ExecutionContext, T.ExecutionVariables, T.Engine) -> T.ExecutionVariables];

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
        // Not completed yet
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