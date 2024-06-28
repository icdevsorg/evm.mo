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

    public func freeze() : Result<[Nat], Text> {
      if (_size == 0) {
        let _stack: [Nat] = [];
        return #ok(_stack);
      } else {
        let _stack = Array.freeze<Nat>(stack);
        return #ok(Array.subArray<Nat>(_stack, 0, _size));
      };
    };

    public func thaw(arr: [Nat]) : Result<(), Text> {
      if (Array.size(arr) > 1024) {
        return #err("Stack overflow");
      } else if (Array.size(arr) == 0) {
        stack := Array.init<Nat> (1024, 0);
        _size := 0;
        return #ok(());
      } else {
        let padSize: Nat = 1024 - Array.size(arr);
        let _pad = Array.init<Nat>(padSize, 0);
        let pad = Array.freeze<Nat>(_pad);
        let _stack = Array.append<Nat>(arr, pad);
        stack := Array.thaw<Nat>(_stack);
        _size := Array.size(arr);
        return #ok(());
      }
    };
  };
};