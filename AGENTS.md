# Contributor Guide

## Dev Environment Tips
- You have DFX installed.
  - dfx build --check will build, optionally include just the canister name you want built. see dfx.json
  - dfx --help for more
- mops is used for motoko module management.
  - See the mops.toml file for current configuration
  - mops add <package> will add new packages
  - mops search <query> will search for packages
  - mops --help for more


## Testing Instructions
- pic.js should be used for testing. It is configured to use jest (`npm run test <?test-file>`)

## Best Practices

# Motoko Coding Best Practices

## ClassPlus construction

Modules that expose class based modules should implement the ClassPlus construction.

ClassPlus and Migration is an important infrastructure and data security process for creating a motoko canister and we can't skip it, even during MVP phases.

To do so:

### add and import the class-plus mops package

```terminal
mops add class-plus
```

```motoko
import ClassPlusLib "mo:class-plus";
```

### implement the class plus boiler plate

This code goes outside of the class you are writing and allows a class to easily instantiate the class with a stable stored variable. In this example {ClassName} would be replaced by the class you are creating.

```

  public func Init<system>(config : {
    manager: ClassPlusLib.ClassPlusInitializationManager;
    initialState: State;
    args : ?InitArgs;
    pullEnvironment : ?(() -> Environment);
    onInitialize: ?({ClassName} -> async*());
    onStorageChange : ((State) ->())
  }) :()-> Subscriber{
    ClassPlusLib.ClassPlus<system,
      {ClassName} , 
      State,
      InitArgs,
      Environment>({config with constructor = {ClassName} }).get;
  };
  ```

### ClassPlus constructor

Your class should use a standard class plus constructor of the following pattern. If you need additional fields you should add it to the InitArgs in the current Migration Types file.

```motoko
public class Subscriber(stored: ?State, caller: Principal, canister: Principal, args: ?InitArgs, environment_passed: ?Environment, storageChanged: (State) -> ()){...};
```


#### Suggested Completion Criteria

If you are building a stateful class component:

- Ensure that the class-plus module has been added and is in the mops.toml file.
- Ensure that the class-plus module and patterns are use for any stateful class module. Check patterns: Class Constructor, Int Function, InitArgs Type Definition, State Type Definition, Environment Type Definition, Initial State Definition

## Migration Pattern for stateful Classes

If you are implementing a class module that needs to maintain state, you should implement the Migration Pattern. The upgrade pattern works by a adding a new version each time the underlying structure of the state changes enough that the objects need to be migrated to a new structure.

### Directory Set-up

Under /src create a directory called /migrations

### Create the /src/migration/lib.mo file

This file is the driver for running migrations. It is mostly boilerplate:

```motoko

import D "mo:base/Debug";

import MigrationTypes "./types";
import v0_0_0 "./v000_000_000";
import v0_0_1 "./v000_000_001";

module {

  let debug_channel = {
    announce = true;
  };

  let upgrades = [
    v0_0_1.upgrade,
    // do not forget to add your new migration upgrade method here
  ];

  func getMigrationId(state: MigrationTypes.State): Nat {
    return switch (state) {
      case (#v0_0_0(_)) 0;
      case (#v0_0_1(_)) 1;
      // do not forget to add your new migration id here
      // should be increased by 1 as it will be later used as an index to get upgrade/downgrade methods
    };
  };

  public func migrate(
    prevState: MigrationTypes.State, 
    nextState: MigrationTypes.State, 
    args: MigrationTypes.Args,
    caller: Principal
  ): MigrationTypes.State {

    var state = prevState;
     
    var migrationId = getMigrationId(prevState);
    let nextMigrationId = getMigrationId(nextState);

    while (nextMigrationId > migrationId) {
      debug if (debug_channel.announce) D.print("in upgrade while " # debug_show((nextMigrationId, migrationId)));
      let migrate = upgrades[migrationId];
      debug if (debug_channel.announce) D.print("upgrade should have run");
      migrationId := if (nextMigrationId > migrationId) migrationId + 1 else migrationId - 1;

      state := migrate(state, args, caller);
    };

    return state;
  };

  public let migration = {
    initialState = #v0_0_0(#data);
    //update your current state version
    currentStateVersion = #v0_0_1(#id);
    getMigrationId = getMigrationId;
    migrate = migrate;
  };
};
```

### Create the src/migrations/types.mo file

this file is mostly boilerplate. You can write it as is for new classes.  For upgrades you will need to add new state entries according to the upgrade pattern.

```motoko
import v0_1_0 "./v000_001_000/types";
import Int "mo:base/Int";


module {
  // do not forget to change current migration when you add a new one
  // you should use this field to import types from you current migration anywhere in your project
  // instead of importing it from migration folder itself
  public let Current = v0_1_0;

  public type Args = ?v0_1_0.InitArgs;

  public type State = {
    #v0_0_0: {#id; #data};
    #v0_1_0: {#id; #data:  v0_1_0.State};
    // do not forget to add your new migration state types here
  };
};
```

### Create the initial 000_000_000 version.

create the directory /src/migrations/v000_000_000

add the /src/migrations/v000_000_000/lib.mo

```motoko
import MigrationTypes "../types";
import D "mo:base/Debug";

module {
  public func upgrade(prevmigration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal): MigrationTypes.State {
    return #v0_0_0(#data);
  };
};
```

add the /src/migrations/v000_000_000/types.mo

```motoko
// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead


module {
  public type State = ();
};
```

### Set up your types and/or define new types

You'll need to create a folder /src/migrations/v{semvar}/ with a lib.mo and types.mo file in it. {semvar} should be of the form 000_000_000 with 000 replaced by a 3 digit representation of the mag_min_pat pattern of semvar. We do this to keep them in semantic order in the file directory.

The types file should include at lest the following definitions:

InitArgs - The initialization args the class needs passed into the constructor
Environment - used for instance specific variables that need to be defined at run time and passed in by the canister. This likely need an advanced property that includes icrc85. See the section on ICRC-85.
Stats - used to report out state of the class.
State - used to hold stable state of the class.  This likely need an icrc85 property. See the section on ICRC-85.

example:

```motoko

  public type InitArgs ={
    sampleArg: Text;
  };

  public type Environment = {
    ...
    var example : Example;
    advanced : ?{
      icrc85 : ICRC85Options;
      
    };
  };

  public type Stats = {
    ...
    sampleStateProp: Text
    ...
  };

  ///MARK: State
  public type State = {
    ...
    sampleStateProp: Text
    icrc85: {
      var nextCycleActionId: ?Nat;
      var lastActionReported: ?Nat;
      var activeActions: Nat;
    };
    ...
  };
```

You will need a lib.mo file that defines what needs to happen during the upgrade:

