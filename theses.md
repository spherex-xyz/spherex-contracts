


## What are Theses

Theses are the basic ideas, the *heuristics* we use to determine if a given transaction or a call is malicious. A Thesis usually comes in the form of a theoretical correlation between some aspects of the transaction, and the chances that transaction is an attack.

To use an example from the classical cyber world - One theses suggests that if a process creates a thread, pauses it and then writes to a code section, this process is probably malicious. This is a correlation between some actions of the process, and the chances it is a malicious process.

The SphereX theses are the same in that regard - they define the parameters by which SphereXEngine determines if a transaction is malicious or not.

Currently, there are two variants of one thesis implemented in SphereXEngine (the prefix-call-flow and the prefix-transaction-flow which are [variants of the call flow thesis](#variations)), but the infrastructure of the usage of other thesis is already part of the system (and if the `SphereXProtected` and `SphereXEngine` contracts)

**Table of contents**

- [List of Theses](#list-of-theses)
  - [Call-Flow (and Transaction-Flow)](#call-flow-and-transaction-flow)
    - [Basic idea](#basic-idea)
    - [Variations](#variations)
    - [Implementations](#implementations)
      - [Transaction flow considerations and implementation](#transaction-flow-considerations-and-implementation)
      - [Call flow considerations and implementation](#call-flow-considerations-and-implementation)
    - [Additional Notes and Known Issues](#additional-notes-and-known-issues)
  - [Future Features](#Future)
# Existing Theses

## Call-Flow (and Transaction-Flow)

### Basic idea
Lets define for a minute a call flow: every program is comprised of various function calls. If we would mark every function in a program with a unique, positive integer id, and then trace the flow of the program, every time a function is called, we will add it's id to a growing vector of integers, and every time the function returns, we will add the negative value of that id to the vector.

What we get at the end of this process, is a vector that represents the various calls of functions in the program - the flow of the program between different peaces of code.

This idea is as relevant in Web3 as in classic programs: we collect the data (that is, append values to our growing vector) in every contract we have control over.

So **the basic idea** of this thesis is that for each given protocol there is a finite set of valid flows (which represent a set of valid usages), and if we spot a transaction that diverges from these expected flows, there is a good change it's an attack.

### Variations

- **Call flow** - The most basic version of this thesis is about collecting said vector starting with the first external call to any contract in the protocol, and ending when that first call ends. Essentially, the flow ends when the sum of the vector goes back to being `0`.
- **Tx flow** - Transaction flow - Because an external call to the protocol can be made multiple times in a single transaction (by another contract), we can gather more information in the vector - until the end of the transaction. So if 2 different external calls appeared in the same transaction, the TX flow will see them as one big long vector, while the Call-Flow variant will see them as 2 vectors.
  - Note that Tx flow actually provides more accurate information, we know that the vector we are watching includes all the transaction. while with call flow we dont have any way to know if this vector represent the whole TX or only part of it.

### Implementations

Currently there are two variants implemented in the engine: the *Tx flow* variant and a *Call flow* variant. Both are implemented with ***prefix checks*** (explained shortly). The `SphereXEngine` contract can be configured to use either.

#### Transaction flow considerations and implementation

First consideration is gas: we don't want to use a dynamic array to save the flow vector, because storing, updating and then comparing the values will be rather costly. What we did instead is to create a "rolling hash" instead of a vector. This is a simple recursion. We start with some number, and every time we get an id for a function (to enter it or exit it) we replace the value with the `keccak256` hash of the previous value with the new id.

```solidity§
bytes32 hash = 1;

function add_call_flow_element(int id) {
    hash = keccak256(abi.encode(id, hash))
}

```

Now that we dealt with the costs, we need to look at a logical problem: A given smart contract X can call external and public functions in another contract Z. While each such function in Z can choose to do some actions before it's return, there is no way for a function in Z to be sure that X will not make another call to some other function in Z. This is a complicated way to say that we have no way of knowing when a transaction is about to end, and make the comparison to the allowed list of transactions.

The way we solved this, is to actually test the growing vector every time we exit a `public` or `external` functions.
So if we have a flow for example `[2, 3, -3, 1, 4, -4, -1, -2]` a test of validity for this flow will be done at:
```js
[2,3,-3],
[2, 3, -3, 1, 4, -4],
[2, 3, -3, 1, 4, -4, -1]
[2, 3, -3, 1, 4, -4, -1, -2]

// Please remember that we don't actually save each array, only the rolling hash of each array
```
(that is if all those functions are public or external. If not, then some of the flows can be emitted).

So in essence, we need to save not only the allowed flows, but also some prefixes of these allowed flows. This is why this method is called ***Transaction Prefix Flow***.

Ok, so we talked about gas, and the problem of not knowing when a transaction ends, but we still have a third problem - we don't know when a new transaction starts. The transaction hash is not known when it is being executed, but we do know the origin of that transaction and it's block, and we all agree that if one of these has changed from the last check (`tx.origin` or `block.number`) then we are in a new transaction. So the way we know when to reset our "vector" (actually, our hash) is by saving the `tx.origin` and `block.number` in each step, and if one of them (or both) changed, it's time to start a new flow. This creates a known issue which you can read about in the next section

#### Call flow considerations and implementation

The gas considerations for call-flow are the same as for the TX-flow and so we use the same solution: saving the *rolling hash* of the call vector, and not the vector itself.

However the other two problems we discussed (knowing that a new call flow has started and when it is finished) should not exist: we should be able to track the depth of the call stack, and when this depth is back to 0 (meaning the external call has ended), we should check the flow (allow or revert it) and then reset all the tracking mechanism (the hash, and the depth counter). So if the depth is 0 before the start of a function, we are at the beginning of a flow, and if it's 0 after a function, we are at the end of the flow.

Unfortunately, this mechanism can be attacked and bypassed using arbitrary external calls which you can read about [here](https://programtheblockchain.com/posts/2018/08/02/contracts-calling-arbitrary-functions/). We will not go too deep into this but the crux of the matter is this: if our client's contract allows for **arbitrary external calls**, an attacker can use it to increase the depth of the tracked flow, so it will never reach 0, and the flow will never be tested. To overcome this exploit, our implementation of the call flow **also uses prefixes** just like the tx-flow. We save not only the allowed flow, but also all prefixes of it that represent calls of public or external functions.

> One more implementation note, because of gas costs, we actually start the depth at 1, add and subtract as required, and check to see if we are back at 1 to figure out if the call is ended. So you can say our depth check is 1-based :)

### Additional Notes and Known Issues

- Contracts that use inline assembly for the return statements actually bypass the suffix of the modifier that decorates that function. In our case, this means that the information about the end of the function is never sent to the `engine`, and we have a vector with a positive opening id, but no corresponding closing (negative) id.
- If the same user managed to execute 2 distinct transactions that touch our contracts in the same block in some way, without any other user executing a transaction that touches the protocol, those 2 distinct transactions will be interpreted as a ***Single transaction***.


## Future
Future theses include different features that are currently under research, such as storage, gas, etc.

