import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Vec "mo:vector"; 
import T "types";


module {

  type Result<Ok, Err> = { #ok: Ok; #err: Err };

  // Helper to extract a topic from the stack and convert to Blob
  private func popTopic(stack : T.EVMStack) : ?Blob {
    switch (stack.pop()) {
      case (#err(_)) { null };
      case (#ok(topicNat)) {
        let topicBuffer = Buffer.Buffer<Nat8>(32);
        for (i in Iter.revRange(31, 0)) {
          topicBuffer.add(Nat8.fromNat((topicNat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
        };
        ?Blob.fromArray(Buffer.toArray<Nat8>(topicBuffer))
      }
    }
  };

  // Generic log helper
  private func doLog(numTopics: Nat, exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG called within STATICCALL")
            };
            let memory_byte_size = Vec.size(exVar.memory);
            let memory_size_word = (memory_byte_size + 31) / 32;
            let memory_cost = (memory_size_word ** 2) / 512 + (3 * memory_size_word);
            var new_memory_cost = memory_cost;
            if (offset + size > memory_byte_size) {
              let new_memory_size_word = (offset + size + 31) / 32;
              let new_memory_byte_size = new_memory_size_word * 32;
              Vec.addMany(exVar.memory, new_memory_byte_size - memory_byte_size, Nat8.fromNat(0));
              new_memory_cost := (new_memory_size_word ** 2) / 512 + (3 * new_memory_size_word);
            };
            let dataBuffer = Buffer.Buffer<Nat8>(4);
            if (size > 0) {
              for (pos in Iter.range(offset, offset + size - 1)) {
                dataBuffer.add(Vec.get(exVar.memory, pos));
              };
            };
            let dataArray = Buffer.toArray<Nat8>(dataBuffer);
            let data = Blob.fromArray(dataArray);
            var topics : [Blob] = [];
            var i = 0;
            var ok = true;
            while (i < numTopics and ok) {
              switch (popTopic(exVar.stack)) {
                case null { ok := false };
                case (?topic) { topics := Array.append(topics, [topic]); i += 1; };
              }
            };
            if (not ok) { return #err("Stack underflow for topics") };
            let logEntry : T.LogEntry = { topics = topics; data = data; };
            Vec.add(exVar.logs, logEntry);
            let memory_expansion_cost = new_memory_cost - memory_cost;
            var topic_count = 0;
            for (entry in Vec.vals(exVar.logs)) {
              topic_count += entry.topics.size();
            };
            let dynamic_gas = 375 * topic_count + 8 * size + memory_expansion_cost;
            let newGas: Int = exVar.totalGas - 375 - dynamic_gas;
            if (newGas < 0) {
              return #err("Out of gas")
            } else {
              exVar.totalGas := Int.abs(newGas);
              return #ok(exVar);
            }
          }
        }
      }
    }
  };

  public func op_A0_LOG0 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    doLog(0, exCon, exVar, engineInstance)
  };

  public func op_A1_LOG1 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    doLog(1, exCon, exVar, engineInstance)
  };

  public func op_A2_LOG2 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    doLog(2, exCon, exVar, engineInstance)
  };

  public func op_A3_LOG3 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    doLog(3, exCon, exVar, engineInstance)
  };

  public func op_A4_LOG4 (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    doLog(4, exCon, exVar, engineInstance)
  };
}