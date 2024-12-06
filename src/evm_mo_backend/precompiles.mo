import Sha256 "mo:sha2/Sha256"; // see https://mops.one/sha2
import T "types";

module {
    
    type PreCompile = [(T.ExecutionContext, T.ExecutionVariables, T.Engine) -> (T.ExecutionContext, T.ExecutionVariables)];

    let pc_00_ = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Unused function
        (exCon, exVar)
    };

    let pc_01_ecRecover = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
    };

    let pc_02_SHA2_256 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
    };

    let pc_03_RIPEMD_160 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
    };

    let pc_04_identity = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
    };

    let pc_05_modexp = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
    };

    let pc_06_ecAdd = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
    };

    let pc_07_ecMul = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
    };

    let pc_08_ecPairing = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
    };

    let pc_09_blake2f = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : (T.ExecutionContext, T.ExecutionVariables) {
        // Not completed yet
        (exCon, exVar)
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