```
import MigrationTypes "../types";
import Time "mo:base/Time";
import v0_1_0 "types";
import D "mo:base/Debug";

module {

  //export
  
  public let BTree = v0_1_0.BTree;
  public let Vector = v0_1_0.Vector;
  public let Set = v0_1_0.Set;
  public let Map = v0_1_0.Map;
  public type EmitableEvent = v0_1_0.EmitableEvent;

  public func upgrade(prevmigration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal): MigrationTypes.State {

    let (name) = switch (args) {
      case (?args) {(args.name)};
      case (_) {("nobody")};
    };

    let state : v0_1_0.State = {
      ...
      var sampleStateProp = name;
      icrc85 = {
        var nextCycleActionId = null;
        var lastActionReported = null;
        var activeActions = 0;
      };
    };

    return #v0_1_0(#data(state));
  };
};
```

### Set up your migration boiler plate in your class

The following code should be before your class declaration:

```motoko

  public let init = Migration.migrate;

  public func initialState() : State {#v0_0_0(#data)};
  public let currentStateVersion = #v0_1_0(#id);

```

### Hydrating your state from the migration state

The following boilerplate will hydrate your class with the state it needs to operate and will expose teh state and environment to the outside:

```motoko

    let environment = switch(environment_passed){
      case(?val) val;
      case(null) {
        D.trap("Environment is required");
      };
    };

    var state : CurrentState = switch(stored){
      case(null) {
        let #v0_1_0(#data(foundState)) = init(initialState(),currentStateVersion, args, canister);
        foundState;
      };
      case(?val) {
        let #v0_1_0(#data(foundState)) = init(val, currentStateVersion, args, canister);
        foundState;
      };
    };

    storageChanged(#v0_1_0(#data(state)));

    let self : Service.Service = actor(Principal.toText(canister));

    public func getState() : CurrentState {state};
    public func getEnvironment() : Environment {environment};
```

#### Suggested Completion Criteria

If you are building a stateful class component:

- Ensure that any stateful class has a migration patter.
- Ensure there is a /src/migrations/ folder
- Ensure that the migrations folder includes the boilerplate for the top-level types.mo and lib.mo boilerplate files and that the boilerplate has been adjusted for the current version.
- Ensure that each migration version has a types.mo file with updated types and that it has a lib.mo file that handles the upgrade
- Ensure that any actor using a stateful class includes the Migration Initialization BoilerPlate
- Ensure that any actor using a stateful class include the hydration boilerplate

## ICRC-85

Most stateful classes should implement ICRC-85 which defines Open Value Sharing parameters and allows users of open source software to fund the creators of the software using cycles from their Internet Computer canisters. 

### Add ovsfixed and timer-tool via mops

```terminal
mops add ovsfixed
mops add timer-tool
```

### Classes should import ovsfixed, timer-tool, and Timer;

```motoko
import ovsfixed "mo:ovs-fixed";
import TT "mo:timer-tool";
import Timer: "mo:base/Timer";
```

### Classes should put in the ovs boiler plate:

the following code goes in the class and is mostly boilerplate. the calulation of how many cycls to charge may be customized, but it is traditional to charge 1 XDR (1_000_000_000_000 cycles) per month plus some usage per action up to a rational limit almost certainly under 100 XDR.

```motoko
    ///////////
    // ICRC85 ovs
    //////////

    private var _icrc85init = false;

    private func ensureCycleShare<system>() : async*(){
      if(_icrc85init == true) return;
      _icrc85init := true;
      ignore Timer.setTimer<system>(#nanoseconds(OneDay), scheduleCycleShare);
      environment.tt.registerExecutionListenerAsync(?"icrc85:ovs:shareaction:icrc72subscriber", handleIcrc85Action : TT.ExecutionAsyncHandler);
    };

    private func scheduleCycleShare<system>() : async() {
      //check to see if it already exists
      debug d(debug_channel.announce, "in schedule cycle share");
      switch(state.icrc85.nextCycleActionId){
        case(?val){
          switch(Map.get(environment.tt.getState().actionIdIndex, Map.nhash, val)){
            case(?time) {
              //already in the queue
              return;
            };
            case(null) {};
          };
        };
        case(null){};
      };

      let result = environment.tt.setActionSync<system>(Int.abs(Time.now()), ({actionType = "icrc85:ovs:shareaction:icrc72subscriber"; params = Blob.fromArray([]);}));
      state.icrc85.nextCycleActionId := ?result.id;
    };

    private func handleIcrc85Action<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error>{
      D.print("in handle timer async " # debug_show((id,action)));
      switch(action.actionType){
        case("icrc85:ovs:shareaction:icrc72subscriber"){
          await* shareCycles<system>();
          #awaited(id);
        };
        case(_) #trappable(id);
      };
    };

    private func shareCycles<system>() : async*(){
      debug d(debug_channel.announce, "in share cycles ");
      let lastReportId = switch(state.icrc85.lastActionReported){
        case(?val) val;
        case(null) 0;
      };

      debug d(debug_channel.announce, "last report id " # debug_show(lastReportId));

      let actions = if(state.icrc85.activeActions > 0){
        state.icrc85.activeActions;
      } else {1;};

      state.icrc85.activeActions := 0;

      debug d(debug_channel.announce, "actions " # debug_show(actions));

      var cyclesToShare = 1_000_000_000_000; //1 XDR

      if(actions > 0){
        let additional = Nat.div(actions, 10000);
        debug d(debug_channel.announce, "additional " # debug_show(additional));
        cyclesToShare := cyclesToShare + (additional * 1_000_000_000_000);
        if(cyclesToShare > 100_000_000_000_000) cyclesToShare := 100_000_000_000_000;
      };

      debug d(debug_channel.announce, "cycles to share" # debug_show(cyclesToShare));

      try{
        await* ovsfixed.shareCycles<system>({
          environment = do?{environment.advanced!.icrc85};
          namespace = "com.panindustrial.libraries.icrc72subscriber";
          actions = actions;
          schedule = func <system>(period: Nat) : async* (){
            let result = environment.tt.setActionSync<system>(Int.abs(Time.now()) + period, {actionType = "icrc85:ovs:shareaction:icrc72subscriber"; params = Blob.fromArray([]);});
            state.icrc85.nextCycleActionId := ?result.id;
          };
          cycles = cyclesToShare;
        });
      } catch(e){
        debug d(debug_channel.announce, "error sharing cycles" # Error.message(e));
      };

    };

    let OneDay =  86_400_000_000_000;
```

### Call ensureCycleShare(); when the monetized action of the component is used:

Ths action and location will vary from class to class, but this must be called to schedule the cycleshare.

```motoko
await* ensureCycleShare();
```

### Add an increment to action

For each action you want to measure you need to increment the activeActions:

```motoko
state.icrc85.activeActions += 1;
```

### Define an openvaluesharing.mo file in your /src directory

This is mostly boilerplate, but replace {myClass} with he class name:

```motoko
module {
  public let openvaluesharing = {
    platform = "icp";
    asset = "cycles";
    payment_mechanism = "icrc85_deposit_cycles_notify";
    custom = [
      {
        key = "namespace";
        value = #text("com.panindustrial.libraries.{myClass}");
      },
      {
        key = "principal";
        value = #text("q26le-iqaaa-aaaam-actsa-cai");
      }
    ]
  };
};

```

