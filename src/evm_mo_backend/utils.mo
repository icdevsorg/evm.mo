import Types "./types";
import Trie "mo:base/Trie";
import Blob "mo:base/Blob";

module {

   public func key(n: Blob) : Trie.Key<Blob> { { hash = Blob.hash(n); key = n } };
}