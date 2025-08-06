import Blob "mo:base/Blob";
import Trie "mo:base/Trie";
import Sha3 "mo:sha3/";
import MPTrie "mo:merkle-patricia-trie/Trie";
import K "mo:merkle-patricia-trie/Key";
import V "mo:merkle-patricia-trie/Value";
import T "types";
import { key } "utils";

module {

  // Helper Functions for EVM Operations
  // These utilities are used by various opcode implementations

  // Calculate hash of code
  public func getCodeHash(code: [T.OpCode]) : Blob {
    var sha = Sha3.Keccak(256);
    sha.update(code);
    Blob.fromArray(sha.finalize());
  };

  // Calculate storage root hash
  public func getStorageRoot(storage: T.Storage) : Blob {
    var trie = MPTrie.init();
    let iter = Trie.iter(storage);
    for ((k,v) in iter) {
      trie := MPTrie.put(trie, K.fromKeyBytes(Blob.toArray(k)), V.fromArray(v));
    };
    MPTrie.hash(trie);
  };

}
