import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Option "mo:base/Option";
import T "types";
import RLP "mo:rlp-motoko";
import RLPTypes "mo:rlp-motoko/types";

module {
  type Trie<K, V> = Trie.Trie<K, V>;
  type Key<K> = Trie.Key<K>;
  func key(n: [Nat8]) : Key<[Nat8]> { { hash = Blob.hash(Blob.fromArray(n)); key = n } };

  public func encodeAccount(nonce: Nat, balance: Nat, storage: T.Storage, code: [T.OpCode]) : Blob {

    let buffer = Buffer.Buffer<RLPTypes.Input>(4);

    let input1: RLPTypes.Input = #number(balance);

    let input2: RLPTypes.Input = #number(nonce);

    let storageBuffer = Buffer.Buffer<RLPTypes.Input>(8);
    let storageIter = Trie.iter(storage);
    for ((k,v) in storageIter) {
      let element = Buffer.Buffer<RLPTypes.Input>(2);
      var kpos: Nat = k.size();
      var k_: Nat = 0;
      for (byte in Iter.fromArray<Nat8>(k)) {
        kpos -= 1;
        k_ += Nat8.toNat(byte) * (256 ** kpos);
      };
      element.add(#number(k_));
      var vpos: Nat = v.size();
      var v_: Nat = 0;
      for (byte in Iter.fromArray<Nat8>(v)) {
        vpos -= 1;
        v_ += Nat8.toNat(byte) * (256 ** vpos);
      };
      element.add(#number(v_));
      storageBuffer.add(#List(element));
    };
    let input3: RLPTypes.Input = #List(storageBuffer);

    let codeBuffer = Buffer.Buffer<RLPTypes.Input>(8);
    let codeIter = Iter.fromArray<(Nat8, ?Blob)>(code);
    for ((n, b) in codeIter) {
      let element = Buffer.Buffer<RLPTypes.Input>(2);
      element.add(#number(Nat8.toNat(n)));
      switch (b) {
        case (null) {
          element.add(#number(0));
        };
        case (?bytes) {
          for (byte: Nat8 in bytes.vals()) {
            element.add(#number(Nat8.toNat(byte)))
          };
        };
      };
      codeBuffer.add(#List(element));
    };
    let input4: RLPTypes.Input = #List(codeBuffer);

    buffer.add(input1);
    buffer.add(input2);
    buffer.add(input3);
    buffer.add(input4);

    let encoded: RLPTypes.Uint8Array = switch(RLP.encode(#List(buffer))) {
      case(#ok(val)) { val };
      case(#err(_)) { 
        Debug.trap("RLP encoding trapped");
      };
    };
    let encodedArray = Buffer.toArray<Nat8>(encoded);
    let encodedBlob = Blob.fromArray(encodedArray);
    encodedBlob;
  };

  public func decodeAccount(input: Blob): (Nat, Nat, T.Storage, [T.OpCode]) {
    let inputArray = Blob.toArray(input);
    let decoded: RLPTypes.Decoded = switch(RLP.decode(#Uint8Array(Buffer.fromArray<Nat8>(inputArray)))) {
      case(#ok(val)) { val };
      case(#err(_)) { 
        Debug.trap("RLP decoding trapped");
      };
    };
    switch(decoded) {
      case(#Uint8Array _) {Debug.trap("RLP decoding returned #Uint8Array")};
      case(#Nested outputBuffer) {
        let element1 = outputBuffer.get(0);
        var output1: Nat = 0;
        switch(element1) {
          case(#Uint8Array e1) {
            output1 := Nat8.toNat(e1.get(0));
          };
          case(#Nested _) {Debug.trap("error")};
        };

        let element2 = outputBuffer.get(1);
        var output2: Nat = 0;
        switch(element2) {
          case(#Uint8Array e2) {
            output2 := Nat8.toNat(e2.get(0));
          };
          case(#Nested _) {Debug.trap("error")};
        };

        let element3 = outputBuffer.get(2);
        var output3: T.Storage = Trie.empty();
        switch(element3) {
          case(#Uint8Array _) {Debug.trap("error")};
          case(#Nested e3) {
            Buffer.iterate<RLPTypes.Decoded>(e3, func (x) {
              // convert each to ([Nat8], [Nat8])
              var karr = Array.init<Nat8>(32,0);
              var varr = Array.init<Nat8>(32,0);
              switch(x) {
                case(#Uint8Array _) {Debug.trap("error")};
                case(#Nested kv) {
                  let k = kv.get(0);
                  let v = kv.get(1);
                  switch(k) {
                    case(#Uint8Array kbuf) {
                      let arr = Buffer.toArray<Nat8>(kbuf);
                      if (kbuf.size() < 32) {
                        let pad = Array.freeze<Nat8>(Array.init<Nat8>(32 - kbuf.size(), 0));
                        karr := Array.thaw<Nat8>(Array.append<Nat8>(arr, pad));
                      };
                    };
                    case(#Nested _) {Debug.trap("error")};
                  };
                  switch(v) {
                    case(#Uint8Array vbuf) {
                      let arr = Buffer.toArray<Nat8>(vbuf);
                      if (vbuf.size() < 32) {
                        let pad = Array.freeze<Nat8>(Array.init<Nat8>(32 - vbuf.size(), 0));
                        varr := Array.thaw<Nat8>(Array.append<Nat8>(arr, pad));
                      };
                    };
                    case(#Nested n) {Debug.trap("error")};
                  };
                };
              };
              // add to Trie
              let karr_ = Array.freeze<Nat8>(karr);
              let varr_ = Array.freeze<Nat8>(varr);
              output3 := Trie.replace(output3, key karr_, func(x: [Nat8], y: [Nat8]) : Bool {Array.equal(x, y, Nat8.equal)}, ?varr_).0;
            });
          };
        };

        let element4 = outputBuffer.get(3);
        let buf = Buffer.Buffer<(Nat8, ?Blob)>(8);
        switch(element4) {
          case(#Uint8Array u) {Debug.trap("error")};
          case(#Nested e4) {
            Buffer.iterate<RLPTypes.Decoded>(e4, func (x) {
              // convert each to (Nat8, ?Blob) and append to buf
              switch(x) {
                case(#Uint8Array nb) {
                  if (nb.size() == 2 and nb.get(1) == 0) {
                    buf.add((nb.get(0), null));
                  } else {
                    let n = nb.remove(0);
                    let b = Blob.fromArray(Buffer.toArray(nb));
                    buf.add((n, Option.make(b)));
                  };
                };
                case(#Nested n) {Debug.trap("error")}
              };
            });
          };
        };
        let output4 = Buffer.toArray<(Nat8, ?Blob)>(buf);
        (output1, output2, output3, output4);
      };
    };
  };
}