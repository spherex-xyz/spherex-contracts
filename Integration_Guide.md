The Process of integration if Spherex Protection into the smart contracts is usually done (at least at this point) by the tech team at Spherex.

That being said, and because the developer of the smart contracts will always know it better than we do, it is important for you as the developer of the protected contract to undestand the process of integration and the various aspects of that process.


## Protection  - the big picture
- Spherex protection works by identifiying suspicious and malicious behavior patterns of a transaction as it is being executed by the protocol (between any number of contracts)
- The granularity of the protection is **functions** - meaning the smallest unit of code we track behaviour of is a function.
  - The data collected and used for each function in each protocol may change, depending on various factors (gas cost in the chain, past history, client requests, etc.)
- `pure` and `view` functions are not protected, as they do not change the state of the contract , and therefore do not require protection.

## Some terms and defenitions

#### Contracts in the system

- **Protected Contract**: The smart contract that is being protected by Spherex.
- **Spherex Engine**: This is a smart contract written by spherex that acts as *the brain* of the protection system.
  - The protected contracts in the protocol communicate with the Spherex Engine to perform various operations (send information and get approval for the current state of the transaction).

#### Entities and addresses

- **Operator**: The wallet that actaully configures and updates the protection of the contract. This can be either the protocol developer/manager, the SphereX tech team, or any other wallet that has the permission to do so.
- **Admin**: The wallet that controls the operator. This should be the protocol owner, and it's meant as a protection against a rogue operator.
- **Allowed Senders** - one of our protection mechanisms is to only allow pre approved addresses to send data to the engine. So this is just a list of all the contracts that are allowed to send data to the engine.
  - This becomes important if you deploy contracts dynamically (for example, using the factory pattern).

Please note that if you decide to manage and configure the protocol (or just its protection) with some kind of a contract (like a mutisig, or a DAO wallet), you will need to set the various roles accordingly.

## Integration

### Inline vs Proxy

ThephereX protection has 2 ways to integrate with a given smart contract:
1. **Inline**: The protection logic is integrated directly into the smart contract as function *decorators*, by inhereting from the contract `SphereXProtected`. This is used for immutable contracts.
1. **Proxy**: The protection logic is integrated into a proxy contract that wraps the protected contract. It is the proxy that communicates with the engine before and after passing the calls to the implementation contract. The integration is done by replacing the existing proxy with one of the SphereX proxies (there are many variation of the *protected proxy*) or inhereting directly from `SphereXProtectedProxy`. This is used for mutalbe\upgradable contracts.
   - Proxy protection also allows to **configure what function are protected after deployments**. So you can decide for a given function that it does not require protection, and configure the engine and proxy to ignore it.

It is entirly possible (and quite common) to find both types of protection for contracts in a given protocol, as some of the underlying contracts are immutable and some are mutable.

### Configuration

All protected contracts (inline or proxy) have these configuration functions:
- `setAdmin` - the admin for the protected logic, can only replace the operator
- `setOperator` - the operator is the entity managing the protected contract
- `setEngine` - set the address of the engine → where we will send data about the behavior of the contract

In addition, a protected proxy also has this configuration function:
- `setProtectedSigs` - the functions we wish to protect and send data about their execution to the engine.
  - This is the mechansim with which we configure what functions to protect or ignore in the protection process.
  - **DO NOT** set view or pure function it will cause the engine to revert.

### Deployment

The constructor of our contracts expects three arguments: the **admin**, the **operator** and the **engine**. usually we will set them as follows:

- Admin - `msg.sender` (if we see the integrated contract receives owner as an argument we will use it as the admin)
- Operator - `address(0)`
- Engine - `address(0)`

#### Special cases

- If you are using a **contract to deploy your contract** you probably should change the admin to be `tx.origin` rather then msg.sender
- If u have a **factory pattern** in your project this is a bit more complicated:
    1. the factory should hold the admin, operator and the engine in his storage (or he should be able to retrieve them somehow) since when it deployes a new contract it should be able to pass them to the deployed contract.
    2. when the factory deploys a new contract it should call the function `_addAllowedSenderOnChain` in the engine to add the address of the new deployed contract.
        1. one of our protection mechanisms is to only allow pre approved addresses to send data to the engine, so the factory should add the new address to the engine allowed list of addresses. (dont worry the factory will get a special role in the engine to only allow him to add allowed addresses not everyone can do it).

## What Should you do?

Here are a few steps we suggest to take to make sure the integration we created is full and correct:

### Roles and Permissions
Make sure the roles and permissions are set correctly:
* Who is the admin of the protocol?
* Who is the operator of the protocol?

### For each of you'r contracts:
  
#### For immutable contracts (inline protection):
  * Does the contract inherit from `SphereXProtected`?
  * Does the constructor initializes the values approprietly?
  * Are all the function you wish to protect use the required decorators?
  
#### For mutable contracts (proxy protection):
  * Is the proxy is one of the proxies provided by SphereX or the proxy inherit from `SphereXProtectedProxy`
  * Does the constructor initializes the values approprietly?
  * What are the function you wish to ignore
  * Are the functions you wish to protect configured in the `setProtectedSigs` function?

#### In the deployment Scripts
  * Did we caought all the deployments? Is there a contract that is deployed without protection (inline or proxy)?
    * Are we using the correct integration for each contract?
  * Are the constructor arguments correct for all the deployments?