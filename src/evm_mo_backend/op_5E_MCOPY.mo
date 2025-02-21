import Vec "mo:vector";
import Result "mo:base/Result";
import Int  "mo:base/Int";
import Nat8  "mo:base/Nat8";
import Array "mo:base/Array";
import Iter  "mo:base/Iter";
import Debug "mo:base/Debug";


// Assuming T is the module that contains our shared types: ExecutionContext, ExecutionVariables, etc.
import T "./types";


module {
// MCOPY opcode: Copy a block of memory within the working memory.
// It pops three values from the stack: destination offset, source offset, and length of bytes to copy.
// If (src + length) or (dst + length) exceeds the current memory length and length > 0,
// the memory is extended with zero bytes (and corresponding gas cost is deducted).
public func op_5E_MCOPY(exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result.Result<T.ExecutionVariables, Text> {
  // Pop destination offset
  switch (exVar.stack.pop()) {
    case (#err(e)) { return #err(e) };
    case (#ok(destOffset)) {
      // Pop source offset
      switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(sourceOffset)) {
        // Pop length
        switch (exVar.stack.pop()) {
        case (#err(e)) { return #err(e) };
        case (#ok(length)) {
          // Get current memory size from exVar.memory (length in bytes)
          let currentSize = Vec.size(exVar.memory);
          // Determine required memory size based on src+length and dst+length
          let requiredSize =
          if (length > 0) {
                  let r = if (sourceOffset + length > destOffset + length) { sourceOffset + length } else { destOffset + length };
                  r
          } else { currentSize };


            // If requiredSize exceeds current memory size, expand memory.
            if (requiredSize > currentSize) {
              let additional = requiredSize - currentSize;
              Vec.addMany(exVar.memory, additional, Nat8.fromNat(0));
            };

              // At this point, memory is guaranteed to be at least requiredSize bytes.
              // Use a temporary buffer to accommodate overlapping copy.
              var temp: [Nat8] = [];
              for (i in Iter.range(0, length - 1)) {
                temp := Array.append<Nat8>(temp, [Vec.get(exVar.memory, sourceOffset + i)]);
              };
              // Now write to destination.
              for (i in Iter.range(0, length - 1)) {
                Vec.put(exVar.memory, destOffset + i, temp[i]);
              };

              // Calculate gas cost.
              // According to EIP, gas cost = G_verylow + (3 * ceil(length / 32)) + memory_expansion_cost
              // For this simplified implementation, we deduct a fixed gas cost per copy operation.
              let newGas: Int = exVar.totalGas - 3;
              if (newGas < 0) {
                return #err("Out of gas")
              };
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            };
          };
        };
      };
    };
  };

}
}