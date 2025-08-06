import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Vec "mo:vector";
import T "types";

module {
  type Result<Ok, Err> = { #ok: Ok; #err: Err};

  // Logging Operations (0xA0-0xA4)
  // These operations emit log events with 0-4 topics for smart contract event logging

  public let op_A0_LOG0 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG0 called within STATICCALL")
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
            let topics : [Blob] = [];
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
            };
          };
        };
      };
    };
  };

  public let op_A1_LOG1 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG1 called within STATICCALL")
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
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(topic1Nat)) {
                let topic1Buffer = Buffer.Buffer<Nat8>(32);
                for (i in Iter.revRange(31, 0)) {
                  topic1Buffer.add(Nat8.fromNat((topic1Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                };
                let topic1 = Blob.fromArray(Buffer.toArray<Nat8>(topic1Buffer));
                let topics : [Blob] = [topic1];
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
                };
              };
            };
          };
        };
      };
    };
  };

  public let op_A2_LOG2 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG2 called within STATICCALL")
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
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(topic1Nat)) {
                let topic1Buffer = Buffer.Buffer<Nat8>(32);
                for (i in Iter.revRange(31, 0)) {
                  topic1Buffer.add(Nat8.fromNat((topic1Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                };
                let topic1 = Blob.fromArray(Buffer.toArray<Nat8>(topic1Buffer));
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(topic2Nat)) {
                    let topic2Buffer = Buffer.Buffer<Nat8>(32);
                    for (i in Iter.revRange(31, 0)) {
                      topic2Buffer.add(Nat8.fromNat((topic2Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                    };
                    let topic2 = Blob.fromArray(Buffer.toArray<Nat8>(topic2Buffer));
                    let topics : [Blob] = [topic1, topic2];
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
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  public let op_A3_LOG3 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG3 called within STATICCALL")
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
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(topic1Nat)) {
                let topic1Buffer = Buffer.Buffer<Nat8>(32);
                for (i in Iter.revRange(31, 0)) {
                  topic1Buffer.add(Nat8.fromNat((topic1Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                };
                let topic1 = Blob.fromArray(Buffer.toArray<Nat8>(topic1Buffer));
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(topic2Nat)) {
                    let topic2Buffer = Buffer.Buffer<Nat8>(32);
                    for (i in Iter.revRange(31, 0)) {
                      topic2Buffer.add(Nat8.fromNat((topic2Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                    };
                    let topic2 = Blob.fromArray(Buffer.toArray<Nat8>(topic2Buffer));
                    switch (exVar.stack.pop()) {
                      case (#err(e)) { return #err(e) };
                      case (#ok(topic3Nat)) {
                        let topic3Buffer = Buffer.Buffer<Nat8>(32);
                        for (i in Iter.revRange(31, 0)) {
                          topic3Buffer.add(Nat8.fromNat((topic3Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                        };
                        let topic3 = Blob.fromArray(Buffer.toArray<Nat8>(topic3Buffer));
                        let topics : [Blob] = [topic1, topic2, topic3];
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
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  public let op_A4_LOG4 = func (exCon: T.ExecutionContext, exVar: T.ExecutionVariables, engineInstance: T.Engine) : Result<T.ExecutionVariables, Text> {
    switch (exVar.stack.pop()) {
      case (#err(e)) { return #err(e) };
      case (#ok(offset)) {
        switch (exVar.stack.pop()) {
          case (#err(e)) { return #err(e) };
          case (#ok(size)) {
            if (exVar.staticCall > 0) {
              return #err("Disallowed opcode LOG4 called within STATICCALL")
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
            switch (exVar.stack.pop()) {
              case (#err(e)) { return #err(e) };
              case (#ok(topic1Nat)) {
                let topic1Buffer = Buffer.Buffer<Nat8>(32);
                for (i in Iter.revRange(31, 0)) {
                  topic1Buffer.add(Nat8.fromNat((topic1Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                };
                let topic1 = Blob.fromArray(Buffer.toArray<Nat8>(topic1Buffer));
                switch (exVar.stack.pop()) {
                  case (#err(e)) { return #err(e) };
                  case (#ok(topic2Nat)) {
                    let topic2Buffer = Buffer.Buffer<Nat8>(32);
                    for (i in Iter.revRange(31, 0)) {
                      topic2Buffer.add(Nat8.fromNat((topic2Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                    };
                    let topic2 = Blob.fromArray(Buffer.toArray<Nat8>(topic2Buffer));
                    switch (exVar.stack.pop()) {
                      case (#err(e)) { return #err(e) };
                      case (#ok(topic3Nat)) {
                        let topic3Buffer = Buffer.Buffer<Nat8>(32);
                        for (i in Iter.revRange(31, 0)) {
                          topic3Buffer.add(Nat8.fromNat((topic3Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                        };
                        let topic3 = Blob.fromArray(Buffer.toArray<Nat8>(topic3Buffer));
                        switch (exVar.stack.pop()) {
                          case (#err(e)) { return #err(e) };
                          case (#ok(topic4Nat)) {
                            let topic4Buffer = Buffer.Buffer<Nat8>(32);
                            for (i in Iter.revRange(31, 0)) {
                              topic4Buffer.add(Nat8.fromNat((topic4Nat % (256 ** Int.abs(i+1))) / (256 ** Int.abs(i))));
                            };
                            let topic4 = Blob.fromArray(Buffer.toArray<Nat8>(topic4Buffer));
                            let topics : [Blob] = [topic1, topic2, topic3, topic4];
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
                            };
                          };
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
