// Modified from https://datatracker.ietf.org/doc/html/rfc7693

import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";
import Array "mo:base/Array";

module {
    // Constants
    let W = 64; // Word size
    let R1: Nat64 = 32; // Rotation constants
    let R2: Nat64 = 24;
    let R3: Nat64 = 16;
    let R4: Nat64 = 63;
    let IV: [Nat64] = [
       0x6A09E667F3BCC908, 0xBB67AE8584CAA73B,
       0x3C6EF372FE94F82B, 0xA54FF53A5F1D36F1,
       0x510E527FADE682D1, 0x9B05688C2B3E6C1F,
       0x1F83D9ABFB41BD6B, 0x5BE0CD19137E2179
    ];

    let SIGMA: [[Nat]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
        [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
        [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
        [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
        [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
        [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
        [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
        [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
        [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3]
    ];

    // G Function
    func G(v: [var Nat64], a: Nat, b: Nat, c: Nat, d: Nat, x: Nat64, y: Nat64): [var Nat64] {

        v[a] := v[a] +% v[b] +% x;
        v[d] := Nat64.bitrotRight(v[d] ^ v[a], R1);
        v[c] := v[c] +% v[d];
        v[b] := Nat64.bitrotRight(v[b] ^ v[c], R2);
        v[a] := v[a] +% v[b] +% y;
        v[d] := Nat64.bitrotRight(v[d] ^ v[a], R3);
        v[c] := v[c] +% v[d];
        v[b] := Nat64.bitrotRight(v[b] ^ v[c], R4);

        return v;
    };

    // Compression function F
    public func F(rounds: Nat, h: [Nat64], m: [Nat64], t: [Nat64], f: Nat8): [Nat64] {
        var v = Array.thaw<Nat64>(Array.append<Nat64>(h, IV));

        v[12] := v[12] ^ t[0];
        v[13] := v[13] ^ t[1];

        if (f == 1) {
            v[14] := v[14] ^ 0xFFFFFFFFFFFFFFFF;
        };

        for (i in Iter.range(0, rounds - 1)) {
            let s = SIGMA[i % 10];
            v := G(v, 0, 4, 8, 12, m[s[0]], m[s[1]]);
            v := G(v, 1, 5, 9, 13, m[s[2]], m[s[3]]);
            v := G(v, 2, 6, 10, 14, m[s[4]], m[s[5]]);
            v := G(v, 3, 7, 11, 15, m[s[6]], m[s[7]]);

            v := G(v, 0, 5, 10, 15, m[s[8]], m[s[9]]);
            v := G(v, 1, 6, 11, 12, m[s[10]], m[s[11]]);
            v := G(v, 2, 7, 8, 13, m[s[12]], m[s[13]]);
            v := G(v, 3, 4, 9, 14, m[s[14]], m[s[15]]);
        };

        let newH = Array.init<Nat64>(8, 0);
        for (i in Iter.range(0, 7)) {
            newH[i] := h[i] ^ v[i] ^ v[i + 8];
        };

        return Array.freeze<Nat64>(newH);
    };
};
