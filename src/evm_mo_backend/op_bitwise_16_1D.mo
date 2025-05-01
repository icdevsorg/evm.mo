import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import { equal } "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Vec "mo:vector"; // see https://github.com/research-ag/vector
import Map "mo:map/Map"; // see https://mops.one/map
import { bhash } "mo:map/Map";
import Sha256 "mo:sha2/Sha256"; // see https://mops.one/sha2
import Sha3 "mo:sha3/"; // see https://mops.one/sha3
import MPTrie "mo:merkle-patricia-trie/Trie"; // see https://github.com/f0i/merkle-patricia-trie.mo
import K "mo:merkle-patricia-trie/Key";
import V "mo:merkle-patricia-trie/Value";
import { encodeAccount; decodeAccount; encodeAddressNonce } "rlp"; // see https://github.com/relaxed04/rlp-motoko
import { callPreCompile } "precompiles";
import EVMStack "evmStack";
import T "types";
import { key; popN; pushAndGas; } "utils";

module {

  type Result<Ok, Err> = { #ok: Ok; #err: Err };

  

  public func op_16_AND (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let a1: Nat64 = Nat64.fromNat(a / 2**192);
        let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
        let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
        let a4: Nat64 = Nat64.fromNat(a % 2**64);
        let b1: Nat64 = Nat64.fromNat(b / 2**192);
        let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
        let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
        let b4: Nat64 = Nat64.fromNat(b % 2**64);
        let result = Nat64.toNat(a1 & b1) * 2**192 + Nat64.toNat(a2 & b2) * 2**128 + Nat64.toNat(a3 & b3) * 2**64 + Nat64.toNat(a4 & b4);
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_17_OR (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let a1: Nat64 = Nat64.fromNat(a / 2**192);
        let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
        let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
        let a4: Nat64 = Nat64.fromNat(a % 2**64);
        let b1: Nat64 = Nat64.fromNat(b / 2**192);
        let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
        let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
        let b4: Nat64 = Nat64.fromNat(b % 2**64);
        let result = Nat64.toNat(a1 | b1) * 2**192 + Nat64.toNat(a2 | b2) * 2**128 + Nat64.toNat(a3 | b3) * 2**64 + Nat64.toNat(a4 | b4);
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_18_XOR (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let b = vals[1];
        let a1: Nat64 = Nat64.fromNat(a / 2**192);
        let a2: Nat64 = Nat64.fromNat((a / 2**128) % 2**64);
        let a3: Nat64 = Nat64.fromNat((a / 2**64) % 2**64);
        let a4: Nat64 = Nat64.fromNat(a % 2**64);
        let b1: Nat64 = Nat64.fromNat(b / 2**192);
        let b2: Nat64 = Nat64.fromNat((b / 2**128) % 2**64);
        let b3: Nat64 = Nat64.fromNat((b / 2**64) % 2**64);
        let b4: Nat64 = Nat64.fromNat(b % 2**64);
        let result = Nat64.toNat(a1 ^ b1) * 2**192 + Nat64.toNat(a2 ^ b2) * 2**128 + Nat64.toNat(a3 ^ b3) * 2**64 + Nat64.toNat(a4 ^ b4);
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_19_NOT (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 1)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let a = vals[0];
        let result = (2**256 - 1) - a;
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_1A_BYTE (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let i = vals[0];
        let x = vals[1];
        var result = 0;
        if (i < 32) {
          let num = x / (256 ** (31 - i));
          result := num % 256;
        };
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_1B_SHL (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let shift = vals[0];
        let value = vals[1];
        let result = (value * (2 ** shift)) % 2**256;
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_1C_SHR (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let shift = vals[0];
        let value = vals[1];
        let result = (value / (2 ** shift));
        return pushAndGas(exVar, result, 3);
      }
    }
  };

  public func op_1D_SAR (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (popN(exVar.stack, 2)) {
      case null { return #err("Stack underflow") };
      case (?vals) {
        let shift = vals[0];
        let value = vals[1];
        var result = (value / (2 ** shift));
        if (value >= 2**255) {
          result += (2**256 - (2 ** (256 - shift)));
        };
        return pushAndGas(exVar, result, 3);
      }
    }
  };
}