#### Suggested Completion Criteria

- Ensure the ovs-fixed mops package has been added and is in the mops.toml file.
- Ensure the ovs-fixed mops package is imported into the class
- Ensure the class has the ovs boilerplate
- Ensure that ensureCycleShare() is called when class is first used
- Ensure the active actions have been identified and that code exists to increment the activeActions
- Ensure that openvalueshare.mo is defined in the root

## Listener Pattern

It is recommended that you expose the execution of code, particularly state changes, to the actor using your component. When you do this, use the mops package Listeners so that the actor can easily set up listeners for the events.

Listeners are synchronous, thus if the user wants to do an async task in response to the action, they should use the timer tool to schedule it during the next round with a delay of 0.

### Add and import the `listeners` mops package

```terminal
mops add listeners
```

```
import Listeners "mo:listeners"
```

### Declare your listener types in your latest migrationn type.mo file

```motoko
  /// `MyActionListener`
  ///
  /// Represents a callback function type that notifiers will implement to be alerted to an action events.
  public type MyActionListener = <system>(Args, transactionId: Nat) -> ();

```

### Implement in your class

add the collection that will hold a particular listener:

```motoko
      // Holds the list of listeners that are notified when a token transfer takes place. 
      /// This allows the ledger to communicate token transfer events to other canisters or entities that have registered an interest.
      private let this_Action_listeners = Listeners.new<TokenTransferredListener>();


      ... //later

    /// `register_listener`
    ///
    /// Registers a new listener or updates an existing one in the provided `listeners` object.
    ///
    /// Parameters:
    /// - `namespace`: A unique namespace used to identify the listener.
    /// - `remote_func`: The listener's callback function.
    /// - `listeners`: The vector of existing listeners that the new listener will be added to or updated in.
    public func register_token_transferred_listener(namespace: Text, remote_func : TokenTransferredListener){
      Listener.register_listener<TokenTransferredListener>(namespace, remote_func, token_transferred_listeners);
    };

    ... //elsewhere call the listener

    //will distribute to all listeners
    Listener.distribute<TokenTransferedListener>(token_transferred_listeners, actionFinal, index);

```

#### Suggested Completion Criteria

- Ensure that the listeners mops package is added and listed in mops.toml
- Ensure that the listeners package in imported in the class
- Ensure that after the class is completed that all state-changing events are identified and that listeners are added, documented, and exposed for each event that a module user might want to listen for.
- Ensure all listener types are defined in the migration's types.mo file.


## Interceptor Pattern

When you offer a function to the users to take some kind of action, particularly one that may perform a state change, it is recommended to use the interceptor pattern. This involves including a nullable parameter that is a function the user can pass to the function that will be executed at a certain point during the life cycle, typically just before work is committed, that passes in the state change information that will be performed, and returns an that object, potentially modified, or an error if the user wants to cancel.

### Add and import the `interceptor` mops package

```terminal
mops add interceptor
```

```
import Interceptor "mo:interceptor"
```

### add an interceptor to your state changing function

```motoko

public fun transfer(caller: Principal, transferArgs: TransferArgs, canTransfer : ?Interceptor.Intercept<Transfer, TransferError>){
   ... // prepare transfer

   let finalTransfer = switch(canTransfer)
    case null {};
    case(?val){
      switch(Interceptor.parse(val(preparedTransfer))){
        case(#ok(val)) val;
        case(#errTrappable(err)) {
          //handle errors that have not committed state via await here;
        };
        case(#err(#awaited(err))){
          //handle error that may have committed state here;
        };
      };
   }
   ... //finish transfer

}

```

#### Suggested Completion Criteria

- Ensure that the listeners mops package is added and listed in mops.toml
- Ensure that the listeners package in imported in the class
- Ensure that after the class is completed that all state-changing events are identified and that listeners are added, documented, and exposed for each event that a module user might want to listen for.
- Ensure all listener types are defined in the migration's types.mo file.


## Time as a Nat

If you need time as a Nat declare the following:

``` motoko
  private func natNow(): Nat{Int.abs(Time.now())};
```

## Principals

While principals can be represented as Text, they should be stored as Principal type as well as be passed in function arguments as Principal types because the system will do length checking and binary comparisons will use fewer cycles than Text.

To convert a principal to text `Principal.toText(p);`
To convert a principal to blob `Principal.toBlob(p);`

## Maps and Sets

When working with Maps and Sets you need to provide the hashing function.

Map.phash = principal hash
Map.thash = text hash
Map.bhash = blob hash
Map.nhahs = nat hash

If the Map key is a complicated type you need to define the hashing algo for that type:

```
public let listItemEq = func(a: ListItem, b:ListItem) : Bool {
    switch(a, b){
      case(#Account(a), #Account(b)) {
        return account_eq(a,b);
      };
      case(#Identity(a), #Identity(b)) {
        return Principal.equal(a,b);
      };
      case(#DataItem(a), #DataItem(b)) {
        return ICRC16.eqShared(a,b);
      };
      case(#List(a), #List(b)) {
        return Text.equal(a,b);
      };
      //todo: is an account with a null subaccount equal to an identity?
      case(_, _) {
        return false;
      };
    };
  };

public func listItemHash32(a : ListItem) : Nat32{

    switch(a){
      case(#Account(a)) {
        return account_hash32(a);
      };
      case(#Identity(a)) {
        return Map.phash.0(a);
      };
      case(#DataItem(a)) {
        return ICRC16.hashShared(a);
      };
      case(#List(a)) {
        return Map.thash.0(a);
      };
    };
    
  };

  public let listItemHash = (listItemHash32, listItemEq);

```

##@ Using `mo:map/Map`  
`let table = Map.new<K,V>()` ‹– store  
`for((a,b) in table.entries()) <- get both.
Every mutating call needs hash function h: `Map.put(table, h, k, v)`.

## available libraries
# Motoko Coding Best Practices

## ClassPlus construction

Modules that expose class based modules should implement the ClassPlus construction.

ClassPlus and Migration is an important infrastructure and data security process for creating a motoko canister and we can't skip it, even during MVP phases.

To do so:

### add and import the class-plus mops package

```terminal
mops add class-plus
```

```motoko
import ClassPlusLib "mo:class-plus";
```

### implement the class plus boiler plate

This code goes outside of the class you are writing and allows a class to easily instantiate the class with a stable stored variable. In this example {ClassName} would be replaced by the class you are creating.

```

  public func Init<system>(config : {
    manager: ClassPlusLib.ClassPlusInitializationManager;
    initialState: State;
    args : ?InitArgs;
    pullEnvironment : ?(() -> Environment);
    onInitialize: ?({ClassName} -> async*());
    onStorageChange : ((State) ->())
  }) :()-> Subscriber{
    ClassPlusLib.ClassPlus<system,
      {ClassName} , 
      State,
      InitArgs,
      Environment>({config with constructor = {ClassName} }).get;
  };
  ```

### ClassPlus constructor

Your class should use a standard class plus constructor of the following pattern. If you need additional fields you should add it to the InitArgs in the current Migration Types file.

```motoko
public class Subscriber(stored: ?State, caller: Principal, canister: Principal, args: ?InitArgs, environment_passed: ?Environment, storageChanged: (State) -> ()){...};
```


#### Suggested Completion Criteria

If you are building a stateful class component:

- Ensure that the class-plus module has been added and is in the mops.toml file.
- Ensure that the class-plus module and patterns are use for any stateful class module. Check patterns: Class Constructor, Int Function, InitArgs Type Definition, State Type Definition, Environment Type Definition, Initial State Definition

## Migration Pattern for stateful Classes

If you are implementing a class module that needs to maintain state, you should implement the Migration Pattern. The upgrade pattern works by a adding a new version each time the underlying structure of the state changes enough that the objects need to be migrated to a new structure.

### Directory Set-up

Under /src create a directory called /migrations

### Create the /src/migration/lib.mo file

This file is the driver for running migrations. It is mostly boilerplate:

```motoko

