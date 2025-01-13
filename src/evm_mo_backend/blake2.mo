// Modified from https://github.com/keep-network/blake2b/blob/master/compression/f.go
// See https://github.com/keep-network/blake2b/blob/master/LICENSE for licence and conditions

import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";

module{

    // F is a compression function for BLAKE2b. It takes as an argument the state
    // vector `h`, message block vector `m`, offset counter `t`, final
    // block indicator flag `f`, and number of rounds `rounds`. The state vector
    // provided as the first parameter is modified by the function.
    public func F(rounds: Nat, h: [Nat64], m: [Nat64], t: [Nat64], f: Nat8) : [Nat64] {

        // IV is an initialization vector for BLAKE2b
        let IV: [Nat64] = [
            0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
            0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
        ];

        // The precomputed values for BLAKE2b
        // There are 10 16-byte arrays - one for each round
        // The entries are calculated from the sigma constants
        let precomputed: [[Nat]] = [
            [0, 2, 4, 6, 1, 3, 5, 7, 8, 10, 12, 14, 9, 11, 13, 15],
            [14, 4, 9, 13, 10, 8, 15, 6, 1, 0, 11, 5, 12, 2, 7, 3],
            [11, 12, 5, 15, 8, 0, 2, 13, 10, 3, 7, 9, 14, 6, 1, 4],
            [7, 3, 13, 11, 9, 1, 12, 14, 2, 5, 4, 15, 6, 10, 0, 8],
            [9, 5, 2, 10, 0, 7, 4, 15, 14, 11, 6, 3, 1, 12, 8, 13],
            [2, 6, 0, 8, 12, 10, 11, 3, 4, 7, 15, 1, 13, 5, 14, 9],
            [12, 1, 14, 4, 5, 15, 13, 10, 0, 6, 9, 8, 7, 3, 2, 11],
            [13, 7, 12, 3, 11, 14, 1, 9, 5, 15, 8, 2, 0, 4, 6, 10],
            [6, 14, 11, 0, 15, 9, 3, 8, 12, 13, 1, 10, 2, 7, 4, 5],
            [10, 8, 7, 1, 2, 4, 6, 5, 15, 9, 3, 13, 11, 14, 12, 0]
        ];

        let c0 = t[0];
        let c1 = t[1];
        var v0 = h[0];
        var v1 = h[1];
        var v2 = h[2];
        var v3 = h[3];
        var v4 = h[4];
        var v5 = h[5];
        var v6 = h[6];
        var v7 = h[7];
        var v8 = IV[0];
        var v9 = IV[1];
        var v10 = IV[2];
        var v11 = IV[3];
        var v12 = IV[4];
        var v13 = IV[5];
        var v14 = IV[6];
        var v15 = IV[7];

        v12 := v12 ^ c0;
        v13 := v13 ^ c1;

        if (f == 1) {
            v14 := v14 ^ 0xffffffffffffffff;
        };

        for (j in Iter.range(1, rounds)) {
            let s = precomputed[j%10];

            v0 += m[s[0]];
            v0 += v4;
            v12 := v12 ^ v0;
            v12 := Nat64.bitrotRight(v12, 32);
            v8 += v12;
            v4 := v4 ^ v8;
            v4 := Nat64.bitrotRight(v4, 24);
            v1 += m[s[1]];
            v1 += v5;
            v13 := v13 ^ v1;
            v13 := Nat64.bitrotRight(v13, 32);
            v9 += v13;
            v5 := v5 ^ v9;
            v5 := Nat64.bitrotRight(v5, 24);
            v2 += m[s[2]];
            v2 += v6;
            v14 := v14 ^ v2;
            v14 := Nat64.bitrotRight(v14, 32);
            v10 += v14;
            v6 := v6 ^ v10;
            v6 := Nat64.bitrotRight(v6, 24);
            v3 += m[s[3]];
            v3 += v7;
            v15 := v15 ^ v3;
            v15 := Nat64.bitrotRight(v15, 32);
            v11 += v15;
            v7 := v7 ^ v11;
            v7 := Nat64.bitrotRight(v7, 24);

            v0 += m[s[4]];
            v0 += v4;
            v12 := v12 ^ v0;
            v12 := Nat64.bitrotRight(v12, 16);
            v8 += v12;
            v4 := v4 ^ v8;
            v4 := Nat64.bitrotRight(v4, 63);
            v1 += m[s[5]];
            v1 += v5;
            v13 := v13 ^ v1;
            v13 := Nat64.bitrotRight(v13, 16);
            v9 += v13;
            v5 := v5 ^ v9;
            v5 := Nat64.bitrotRight(v5, 63);
            v2 += m[s[6]];
            v2 += v6;
            v14 := v14 ^ v2;
            v14 := Nat64.bitrotRight(v14, 16);
            v10 += v14;
            v6 := v6 ^ v10;
            v6 := Nat64.bitrotRight(v6, 63);
            v3 += m[s[7]];
            v3 += v7;
            v15 := v15 ^ v3;
            v15 := Nat64.bitrotRight(v15, 16);
            v11 += v15;
            v7 := v7 ^ v11;
            v7 := Nat64.bitrotRight(v7, 63);

            v0 += m[s[8]];
            v0 += v5;
            v15 := v15 ^ v0;
            v15 := Nat64.bitrotRight(v15, 32);
            v10 += v15;
            v5 := v5 ^ v10;
            v5 := Nat64.bitrotRight(v5, 24);
            v1 += m[s[9]];
            v1 += v6;
            v12 := v12 ^ v1;
            v12 := Nat64.bitrotRight(v12, 32);
            v11 += v12;
            v6 := v6 ^ v11;
            v6 := Nat64.bitrotRight(v6, 24);
            v2 += m[s[10]];
            v2 += v7;
            v13 := v13 ^ v2;
            v13 := Nat64.bitrotRight(v13, 32);
            v8 += v13;
            v7 := v7 ^ v8;
            v7 := Nat64.bitrotRight(v7, 24);
            v3 += m[s[11]];
            v3 += v4;
            v14 := v14 ^ v3;
            v14 := Nat64.bitrotRight(v14, 32);
            v9 += v14;
            v4 := v4 ^ v9;
            v4 := Nat64.bitrotRight(v4, 24);

            v0 += m[s[12]];
            v0 += v5;
            v15 := v15 ^ v0;
            v15 := Nat64.bitrotRight(v15, 16);
            v10 += v15;
            v5 := v5 ^ v10;
            v5 := Nat64.bitrotRight(v5, 63);
            v1 += m[s[13]];
            v1 += v6;
            v12 := v12 ^ v1;
            v12 := Nat64.bitrotRight(v12, 16);
            v11 += v12;
            v6 := v6 ^ v11;
            v6 := Nat64.bitrotRight(v6, 63);
            v2 += m[s[14]];
            v2 += v7;
            v13 := v13 ^ v2;
            v13 := Nat64.bitrotRight(v13, 16);
            v8 += v13;
            v7 := v7 ^ v8;
            v7 := Nat64.bitrotRight(v7, 63);
            v3 += m[s[15]];
            v3 += v4;
            v14 := v14 ^ v3;
            v14 := Nat64.bitrotRight(v14, 16);
            v9 += v14;
            v4 := v4 ^ v9;
            v4 := Nat64.bitrotRight(v4, 63);
        };

        let k0 = h[0] ^ (v0 ^ v8);
        let k1 = h[1] ^ (v1 ^ v9);
        let k2 = h[2] ^ (v2 ^ v10);
        let k3 = h[3] ^ (v3 ^ v11);
        let k4 = h[4] ^ (v4 ^ v12);
        let k5 = h[5] ^ (v5 ^ v13);
        let k6 = h[6] ^ (v6 ^ v14);
        let k7 = h[7] ^ (v7 ^ v15);

        return [k0, k1, k2, k3, k4, k5, k6, k7];
    };
};