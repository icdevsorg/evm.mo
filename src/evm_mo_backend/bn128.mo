import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";

module {

  type Fq = Nat; // field elements
  type Fq2 = [Int]; // 2 elements
  type Fq12 = [Int]; // 12 elements

  public let FQ2_one: [Int] = [1, 0];
  public let FQ2_zero: [Int] = [0, 0];
  public let FQ12_one: [Int] = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  public let FQ12_zero: [Int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  // FIELD ELEMENTS
  let fieldModulus = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

  // Extended Euclidean algorithm to find modular inverses for integers
  func primeFieldInv(a: Int, n: Int): Nat {
    if (a == 0) return 0;

    var lm: Int = 1;
    var hm: Int = 0;
    var low = a % n;
    var high = n;

    while (low > 1) {
      let r = high / low;
      let nm = hm - lm * r;
      let new = high - low * r;
      hm := lm;
      lm := nm;
      high := low;
      low := new;
    };
    return Int.abs(lm % n);
  };

  // Utility functions for polynomial operations
  func deg(p: [Int]): Nat {
    if (p == []) { return 0; };
    var d = Array.size(p) - 1;
    while (d > 0 and p[d] == 0) d -= 1;
    return d;
  };

  func polyRoundedDiv(a: [Int], b: [Int]): [Nat] {
    let dega = deg(a);
    let degb = deg(b);
    var temp = Array.thaw<Int>(a);
    var o = Array.init<Nat>(Array.size(a), 0);

    for (i in Iter.revRange(dega - degb, 0)) {
      let coeff = (temp[degb + Int.abs(i)] * primeFieldInv(b[degb], fieldModulus)) % fieldModulus;
      o[Int.abs(i)] := Int.abs(coeff);

      for (c in Iter.range(0, degb)) {
        temp[c + Int.abs(i)] := (temp[c + Int.abs(i)] - coeff * b[c]) % fieldModulus;
      };
    };
    let o_ = Array.freeze<Nat>(o);
    return Array.map<Nat, Nat>(Array.subArray<Nat>(o_, 0, deg(o_) + 1), func x = x % fieldModulus);
  };


  // A class for field elements in FQ
  class FQ(n: Nat) {
    let fieldModulus = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    let value = n % fieldModulus;

    public func add(other: Fq): Fq {
      return (value + other) % fieldModulus;
    };

    public func sub(other: Fq): Fq {
      return (value + fieldModulus - (other % fieldModulus)) % fieldModulus;
    };

    public func mul(other: Fq): Fq {
      return (value * other) % fieldModulus;
    };

    public func div(other: Fq): Fq {
      return (value * primeFieldInv(other, fieldModulus)) % fieldModulus;
    };

    public func pow(exp: Fq): Fq {
      var base = value;
      var result = 1;
      var power = exp;

      while (power > 0) {
        if (power % 2 == 1) {
          result := (result * base) % fieldModulus;
        };
        power := power / 2;
        base := (base * base) % fieldModulus;
      };
      return result;
    };

    public func neg(): Fq {
      return fieldModulus - (value % fieldModulus);
    };

    public func eq(other: Fq): Bool {
      return value == (other % fieldModulus);
    };

    public func ne(other: Fq): Bool {
      return value != (other % fieldModulus);
    };

    public func repr(): Text {
      return Nat.toText(value);
    };
  };

  // The quadratic extension field
  public class FQ2(coeffsInit: [Int]) {
    public let coeffs: [Int] = coeffsInit;
    let modulusCoeffs = [1, 0];
    let fieldModulus = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    let mcTuples = [(0, 1)];
    let degree= 2;

    public func value(): Fq2 {
      [coeffs[0] % fieldModulus, coeffs[1] % fieldModulus]
    };

    public func add(other: Fq2): Fq2 {
      let newCoeffs = Array.tabulate<Int>(
        degree,
        func(i: Nat): Int {
          (coeffs[i] + other[i]) % fieldModulus
        }
      );
      return newCoeffs;
    };

    public func sub(other: Fq2): Fq2 {
      let newCoeffs = Array.tabulate<Int>(
        degree,
        func(i: Nat): Int {
          (coeffs[i] - other[i]) % fieldModulus
        }
      );
      return newCoeffs;
    };

    public func mul(other: Fq2): Fq2 {
      var b = Array.init<Int>(degree * 2 - 1, 0);
      for (i in Iter.range(0, coeffs.size() - 1)) {
        for (j in Iter.range(0, other.size() - 1)) {
          b[i + j] += coeffs[i] * other[j];
        };
      };

      for (exp in Iter.revRange(degree - 2, 0)) { // Degree reduction
        let top = b[degree + Int.abs(exp)];
        for ((i, c) in mcTuples.vals()) {
          b[Int.abs(exp + i)] -= top * c;
        };
      };

      let newCoeffs = Array.tabulate<Int>(
        degree,
        func(i: Nat): Int {
          b[i] % fieldModulus
        }
      );

      return newCoeffs;
    };

    public func scalarDiv(scalar: Int): Fq2 {
      // Scalar division: multiply by modular inverse of scalar
      let scalarInv = primeFieldInv(scalar, fieldModulus);
      let newCoeffs = Array.map<Int, Int>(
        coeffs,
        func(c: Int): Int {
          (c * scalarInv) % fieldModulus;
        }
      );
      return newCoeffs;
    };

    public func div(other: Fq2): Fq2 {
      // Polynomial division: multiply by the inverse of the other FQ2
      return FQ2(coeffs).mul(FQ2(other).inv());
    };

    public func scalarMul(scalar: Int): Fq2 {
      let newCoeffs = Array.map<Int, Int>(
        coeffs,
        func(c: Int): Int {
          (c * scalar) % fieldModulus;
        }
      );
      return newCoeffs;
    };

    public func pow(exponent: Nat): Fq2 {
      var result = FQ2_one;
      var base = coeffs;
      var exp = exponent;

      while (exp > 0) {
        if (exp % 2 == 1) {
          result := FQ2(result).mul(base);
        };
        base := FQ2(base).mul(base);
        exp /= 2;
      };

      return result;
    };

    public func eq(other: Fq2): Bool {
      for (i in Iter.range(0, coeffs.size() - 1)) {
        if (coeffs[i] != other[i]) {
          return false;
        };
      };
      return true;
    };

    public func neg(): Fq2 {
      let newCoeffs = Array.map<Int, Int>(
        coeffs,
        func(c: Int): Int {
          (-c) % fieldModulus;
        }
      );
      return newCoeffs;
    };

    // Modular inverse (using extended Euclidean algorithm)
    public func inv(): Fq2 {
      var lm = Array.init<Int>(degree + 1, 0); lm[0] := 1;
      var hm = Array.init<Int>(degree + 1, 0);
      var low = Array.append<Int>(coeffs, [0]);
      var high = Array.append<Int>(modulusCoeffs, [1]);

      while (deg(low) > 0) {
        let r_ = polyRoundedDiv(high, low);
        let extra = degree + 1 - r_.size();
        let r = Array.append<Nat>(r_, Array.freeze<Nat>(Array.init<Nat>(extra, 0)));
        var nm = hm;
        var newLow = Array.thaw<Int>(high);

        for (i in Iter.range(0, degree)) {
          for (j in Iter.range(0, degree - i)) {
            nm[i + j] := (nm[i + j] - lm[i] * r[j]) % fieldModulus;
            newLow[i + j] := (newLow[i + j] - low[i] * r[j]) % fieldModulus;
          };
        };

        lm := nm;
        low := Array.freeze<Int>(newLow);
        high := low;
        hm := lm;
      };

      return FQ2(Array.subArray<Int>(Array.freeze<Int>(lm), 0, degree)).scalarMul(primeFieldInv(low[0], fieldModulus));
    };

    public func repr(): Text {
      return "FQ2(" # debugShowCoeffs() # ")";
    };

    private func debugShowCoeffs(): Text {
      Array.foldLeft<Int, Text>(coeffs, "", func(acc, c) = acc # " " # Int.toText(c));
    };
  };

  // The 12th-degree extension field
  public class FQ12(coeffsInit: [Int]) {
    public let coeffs: [Int] = coeffsInit;
    let modulusCoeffs: [Int] = [82, 0, 0, 0, 0, 0, -18, 0, 0, 0, 0, 0];
    let fieldModulus = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    let mcTuples = [(0, 82), (6, -18)];
    let degree = 12;

    public func add(other: Fq12): Fq12 {
      let newCoeffs = Array.tabulate<Int>(
        degree,
        func(i: Nat): Int {
          (coeffs[i] + other[i]) % fieldModulus
        }
      );
      return newCoeffs;
    };

    public func sub(other: Fq12): Fq12 {
      let newCoeffs = Array.tabulate<Int>(
        degree,
        func(i: Nat): Int {
          (coeffs[i] - other[i]) % fieldModulus
        }
      );
      return newCoeffs;
    };

    public func mul(other: Fq12): Fq12 {
      var b = Array.init<Int>(degree * 2 - 1, 0);
      for (i in Iter.range(0, coeffs.size() - 1)) {
        for (j in Iter.range(0, other.size() - 1)) {
          b[i + j] += coeffs[i] * other[j];
        };
      };

      for (exp in Iter.revRange(degree - 2, 0)) { // Degree reduction
        let top = b[degree + Int.abs(exp)];
        for ((i, c) in mcTuples.vals()) {
          b[Int.abs(exp + i)] -= top * c;
        };
      };

      let newCoeffs = Array.tabulate<Int>(
        degree,
        func(i: Nat): Int {
          b[i] % fieldModulus
        }
      );

      return newCoeffs;
    };

    public func scalarDiv(scalar: Int): Fq2 {
      // Scalar division: multiply by modular inverse of scalar
      let scalarInv = primeFieldInv(scalar, fieldModulus);
      let newCoeffs = Array.map<Int, Int>(
        coeffs,
        func(c: Int): Int {
          (c * scalarInv) % fieldModulus;
        }
      );
      return newCoeffs;
    };

    public func div(other: Fq12): Fq12 {
      // Polynomial division: multiply by the inverse of the other FQ2
      return FQ12(coeffs).mul(FQ12(other).inv());
    };

    public func scalarMul(scalar: Int): Fq12 {
      let newCoeffs = Array.map<Int, Int>(
        coeffs,
        func(c: Int): Int {
          (c * scalar) % fieldModulus;
        }
      );
      return newCoeffs;
    };

    public func pow(exponent: Nat): Fq12 {
      var result = FQ12_one;
      var base = coeffs;
      var exp = exponent;

      while (exp > 0) {
        if (exp % 2 == 1) {
          result := FQ12(result).mul(base);
        };
        base := FQ12(base).mul(base);
        exp /= 2;
      };

      return result;
    };

    public func eq(other: Fq12): Bool {
      for (i in Iter.range(0, coeffs.size() - 1)) {
        if (coeffs[i] != other[i]) {
          return false;
        };
      };
      return true;
    };

    public func neg(): Fq12 {
      let newCoeffs = Array.map<Int, Int>(
        coeffs,
        func(c: Int): Int {
          (-c) % fieldModulus;
        }
      );
      return newCoeffs;
    };

    // Modular inverse (using extended Euclidean algorithm)
    public func inv(): Fq12 {
      var lm = Array.init<Int>(degree + 1, 0); lm[0] := 1;
      var hm = Array.init<Int>(degree + 1, 0);
      var low = Array.append<Int>(coeffs, [0]);
      var high = Array.append<Int>(modulusCoeffs, [1]);

      while (deg(low) > 0) {
        let r_ = polyRoundedDiv(high, low);
        let extra = degree + 1 - r_.size();
        let r = Array.append<Nat>(r_, Array.freeze<Nat>(Array.init<Nat>(extra, 0)));
        var nm = hm;
        var newLow = Array.thaw<Int>(high);

        for (i in Iter.range(0, degree)) {
          for (j in Iter.range(0, degree - i)) {
            nm[i + j] := (nm[i + j] - lm[i] * r[j]) % fieldModulus;
            newLow[i + j] := (newLow[i + j] - low[i] * r[j]) % fieldModulus;
          };
        };

        lm := nm;
        low := Array.freeze<Int>(newLow);
        high := low;
        hm := lm;
      };

      return FQ12(Array.subArray<Int>(Array.freeze<Int>(lm), 0, degree)).scalarMul(primeFieldInv(low[0], fieldModulus));
    };

    public func repr(): Text {
      return "FQ12(" # debugShowCoeffs() # ")";
    };

    private func debugShowCoeffs(): Text {
      Array.foldLeft<Int, Text>(coeffs, "", func(acc, c) = acc # " " # Int.toText(c));
    };
  };

  // CURVE
  public let curveOrder = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

  // Generator points
  public let G1 = (1, 2, 1);
  public let G2 = (
    [10857046999023057135944570762232829481370756359578518086990519993285655852781, 
         11559732032986387107991004021392285783925812861821192530917403151452391805634],
    [8495653923123431417604973247489272438418190587263600148770280649306958101930, 
         4082367875863433681332203403145435568316851327593401208105741076214120093531],
    FQ2_one
  );

  // Check if a point is the point at infinity
  public func isInf(pt: (Fq, Fq, Fq)): Bool {
    return pt.2 % fieldModulus == 0;
  };

  public func isInfFq2(pt: (Fq2, Fq2, Fq2)): Bool {
    return FQ2(pt.2).value() == FQ2_zero;
  };

  // Check if a point is on the curve y^2 == x^3 + b
  public func isOnCurve(pt: (Fq, Fq, Fq), b: Fq): Bool {
    if (isInf(pt)) {
      return true;
    };
    let (x, y, z) = pt;
    let l = FQ(FQ(y).pow(2)).mul(z); // (y ** 2) * z
    let r = FQ(FQ(x).pow(3)).add(FQ(b).mul(FQ(z).pow(3))); // (x ** 3) + (b * (z ** 3))
    return l == r;  };

  public func isOnCurveFq2(pt: (Fq2, Fq2, Fq2), b: Fq2): Bool {
    if (isInfFq2(pt)) {
      return true;
    };
    let (x, y, z) = pt;
    let l = FQ2(FQ2(y).pow(2)).mul(z); // (y ** 2) * z
    let r = FQ2(FQ2(x).pow(3)).add(FQ2(b).mul(FQ2(z).pow(3))); // (x ** 3) + (b * (z ** 3))
    return l == r;
  };

  // Elliptic curve point doubling
  public func double(pt: (Fq, Fq, Fq)): (Fq, Fq, Fq) {
    let (x, y, z) = pt;
    let W = FQ(FQ(x).pow(2)).mul(3); // 3 * (x ** 2);
    let S = FQ(y).mul(z); //y * z;
    let B = FQ(FQ(x).mul(y)).mul(S); //x * y * S;
    let H = FQ(FQ(W).pow(2)).sub(FQ(B).mul(8)); //(W ** 2) - 8 * B;
    let S_squared = FQ(S).pow(2); //S ** 2;
    let newX = FQ(FQ(H).mul(S)).mul(2); //2 * H * S;
    let newY = FQ(FQ(W).mul(FQ(FQ(B).mul(4)).sub(H))).sub(FQ(FQ(FQ(y).pow(2)).mul(S_squared)).mul(8)); //W * (4 * B - H) - 8 * (y ** 2) * S_squared;
    let newZ = FQ(FQ(S).mul(S_squared)).mul(8); //8 * S * S_squared;
    return (newX, newY, newZ);
  };

  // Elliptic curve point doubling for FQ2 (or FQ12)
  public func doubleFq2(pt: (Fq2, Fq2, Fq2)): (Fq2, Fq2, Fq2) {
    let (x, y, z) = pt;
    let W = FQ2(FQ2(x).pow(2)).scalarMul(3); // 3 * (x ** 2);
    let S = FQ2(y).mul(z); //y * z;
    let B = FQ2(FQ2(x).mul(y)).mul(S); //x * y * S;
    let H = FQ2(FQ2(W).pow(2)).sub(FQ2(B).scalarMul(8)); //(W ** 2) - 8 * B;
    let S_squared = FQ2(S).pow(2); //S ** 2;
    let newX = FQ2(FQ2(H).mul(S)).scalarMul(2); //2 * H * S;
    let newY = FQ2(FQ2(W).mul(FQ2(FQ2(B).scalarMul(4)).sub(H))).sub(FQ2(FQ2(FQ2(y).pow(2)).mul(S_squared)).scalarMul(8)); //W * (4 * B - H) - 8 * (y ** 2) * S_squared;
    let newZ = FQ2(FQ2(S).mul(S_squared)).scalarMul(8); //8 * S * S_squared;
    return (newX, newY, newZ);
  };

  // Elliptic curve point addition
  public func add(p1: (Fq12, Fq12, Fq12), p2: (Fq12, Fq12, Fq12)): (Fq12, Fq12, Fq12) {
    let one = FQ12_one;
    let zero = FQ12_zero;
    if (p1.2 == zero or p2.2 == zero) {
      return if (p2.2 == zero) p1 else p2;
    };
    let (x1, y1, z1) = p1;
    let (x2, y2, z2) = p2;
    let U1 = FQ12(y2).mul(z1);
    let U2 = FQ12(y1).mul(z2);
    let V1 = FQ12(x2).mul(z1);
    let V2 = FQ12(x1).mul(z2);

    if (V1 == V2 and U1 == U2) {
      return doubleFq2(p1);
    } else if (V1 == V2) {
      return (one, one, zero);
    };

    let U = FQ12(U1).sub(U2);
    let V = FQ12(V1).sub(V2);
    let V_squared = FQ12(V).pow(2);
    let V_squared_times_V2 = FQ12(V_squared).mul(V2);
    let V_cubed = FQ12(V).mul(V_squared);
    let W = FQ12(z1).mul(z2);
    let A = FQ12(FQ12(FQ12(FQ12(U).pow(2)).mul(W)).sub(V_cubed)).sub(FQ12(V_squared_times_V2).scalarMul(2)); // (U ** 2) * W - V_cubed - 2 * V_squared_times_V2;
    let newX = FQ12(V).mul(A);
    let newY = FQ12(FQ12(U).mul(FQ12(V_squared_times_V2).sub(A))).sub(FQ12(V_cubed).mul(U2)); // U * (V_squared_times_V2 - A) - V_cubed * U2;
    let newZ = FQ12(V_cubed).mul(W);
    return (newX, newY, newZ);
  };

  // Elliptic curve point multiplication
  public func multiply(pt: (Fq2, Fq2, Fq2), n: Nat): (Fq2, Fq2, Fq2) {
    if (n == 0) {
      return (FQ2_one, FQ2_one, FQ2_zero);
    } else if (n == 1) {
      return pt;
    } else if (n % 2 == 0) {
      return multiply(doubleFq2(pt), n / 2);
    } else {
      return add(multiply(doubleFq2(pt), n / 2), pt);
    };
  };

  // Negate a point
  public func neg(pt: (Fq2, Fq2, Fq2)): (Fq2, Fq2, Fq2) {
    if (isInfFq2(pt)) {
      return pt;
    };
    let (x, y, z) = pt;
    return (x, FQ2(y).neg(), z);
  };

  // Twist a point in E(FQ2) into E(FQ12)
  public func twist(pt: (Fq2, Fq2, Fq2)): (Fq12, Fq12, Fq12) {
    let _x = pt.0;
    let _y = pt.1;
    let _z = pt.2;
    let w: Fq12 = [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let xcoeffs = [_x[0] - _x[1] * 9, _x[1]];
    let ycoeffs = [_y[0] - _y[1] * 9, _y[1]];
    let zcoeffs = [_z[0] - _z[1] * 9, _z[1]];
    let nx = [xcoeffs[0], 0,0,0,0,0, xcoeffs[1], 0,0,0,0,0];
    let ny = [ycoeffs[0], 0,0,0,0,0, ycoeffs[1], 0,0,0,0,0];
    let nz = [zcoeffs[0], 0,0,0,0,0, zcoeffs[1], 0,0,0,0,0];
    let twx = FQ12(nx).mul(FQ12(w).pow(2));
    let twy = FQ12(ny).mul(FQ12(w).pow(3));
    return (twx, twy, nz); // use FQ12 functions
  };

  // PAIRING
  // Constants for the pairing algorithm
  public let ateLoopCount = 29793968203157093288;
  public let pseudoBinaryEncoding = [0, 0, 0, 1, 0, 1, 0, -1, 0, 0, 1, -1, 0, 0, 1, 0,
                                      0, 1, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 0, 0, 1, 1,
                                      1, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, -1, 0, 0, 1,
                                      1, 0, 0, -1, 0, 0, 0, 1, 1, 0, -1, 0, 0, 1, 0, 1, 1];

  // Line function for the Miller loop
  public func lineFunc(P1: (Fq12, Fq12, Fq12), P2: (Fq12, Fq12, Fq12), T: (Fq12, Fq12, Fq12)): (Fq12, Fq12) {
    let (x1, y1, z1) = P1;
    let (x2, y2, z2) = P2;
    let (xt, yt, zt) = T;

    let mNumerator = FQ12(FQ12(y2).mul(z1)).sub(FQ12(y1).mul(z2));// y2 * z1 - y1 * z2;
    let mDenominator = FQ12(FQ12(x2).mul(z1)).sub(FQ12(x1).mul(z2));// x2 * z1 - x1 * z2;

    if (mDenominator != FQ12_zero) {
      let v1 = FQ12(mNumerator).mul(FQ12(FQ12(z1).mul(xt)).sub(FQ12(x1).mul(zt))); // mNumerator * (xt * z1 - x1 * zt)
      let v2 = FQ12(mNumerator).mul(FQ12(FQ12(z1).mul(yt)).sub(FQ12(y1).mul(zt))); // mDenominator * (yt * z1 - y1 * zt)
      let v3 = FQ12(FQ12(mDenominator).mul(zt)).mul(z1); // mDenominator * zt * z1
      return (FQ12(v1).sub(v2), v3);
    } else if (mNumerator == FQ12_zero) {
      let mNumerator = FQ12(FQ12(x1).mul(x1)).scalarMul(3); // 3 * x1 * x1;
      let mDenominator = FQ12(FQ12(y1).mul(z1)).scalarMul(2); // 2 * y1 * z1;
      let v1 = FQ12(mNumerator).mul(FQ12(FQ12(z1).mul(xt)).sub(FQ12(x1).mul(zt))); // mNumerator * (xt * z1 - x1 * zt)
      let v2 = FQ12(mNumerator).mul(FQ12(FQ12(z1).mul(yt)).sub(FQ12(y1).mul(zt))); // mDenominator * (yt * z1 - y1 * zt)
      let v3 = FQ12(FQ12(mDenominator).mul(zt)).mul(z1); // mDenominator * zt * z1
      return (FQ12(v1).sub(v2), v3);
    } else {
      return (
        FQ12(FQ12(z1).mul(xt)).sub(FQ12(x1).mul(zt)), // xt * z1 - x1 * zt,
        FQ12(z1).mul(zt) // z1 * zt
      );
    };
  };

  // Cast a point to FQ12
  public func castPointToFQ12(pt: (Fq, Fq, Fq)): (Fq12, Fq12, Fq12) {
    let (x, y, z) = pt;
    return (
      [x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [y, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [z, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    );
  };

  // Miller loop
  public func millerLoop(Q: (Fq12, Fq12, Fq12), P: (Fq12, Fq12, Fq12), finalExponentiate: Bool): Fq12 {
    //if (Q == null or P == null) {
    //  return FQ12_one; // zero?
    //};

    var R = Q;
    var fNum = FQ12_one;
    var fDen = FQ12_one;

    for (b in Array.reverse(pseudoBinaryEncoding).vals()) {
      let (_n, _d) = lineFunc(R, R, P);
      fNum := FQ12(fNum).mul(FQ12(fNum).mul(_n));
      fDen := FQ12(fDen).mul(FQ12(fDen).mul(_n));
      R := doubleFq2(R);

      if (b == 1) {
        let (_n, _d) = lineFunc(R, Q, P);
        fNum := FQ12(fNum).mul(_n);
        fDen := FQ12(fDen).mul(_d);
        R := add(R, Q);
      } else if (b == -1) {
        let nQ = neg(Q);
        let (_n, _d) = lineFunc(R, nQ, P);
        fNum := FQ12(fNum).mul(_n);
        fDen := FQ12(fDen).mul(_d);
        R := add(R, nQ);
      };
    };

    let Q1 = (FQ12(Q.0).pow(fieldModulus), FQ12(Q.1).pow(fieldModulus), FQ12(Q.2).pow(fieldModulus));
    let nQ2 = (FQ12(Q1.0).pow(fieldModulus), FQ12(FQ12(Q1.1).pow(fieldModulus)).neg(), FQ12(Q1.2).pow(fieldModulus));

    let (_n1, _d1) = lineFunc(R, Q1, P);
    R := add(R, Q1);
    let (_n2, _d2) = lineFunc(R, nQ2, P);

    let f = FQ12(FQ12(FQ12(fNum).mul(_n1)).mul(_n2)).div(FQ12(FQ12(fDen).mul(_d1)).mul(_d2)); // fNum * _n1 * _n2 / (fDen * _d1 * _d2);

    if (finalExponentiate) {
      return FQ12(f).pow((fieldModulus ** 12 - 1) / curveOrder);
    } else {
      return f;
    };
  };

  // Pairing computation
  public func pairing(Q: (Fq2, Fq2, Fq2), P: (Fq, Fq, Fq), finalExponentiate: Bool): Fq12 {
    if (P.2 == 0 or Q.2 == FQ2_zero) {
      return FQ12_one;
    };
    return millerLoop(twist(Q), castPointToFQ12(P), finalExponentiate);
  };

  // Final exponentiation
  public func finalExponentiate(p: Fq12): Fq12 {
    return FQ12(p).pow((fieldModulus ** 12 - 1) / curveOrder);
  };
};
