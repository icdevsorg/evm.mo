import T "./types";
import Trie "mo:base/Trie";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Sha3 "mo:sha3/"; // see https://mops.one/sha3
import Result "mo:base/Result";
import Int "mo:base/Int";


module {

  public func key(n: Blob) : Trie.Key<Blob> { { hash = Blob.hash(n); key = n } };


  public func getCodeHash(code: [T.OpCode]) : Blob {
    var sha = Sha3.Keccak(256);
    sha.update(code);
    Blob.fromArray(sha.finalize());
  };

  // Helper to pop n values from the stack
  public func popN(stack : T.EVMStack, n: Nat) : ?[Nat] {
    
    var i = 0;
    var ok = true;
    let b = Buffer.Buffer<Nat>(n);
    while (i < n and ok) {
      
      switch (stack.pop()) {
        case (#ok(v)) { b.add(v); i += 1; };
        case (#err(_)) { ok := false; };
      }
    };
    if (ok) { ?Buffer.toArray(b) } else { null };
  };

  // Helper to push a value and deduct gas
  public func pushAndGas(exVar: T.ExecutionVariables, value: Nat, gasCost: Nat) : Result.Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.push(value)) {
      case (#err(e)) { return #err(e) };
      case (#ok(_)) {
        let newGas: Int = exVar.totalGas - gasCost;
        if (newGas < 0) {
          return #err("Out of gas")
        } else {
          exVar.totalGas := Int.abs(newGas);
          return #ok(exVar);
        }
      }
    }
  };

  
}