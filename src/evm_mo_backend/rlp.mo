import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import RLP "mo:rlp-motoko";
import RLPTypes "mo:rlp-motoko/types";

module {
  public func encodeAccount(nonce: Nat, balance: Nat, storageRoot: Blob, codeHash: Blob) : Blob {

    let buffer = Buffer.Buffer<RLPTypes.Input>(4);

    let input1: RLPTypes.Input = #number(balance);

    let input2: RLPTypes.Input = #number(nonce);

    let storageIter = storageRoot.vals();
    let input3: RLPTypes.Input = #Uint8Array(Buffer.fromIter<Nat8>(storageIter));

    let codeIter = codeHash.vals();
    let input4: RLPTypes.Input = #Uint8Array(Buffer.fromIter<Nat8>(codeIter));

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

  public func decodeAccount(input: Blob): (Nat, Nat, Blob, Blob) {
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
        // decode nonce
        let element1 = outputBuffer.get(0);
        var output1: Nat = 0;
        switch(element1) {
          case(#Uint8Array e1) {
            var pos: Nat = e1.size();
            var result: Nat = 0;
            for (val: Nat8 in e1.vals()) {
              pos -= 1;
              result += Nat8.toNat(val) * (256 ** pos);
            };
            output1 := result;
          };
          case(#Nested _) {Debug.trap("error")};
        };

        // decode balance
        let element2 = outputBuffer.get(1);
        var output2: Nat = 0;
        switch(element2) {
          case(#Uint8Array e2) {
            var pos: Nat = e2.size();
            var result: Nat = 0;
            for (val: Nat8 in e2.vals()) {
              pos -= 1;
              result += Nat8.toNat(val) * (256 ** pos);
            };
            output2 := result;
          };
          case(#Nested _) {Debug.trap("error")};
        };

        // decode storageRoot
        let element3 = outputBuffer.get(2);
        var output3: Blob = "";
        switch(element3) {
          case(#Uint8Array e3) {
            let arr = Buffer.toArray<Nat8>(e3);
            output3 := Blob.fromArray(arr);
          };
          case(#Nested _) {Debug.trap("error")};
        };

        // decode codeHash
        let element4 = outputBuffer.get(3);
        var output4: Blob = "";
        switch(element4) {
          case(#Uint8Array e4) {
            let arr = Buffer.toArray<Nat8>(e4);
            output4 := Blob.fromArray(arr);
          };
          case(#Nested _) {Debug.trap("error")};
        };
        
        (output1, output2, output3, output4);
      };
    };
  };
}