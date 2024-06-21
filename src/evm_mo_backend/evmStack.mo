import Array "mo:base/Array";

module {

  // A structure representing an EVM-specific stack.
  public class EVMStack() {
    var stack = Array.init<Nat>(1024,0);
    var _size: Nat = 0;

    public type Result<Ok, Err> = { #ok: Ok; #err: Err};

    public func push(X: Nat) : Result<(), Text> {
      if (_size >= 1024) {
        return #err("Stack overflow");
      } else {
        stack[_size] := X;
        _size += 1;
        return #ok(());
      };
    };

    public func pop() : Result<Nat, Text> {
      if (_size == 0) {
        return #err("Stack underflow");
      } else {
        _size -= 1;
        return #ok(stack[_size]);
      };
    };

    public func peek(pos: Nat) : Result<Nat, Text> {
      if (pos >= _size) { // pos = 0 for top item
        return #err("Invalid stack position");
      } else {
        return #ok(stack[_size - pos - 1]);
      };
    };

    public func poke(pos: Nat, X: Nat) : Result<(), Text> {
      if (pos >= _size) { // pos = 0 for top item
        return #err("Invalid stack position");
      } else {
        stack[_size - pos - 1] := X;
        return #ok(());
      };
    };
  };
};