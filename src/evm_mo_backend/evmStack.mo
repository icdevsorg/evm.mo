import Array "mo:base/Array";

module {

  // A structure representing an EVM-specific stack.
  public class EVMStack() {
    var stack = Array.init<Nat>(1024,0);
    var _size: Nat = 0;

    public func push(X: Nat) {
      assert(_size < 1024);
      stack[_size] := X;
      _size += 1;
    };

    public func pop() : Nat {
      assert(_size > 0);
      _size -= 1;
      stack[_size];
    };

    public func peek(pos: Nat) : Nat {
      assert(pos < _size); // pos = 0 for top item
      stack[_size - pos - 1];
    };

    public func poke(pos: Nat, X: Nat) {
      assert(pos < _size); // pos = 0 for top item
      stack[_size - pos - 1] := X;
    };
  };
};