import D "mo:base/Debug";

import MigrationTypes "./types";
import v0_0_0 "./v000_000_000";
import v0_0_1 "./v000_000_001";

module {

  let debug_channel = {
    announce = true;
  };

  let upgrades = [
    v0_0_1.upgrade,
    // do not forget to add your new migration upgrade method here
  ];

  func getMigrationId(state: MigrationTypes.State): Nat {
    return switch (state) {
      case (#v0_0_0(_)) 0;
      case (#v0_0_1(_)) 1;
      // do not forget to add your new migration id here
      // should be increased by 1 as it will be later used as an index to get upgrade/downgrade methods
    };
  };

  public func migrate(
    prevState: MigrationTypes.State, 
    nextState: MigrationTypes.State, 
    args: MigrationTypes.Args,
    caller: Principal
  ): MigrationTypes.State {

    var state = prevState;
     
    var migrationId = getMigrationId(prevState);
    let nextMigrationId = getMigrationId(nextState);

    while (nextMigrationId > migrationId) {
      debug if (debug_channel.announce) D.print("in upgrade while " # debug_show((nextMigrationId, migrationId)));
      let migrate = upgrades[migrationId];
      debug if (debug_channel.announce) D.print("upgrade should have run");
      migrationId := if (nextMigrationId > migrationId) migrationId + 1 else migrationId - 1;

      state := migrate(state, args, caller);
    };

    return state;
  };

  public let migration = {
    initialState = #v0_0_0(#data);
    //update your current state version
    currentStateVersion = #v0_0_1(#id);
    getMigrationId = getMigrationId;
    migrate = migrate;
  };
};
```

### Create the src/migrations/types.mo file

this file is mostly boilerplate. You can write it as is for new classes.  For upgrades you will need to add new state entries according to the upgrade pattern.

```motoko
import v0_1_0 "./v000_001_000/types";
import Int "mo:base/Int";


module {
  // do not forget to change current migration when you add a new one
  // you should use this field to import types from you current migration anywhere in your project
  // instead of importing it from migration folder itself
  public let Current = v0_1_0;

  public type Args = ?v0_1_0.InitArgs;

  public type State = {
    #v0_0_0: {#id; #data};
    #v0_1_0: {#id; #data:  v0_1_0.State};
    // do not forget to add your new migration state types here
  };
};
```

### Create the initial 000_000_000 version.

create the directory /src/migrations/v000_000_000

add the /src/migrations/v000_000_000/lib.mo

```motoko
import MigrationTypes "../types";
import D "mo:base/Debug";

module {
  public func upgrade(prevmigration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal): MigrationTypes.State {
    return #v0_0_0(#data);
  };
};
```

add the /src/migrations/v000_000_000/types.mo

```motoko
// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead


module {
  public type State = ();
};
```

### Set up your types and/or define new types

You'll need to create a folder /src/migrations/v{semvar}/ with a lib.mo and types.mo file in it. {semvar} should be of the form 000_000_000 with 000 replaced by a 3 digit representation of the mag_min_pat pattern of semvar. We do this to keep them in semantic order in the file directory.

The types file should include at lest the following definitions:

InitArgs - The initialization args the class needs passed into the constructor
Environment - used for instance specific variables that need to be defined at run time and passed in by the canister. This likely need an advanced property that includes icrc85. See the section on ICRC-85.
Stats - used to report out state of the class.
State - used to hold stable state of the class.  This likely need an icrc85 property. See the section on ICRC-85.

example:

```motoko

  public type InitArgs ={
    sampleArg: Text;
  };

  public type Environment = {
    ...
    var example : Example;
    advanced : ?{
      icrc85 : ICRC85Options;
      
    };
  };

  public type Stats = {
    ...
    sampleStateProp: Text
    ...
  };

  ///MARK: State
  public type State = {
    ...
    sampleStateProp: Text
    icrc85: {
      var nextCycleActionId: ?Nat;
      var lastActionReported: ?Nat;
      var activeActions: Nat;
    };
    ...
  };
```

You will need a lib.mo file that defines what needs to happen during the upgrade:

```
import MigrationTypes "../types";
import Time "mo:base/Time";
import v0_1_0 "types";
import D "mo:base/Debug";

module {

  //export
  
  public let BTree = v0_1_0.BTree;
  public let Vector = v0_1_0.Vector;
  public let Set = v0_1_0.Set;
  public let Map = v0_1_0.Map;
  public type EmitableEvent = v0_1_0.EmitableEvent;

  public func upgrade(prevmigration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal): MigrationTypes.State {

    let (name) = switch (args) {
      case (?args) {(args.name)};
      case (_) {("nobody")};
    };

    let state : v0_1_0.State = {
      ...
      var sampleStateProp = name;
      icrc85 = {
        var nextCycleActionId = null;
        var lastActionReported = null;
        var activeActions = 0;
      };
    };

    return #v0_1_0(#data(state));
  };
};
```

### Set up your migration boiler plate in your class

The following code should be before your class declaration:

```motoko

  public let init = Migration.migrate;

  public func initialState() : State {#v0_0_0(#data)};
  public let currentStateVersion = #v0_1_0(#id);

```

### Hydrating your state from the migration state

The following boilerplate will hydrate your class with the state it needs to operate and will expose teh state and environment to the outside:

```motoko

    let environment = switch(environment_passed){
      case(?val) val;
      case(null) {
        D.trap("Environment is required");
      };
    };

    var state : CurrentState = switch(stored){
      case(null) {
        let #v0_1_0(#data(foundState)) = init(initialState(),currentStateVersion, args, canister);
        foundState;
      };
      case(?val) {
        let #v0_1_0(#data(foundState)) = init(val, currentStateVersion, args, canister);
        foundState;
      };
    };

    storageChanged(#v0_1_0(#data(state)));

    let self : Service.Service = actor(Principal.toText(canister));

    public func getState() : CurrentState {state};
    public func getEnvironment() : Environment {environment};
```

#### Suggested Completion Criteria

If you are building a stateful class component:

- Ensure that any stateful class has a migration patter.
- Ensure there is a /src/migrations/ folder
- Ensure that the migrations folder includes the boilerplate for the top-level types.mo and lib.mo boilerplate files and that the boilerplate has been adjusted for the current version.
- Ensure that each migration version has a types.mo file with updated types and that it has a lib.mo file that handles the upgrade
- Ensure that any actor using a stateful class includes the Migration Initialization BoilerPlate
- Ensure that any actor using a stateful class include the hydration boilerplate

## ICRC-85

Most stateful classes should implement ICRC-85 which defines Open Value Sharing parameters and allows users of open source software to fund the creators of the software using cycles from their Internet Computer canisters. 

### Add ovsfixed and timer-tool via mops

```terminal
mops add ovsfixed
mops add timer-tool
```

### Classes should import ovsfixed, timer-tool, and Timer;

```motoko
import ovsfixed "mo:ovs-fixed";
import TT "mo:timer-tool";
import Timer: "mo:base/Timer";
```

### Classes should put in the ovs boiler plate:

the following code goes in the class and is mostly boilerplate. the calulation of how many cycls to charge may be customized, but it is traditional to charge 1 XDR (1_000_000_000_000 cycles) per month plus some usage per action up to a rational limit almost certainly under 100 XDR.

```motoko
    ///////////
    // ICRC85 ovs
    //////////

    private var _icrc85init = false;

    private func ensureCycleShare<system>() : async*(){
      if(_icrc85init == true) return;
      _icrc85init := true;
      ignore Timer.setTimer<system>(#nanoseconds(OneDay), scheduleCycleShare);
      environment.tt.registerExecutionListenerAsync(?"icrc85:ovs:shareaction:icrc72subscriber", handleIcrc85Action : TT.ExecutionAsyncHandler);
    };

    private func scheduleCycleShare<system>() : async() {
      //check to see if it already exists
      debug d(debug_channel.announce, "in schedule cycle share");
      switch(state.icrc85.nextCycleActionId){
        case(?val){
          switch(Map.get(environment.tt.getState().actionIdIndex, Map.nhash, val)){
            case(?time) {
              //already in the queue
              return;
            };
            case(null) {};
          };
        };
        case(null){};
      };

      let result = environment.tt.setActionSync<system>(Int.abs(Time.now()), ({actionType = "icrc85:ovs:shareaction:icrc72subscriber"; params = Blob.fromArray([]);}));
      state.icrc85.nextCycleActionId := ?result.id;
    };

    private func handleIcrc85Action<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error>{
      D.print("in handle timer async " # debug_show((id,action)));
      switch(action.actionType){
        case("icrc85:ovs:shareaction:icrc72subscriber"){
          await* shareCycles<system>();
          #awaited(id);
        };
        case(_) #trappable(id);
      };
    };

    private func shareCycles<system>() : async*(){
      debug d(debug_channel.announce, "in share cycles ");
      let lastReportId = switch(state.icrc85.lastActionReported){
        case(?val) val;
        case(null) 0;
      };

      debug d(debug_channel.announce, "last report id " # debug_show(lastReportId));

      let actions = if(state.icrc85.activeActions > 0){
        state.icrc85.activeActions;
      } else {1;};

      state.icrc85.activeActions := 0;

      debug d(debug_channel.announce, "actions " # debug_show(actions));

      var cyclesToShare = 1_000_000_000_000; //1 XDR

      if(actions > 0){
        let additional = Nat.div(actions, 10000);
        debug d(debug_channel.announce, "additional " # debug_show(additional));
        cyclesToShare := cyclesToShare + (additional * 1_000_000_000_000);
        if(cyclesToShare > 100_000_000_000_000) cyclesToShare := 100_000_000_000_000;
      };

      debug d(debug_channel.announce, "cycles to share" # debug_show(cyclesToShare));

      try{
        await* ovsfixed.shareCycles<system>({
          environment = do?{environment.advanced!.icrc85};
          namespace = "com.panindustrial.libraries.icrc72subscriber";
          actions = actions;
          schedule = func <system>(period: Nat) : async* (){
            let result = environment.tt.setActionSync<system>(Int.abs(Time.now()) + period, {actionType = "icrc85:ovs:shareaction:icrc72subscriber"; params = Blob.fromArray([]);});
            state.icrc85.nextCycleActionId := ?result.id;
          };
          cycles = cyclesToShare;
        });
      } catch(e){
        debug d(debug_channel.announce, "error sharing cycles" # Error.message(e));
      };

    };

    let OneDay =  86_400_000_000_000;
```

### Call ensureCycleShare(); when the monetized action of the component is used:

Ths action and location will vary from class to class, but this must be called to schedule the cycleshare.

```motoko
await* ensureCycleShare();
```

### Add an increment to action

For each action you want to measure you need to increment the activeActions:

```motoko
state.icrc85.activeActions += 1;
```

### Define an openvaluesharing.mo file in your /src directory

This is mostly boilerplate, but replace {myClass} with he class name:

```motoko
module {
  public let openvaluesharing = {
    platform = "icp";
    asset = "cycles";
    payment_mechanism = "icrc85_deposit_cycles_notify";
    custom = [
      {
        key = "namespace";
        value = #text("com.panindustrial.libraries.{myClass}");
      },
      {
        key = "principal";
        value = #text("q26le-iqaaa-aaaam-actsa-cai");
      }
    ]
  };
};

```

#### Suggested Completion Criteria

- Ensure the ovs-fixed mops package has been added and is in the mops.toml file.
- Ensure the ovs-fixed mops package is imported into the class
- Ensure the class has the ovs boilerplate
- Ensure that ensureCycleShare() is called when class is first used
- Ensure the active actions have been identified and that code exists to increment the activeActions
- Ensure that openvalueshare.mo is defined in the root

## Listener Pattern

It is recommended that you expose the execution of code, particularly state changes, to the actor using your component. When you do this, use the mops package Listeners so that the actor can easily set up listeners for the events.

Listeners are synchronous, thus if the user wants to do an async task in response to the action, they should use the timer tool to schedule it during the next round with a delay of 0.

### Add and import the `listeners` mops package

```terminal
mops add listeners
```

```
import Listeners "mo:listeners"
```

### Declare your listener types in your latest migrationn type.mo file

```motoko
  /// `MyActionListener`
  ///
  /// Represents a callback function type that notifiers will implement to be alerted to an action events.
  public type MyActionListener = <system>(Args, transactionId: Nat) -> ();

```

### Implement in your class

add the collection that will hold a particular listener:

```motoko
      // Holds the list of listeners that are notified when a token transfer takes place. 
      /// This allows the ledger to communicate token transfer events to other canisters or entities that have registered an interest.
      private let this_Action_listeners = Listeners.new<TokenTransferredListener>();


      ... //later

    /// `register_listener`
    ///
    /// Registers a new listener or updates an existing one in the provided `listeners` object.
    ///
    /// Parameters:
    /// - `namespace`: A unique namespace used to identify the listener.
    /// - `remote_func`: The listener's callback function.
    /// - `listeners`: The vector of existing listeners that the new listener will be added to or updated in.
    public func register_token_transferred_listener(namespace: Text, remote_func : TokenTransferredListener){
      Listener.register_listener<TokenTransferredListener>(namespace, remote_func, token_transferred_listeners);
    };

    ... //elsewhere call the listener

    //will distribute to all listeners
    Listener.distribute<TokenTransferedListener>(token_transferred_listeners, actionFinal, index);

```

#### Suggested Completion Criteria

- Ensure that the listeners mops package is added and listed in mops.toml
- Ensure that the listeners package in imported in the class
- Ensure that after the class is completed that all state-changing events are identified and that listeners are added, documented, and exposed for each event that a module user might want to listen for.
- Ensure all listener types are defined in the migration's types.mo file.


## Interceptor Pattern

When you offer a function to the users to take some kind of action, particularly one that may perform a state change, it is recommended to use the interceptor pattern. This involves including a nullable parameter that is a function the user can pass to the function that will be executed at a certain point during the life cycle, typically just before work is committed, that passes in the state change information that will be performed, and returns an that object, potentially modified, or an error if the user wants to cancel.

### Add and import the `interceptor` mops package

```terminal
mops add interceptor
```

```
import Interceptor "mo:interceptor"
```

### add an interceptor to your state changing function

```motoko

public fun transfer(caller: Principal, transferArgs: TransferArgs, canTransfer : ?Interceptor.Intercept<Transfer, TransferError>){
   ... // prepare transfer

   let finalTransfer = switch(canTransfer)
    case null {};
    case(?val){
      switch(Interceptor.parse(val(preparedTransfer))){
        case(#ok(val)) val;
        case(#errTrappable(err)) {
          //handle errors that have not committed state via await here;
        };
        case(#err(#awaited(err))){
          //handle error that may have committed state here;
        };
      };
   }
   ... //finish transfer

}

```

#### Suggested Completion Criteria

- Ensure that the listeners mops package is added and listed in mops.toml
- Ensure that the listeners package in imported in the class
- Ensure that after the class is completed that all state-changing events are identified and that listeners are added, documented, and exposed for each event that a module user might want to listen for.
- Ensure all listener types are defined in the migration's types.mo file.


## Time as a Nat

If you need time as a Nat declare the following:

``` motoko
  private func natNow(): Nat{Int.abs(Time.now())};
```

## Principals

While principals can be represented as Text, they should be stored as Principal type as well as be passed in function arguments as Principal types because the system will do length checking and binary comparisons will use fewer cycles than Text.

To convert a principal to text `Principal.toText(p);`
To convert a principal to blob `Principal.toBlob(p);`

## Maps and Sets

When working with Maps and Sets you need to provide the hashing function.

Map.phash = principal hash
Map.thash = text hash
Map.bhash = blob hash
Map.nhahs = nat hash

If the Map key is a complicated type you need to define the hashing algo for that type:

```
public let listItemEq = func(a: ListItem, b:ListItem) : Bool {
    switch(a, b){
      case(#Account(a), #Account(b)) {
        return account_eq(a,b);
      };
      case(#Identity(a), #Identity(b)) {
        return Principal.equal(a,b);
      };
      case(#DataItem(a), #DataItem(b)) {
        return ICRC16.eqShared(a,b);
      };
      case(#List(a), #List(b)) {
        return Text.equal(a,b);
      };
      //todo: is an account with a null subaccount equal to an identity?
      case(_, _) {
        return false;
      };
    };
  };

public func listItemHash32(a : ListItem) : Nat32{

    switch(a){
      case(#Account(a)) {
        return account_hash32(a);
      };
      case(#Identity(a)) {
        return Map.phash.0(a);
      };
      case(#DataItem(a)) {
        return ICRC16.hashShared(a);
      };
      case(#List(a)) {
        return Map.thash.0(a);
      };
    };
    
  };

  public let listItemHash = (listItemHash32, listItemEq);

```

##@ Using `mo:map/Map`  
`let table = Map.new<K,V>()` ‹– store  
`for((a,b) in table.entries()) <- get both.
Every mutating call needs hash function h: `Map.put(table, h, k, v)`.

## available libraries

To use a library in your motoko file you must import it:

Many items are available in Base. Examples:

import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";

Map and Set are imported as such:

import Map "mo:map/Map";
import Set "mo:map/Set";

The StableBTreeMap is an important library that keeps items in a defined order.

import BTree "mo:stablebtreemap";

## Pagination

When returning a paginated query, use the `?prev: Type, ?take: Nat` patter.

Use a Buffer to accumulate the results:

```
    // Endpoint: get_items with pagination
    // Returns an array of ItemDetail
    public func get_items(prev: ?Principal, take: ?Nat) : async [ItemDetail] {
      let useTake = switch(take) {
        case(null) { 100 };
        case(?val) { val };
      };

      let aBuffer = Buffer.Buffer<ItemDetail>(1);
      var bFoundStart = switch(prev) {
        case(null) { true };
        case(?val) { false };
      };

      label proc for(thisItem in Map.entries(items)) {
        if(bFoundStart == false and ?thisItem.0 == prev) {
          bFoundStart := true;
          continue proc;
        } else {
          continue proc;
        };
        aBuffer.add(thisItem.1);
        if(aBuffer.size() >= useTake) {
          break proc;
        };
      };

      return Buffer.toArray(aBuffer);
    };
```

## Blocks

All Parentheses blocks `{...}` should be followed by a an ";" in motoko including func blocks. ALL BLOCKS NEED a trailing `;`. 

example - note the semi-colon at the end of the ;

```
private func inNamespace(){
  let x =1
  return x
};
```

If you receive an error like:
```
seplist(<dec_field>,<semicolon>) -> <dec_field> . ; seplist(<dec_field>,<semicolon>) 

>     **public** func ...
```

..then you have likely missed a semi-colon on the block above.

## Continue and Break

To use continue and break for loops you need to use a lable.

```
label proc for(thisItem in myArray.vals()){
  if(thisItem == 4) break proc;
  //... more code
};
```

## Modules

All motoko files that want to expose public actors should have a module wrapper ` module {//code }` after import.

## Imports

Imports only go at the top of files.

## Library Functions that fulfill query requests should not be async. 

## Converting candid to motoko

Note, that candid uses a different syntax to motoko for records and variants.

Motoko records do not use the key word `record`. 

The types they use are usually the capitalized versions of the candid types.

ie:

nat -> Nat
principal -> Principal

Variants do not use the key word `variant` but instead use a hashtag in front of the variant member

ie:

variant {one: nat; two}; -> {#one: Nat; #two}

## Type checking files

Do not type check a motoko file until after you have edited it.

## Unused parameters  
Motoko’s `M0194` warning is triggered if a function parameter is not
referenced.  
Rename throw-away parameters to `_` (or `_caller`, `_args`, …) to silence
the warning _and_ signal intent.

```motoko
public func upgrade(
  _prev : MigrationTypes.State,
  _args : MigrationTypes.Args,
  _caller : Principal,
  _canister : Principal
) : MigrationTypes.State {
  // …
};
```

## Exhaustive variant matching  
Whenever you destructure a variant with `let #tag(…) =`, you _must_
cover every tag. If you only care about one tag, wrap the pattern in a
`switch`, or include a `_` fall-through.

```motoko
switch init(initial, currentVersion, args, canister) {
  case (#v0_1_0(#data s)) { state := s };
  case (_)               { Debug.trap("unexpected migration tag") };
};
```

## Arrays: remember the module prefix 

`slice`, `sort`, `find`, `indexOf`, `clone`, … are **functions** on
`mo:base/Array`, not methods on the array value.

## Option handling

Use `do ? { … }` or a null-check before `x!`.  
Never write `something!` outside those two contexts.

## Common Compile-time Foot-guns   🚧


1. **Unused parameters (`M0194`)** – prefix with `_`.
2. **Variant exhaustiveness (`M0145`)** – cover every tag.
3. **Array helpers** – use `Array.slice(arr, …)`, _not_ `arr.slice`.
4. **Map.entries** returns `(map,hash)` – keep both.
5. **Mutable state** – declare record fields `var`.
6. **Option unwrap** – only inside `do ? {}` or after null guard.
7. **Module shadowing** – beware local `Array`, `Map`, etc.
8. **Migration.migrate tuple** – `(prev,next,args,caller,canister)`.

## Avoid Array.append

This is a very slow function. Create a buffer to build up or append an array especially when there are multiple or unknown number of items.

## Suggested Completion Criteria

- Check that Principals are stored as Principal type and not Text
- Check that Principals are passed in function args as Principal types and not Text.
To use a library in your motoko file you must import it:

Many items are available in Base. Examples:

import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";

Map and Set are imported as such:

import Map "mo:map/Map";
import Set "mo:map/Set";

Maps are useful for Indexs that point to records in determanistic BTrees.  let userIndex = Map.new<Principal, Nat>;

The StableBTreeMap is an important library that keeps items in a defined order.  BTrees should bhe used when data needs to be read out in determanistic order for report or queries.

import BTree "mo:stablebtreemap";

## Pagination

When returning a paginated query, use the `?prev: Type, ?take: Nat` patter.

Use a Buffer to accumulate the results:

```
    // Endpoint: get_items with pagination
    // Returns an array of ItemDetail
    public func get_items(prev: ?Principal, take: ?Nat) : async [ItemDetail] {
      let useTake = switch(take) {
        case(null) { 100 };
        case(?val) { val };
      };

      let aBuffer = Buffer.Buffer<ItemDetail>(1);
      var bFoundStart = switch(prev) {
        case(null) { true };
        case(?val) { false };
      };

      label proc for(thisItem in Map.entries(items)) {
        if(bFoundStart == false and ?thisItem.0 == prev) {
          bFoundStart := true;
          continue proc;
        } else {
          continue proc;
        };
        aBuffer.add(thisItem.1);
        if(aBuffer.size() >= useTake) {
          break proc;
        };
      };

      return Buffer.toArray(aBuffer);
    };
```

## Blocks

All Parentheses blocks `{...}` should be followed by a an ";" in motoko including func blocks. ALL BLOCKS NEED a trailing `;`. 

example - note the semi-colon at the end of the ;

```
private func inNamespace(){
  let x =1
  return x
};
```

If you receive an error like:
```
seplist(<dec_field>,<semicolon>) -> <dec_field> . ; seplist(<dec_field>,<semicolon>) 

>     **public** func ...
```

..then you have likely missed a semi-colon on the block above.

## Continue and Break

To use continue and break for loops you need to use a lable.

```
label proc for(thisItem in myArray.vals()){
  if(thisItem == 4) break proc;
  //... more code
};
```

## Modules

All motoko files that want to expose public actors should have a module wrapper ` module {//code }` after import.

## Imports

Imports only go at the top of files.

## Library Functions that fulfill query requests should not be async. 

## Converting candid to motoko

Note, that candid uses a different syntax to motoko for records and variants.

Motoko records do not use the key word `record`. 

The types they use are usually the capitalized versions of the candid types.

ie:

nat -> Nat
principal -> Principal

Variants do not use the key word `variant` but instead use a hashtag in front of the variant member

ie:

variant {one: nat; two}; -> {#one: Nat; #two}

## Type checking files

Do not type check a motoko file until after you have edited it.

## Unused parameters  
Motoko’s `M0194` warning is triggered if a function parameter is not
referenced.  
Rename throw-away parameters to `_` (or `_caller`, `_args`, …) to silence
the warning _and_ signal intent.

```motoko
public func upgrade(
  _prev : MigrationTypes.State,
  _args : MigrationTypes.Args,
  _caller : Principal,
  _canister : Principal
) : MigrationTypes.State {
  // …
};
```

## Exhaustive variant matching  
Whenever you destructure a variant with `let #tag(…) =`, you _must_
cover every tag. If you only care about one tag, wrap the pattern in a
`switch`, or include a `_` fall-through.

```motoko
switch init(initial, currentVersion, args, canister) {
  case (#v0_1_0(#data s)) { state := s };
  case (_)               { Debug.trap("unexpected migration tag") };
};
```

## Arrays: remember the module prefix 

`slice`, `sort`, `find`, `indexOf`, `clone`, … are **functions** on
`mo:base/Array`, not methods on the array value.

## Option handling

Use `do ? { … }` or a null-check before `x!`.  
Never write `something!` outside those two contexts.

## Common Compile-time Foot-guns   🚧


1. **Unused parameters (`M0194`)** – prefix with `_`.
2. **Variant exhaustiveness (`M0145`)** – cover every tag.
3. **Array helpers** – use `Array.slice(arr, …)`, _not_ `arr.slice`.
4. **Map.entries** returns `(map,hash)` – keep both.
5. **Mutable state** – declare record fields `var`.
6. **Option unwrap** – only inside `do ? {}` or after null guard.
7. **Module shadowing** – beware local `Array`, `Map`, etc.
8. **Migration.migrate tuple** – `(prev,next,args,caller,canister)`.

## Avoid Array.append

This is a very slow function. Create a buffer to build up or append an array especially when there are multiple or unknown number of items.

## Suggested Completion Criteria

- Check that Principals are stored as Principal type and not Text
- Check that Principals are passed in function args as Principal types and not Text.

# Best Practices for designing State Objects in a Motoko Class

## Whole Named Types

Do not type ultimate state variables with record type descriptions. Always promote the item into a named item until you get to a static type.

```motoko

//do not do the following
public type State = {
  item : {
    x: Nat;
    y: Text;
  };
};

//instead promote the record type to it's own type. this is important for candid descriptors during compile.

public type ItemDetail = {
  x: Nat;
  y: Text;
};

public type State = {
  item : ItemDetail;
};
```

## State variables that will change

If a state variable or one of its properties will be changed by the program it should be marked as mutable by using the `var` key word.

Each type that has a var in it needs a corresponding XShared type that can be used to return data out of actors and a function that recasts var members as non-var types.

```motoko
public type User ={
  userId: Nat;
  var infractions: Nat;
};

public type UserShared ={
  userId: Nat;
  infractions: Nat;
};

public func shareUser(x : User) : UserShared{
  {
    x with
    infractions: x.infractions
  }
};
```

### Collections

- Do not store dynamic collections in Arrays as append operations are expensive.
- For collections that will only ever grow you can use Vector.
- For Key-Value collections you can use a Map when you want to preserve insertion order and have fast random access by key.
- For Key-Value collection where you will need to paginate results by a reliable order you can use stableheapbtreemap.
- For Collections with unique items use Set to avoid duplicates.
- When nested collections are necessary, apply the same rules as above.
- When you have nested collections, your ultimate objects need to have an id and you will likely need index collections that point internal keys to the id for quick look up.

```motoko

public type User = {
  userId: Nat; //item ID
  dependents: Set.Set<User>;
};

public type InventoryItem = {
  inventoryItemId: Nat; //item ID
  var description: Text;
  var quantity: Nat;
};

public type Categories : Text;

public type State = {
  log : Vector.Vector<Text>; //will only ever grow
  nestedCollectionUsers : BTree.BTree<Nat, User>; //nested collection; Ordered by User.userId.
  nestedDependentsIndex = Map.Map<User, Nat>; //maps a Dependent to it's parent User record; <User, User.userId>
  insertionOrderCollection = Map.Map<Nat, InventoryItem>; <InventoryItem.inventoryItemId, InventoryItem>
  uniqueSet = Set.Set<Categories>;
};

```

Final State fields for collections _must_ use Vector, Map, Set or BTree and NEVER Array.  This is internal stable state and will not be shared with other actors. For Stats and other sharable items you can build up buffers to dump to arrays.

## Self lint rules

- Did you use a Vector/Map/BTree for all dynamic collections? - Is every array in the stable state justified by immutability and small/fixed size?

- # Getting started - pic.js Testing

## JavaScript runtime environment

Tests written with PicJS are executed in a JavaScript runtime environment, such as [NodeJS](https://nodejs.org/en).


## Package manager

PicJS is a JavaScript/TypeScript package distributed on [NPM](https://www.npmjs.com/package/@hadronous/pic). To install and manage NPM packages, you will need to have an NPM-compatible package manager.

- [npm](https://nodejs.org/en/learn/getting-started/an-introduction-to-the-npm-package-manager)
  - This is the official package manager for [NodeJS](https://nodejs.org/en) and comes pre-installed.
  - Beginners should stick with this option.

## Test runner

PicJS tests can be run with any test runner that runs on [NodeJS](https://nodejs.org/en) or [Bun](https://bun.sh/) (in theory the same should be true for [Deno](https://deno.com/), but that is not actively tested).

The following test runners are actively tested and officially supported:

- [Jest](https://jestjs.io/)
  - Recommended if you're new to JavaScript testing because it has the largest community and is the most widely used.
  - See the [Jest guide](./using-jest) for details on getting started with Jest and PicJS.


# Using Jest

[Jest](https://jestjs.io) is a JavaScript testing framework that is widely used in the JavaScript community. It is recommended for beginners because it has the largest community and is the most widely used. Jest is also the officially supported test runner for PicJS.


## Writing tests

[Jest](https://jestjs.io) tests are very similar to tests written with [Jasmine](https://jasmine.github.io), or [Vitest](https://vitest.dev) so they will feel very familiar to developers who have used these frameworks before.

The basic skeleton of all PicJS tests written with [Jest](https://jestjs.io) will look something like this:

```ts title="tests/example.spec.ts"
// Import generated types for your canister
import { type _SERVICE } from '../../declarations/backend/backend.did';

// Define the path to your canister's WASM file
export const WASM_PATH = resolve(
  import.meta.dir,
  '..',
  '..',
  'target',
  'wasm32-unknown-unknown',
  'release',
  'backend.wasm',
);

// The `describe` function is used to group tests together
// and is completely optional.
describe('Test suite name', () => {
  // Define variables to hold our PocketIC instance, canister ID,
  // and an actor to interact with our canister.
  let pic: PocketIc;
  let canisterId: Principal;
  let actor: Actor<_SERVICE>;

  // The `beforeEach` hook runs before each test.
  //
  // This can be replaced with a `beforeAll` hook to persist canister
  // state between tests.
  beforeEach(async () => {
    // create a new PocketIC instance
    pic = await PocketIc.create(process.env.PIC_URL);

    // Setup the canister and actor
    const fixture = await pic.setupCanister<_SERVICE>({
      idlFactory,
      wasm: WASM_PATH,
    });

    // Save the actor and canister ID for use in tests
    actor = fixture.actor;
    canisterId = fixture.canisterId;
  });

  // The `afterEach` hook runs after each test.
  //
  // This should be replaced with an `afterAll` hook if you use
  // a `beforeAll` hook instead of a `beforeEach` hook.
  afterEach(async () => {
    // tear down the PocketIC instance
    await pic.tearDown();
  });

  // The `it` function is used to define individual tests
  it('should do something cool', async () => {
    const response = await actor.do_something_cool();

    expect(response).toEqual('cool');
  });
});
```

You can also check out the official [Jest getting started documentation](https://jestjs.io/docs/getting-started) for more information on writing tests.

## Null parameters

Candid IDL types for null do not map to null. For an opt, use an array wrapper.  For example, for a ?Nat of ?9 you would do [9n]. For a null, you use an empty array, so a null for ?Nat would be [].

## Nats and BigInts.

Nats and Ints are represented in typescript as a BigInt. For constants, you can put an `n` after the number. For example, 9 would be 9n.  This is only for unbounded Nat and Int types.

## Upgrades and Installs

You need to provide a sender that is a controller and you need to format the IDL as follows for the parameters and they must be provided even if you have them as null.

Example:

await pic.upgradeCanister({ canisterId: main_fixture.canisterId, wasm: sub_WASM_PATH, arg: IDL.encode(mainInit({IDL}), [[]]), sender: admin.getPrincipal() });

Pic has these function:

Methods
create()
setupCanister()
createCanister()
startCanister()
stopCanister()
installCode()
reinstallCode()
upgradeCanister()
updateCanisterSettings()
createActor()
createDeferredActor()
queryCall()
updateCall()
tearDown()
tick()
getControllers()
resetTime()
resetCertifiedTime()
setTime()
setCertifiedTime()
advanceTime()
advanceCertifiedTime()
getPubKey()
getCanisterSubnetId()
getTopology()
getBitcoinSubnet()
getFiduciarySubnet()
getInternetIdentitySubnet()
getNnsSubnet()
getSnsSubnet()
getApplicationSubnets()
getSystemSubnets()
getCyclesBalance()
addCycles()
setStableMemory()
getStableMemory()
getPendingHttpsOutcalls()
mockPendingHttpsOutcall()
