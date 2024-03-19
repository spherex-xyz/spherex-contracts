The Process of adding Spherex Protection into the smart contracts is usually done (at least at this point) by the tech team at Spherex.

That being said, and because the developer of the smart contracts will always know it better than we do, it is important for you as the developer of the protected contract to understand the process of integration and the various aspects of that process.

- [Protection  - the big picture](#protection----the-big-picture)
- [Some terms and definitions](#some-terms-and-definitions)
    - [Contracts in the system](#contracts-in-the-system)
    - [Entities and addresses](#entities-and-addresses)
- [Integration](#integration)
  - [Inline vs Proxy](#inline-vs-proxy)
  - [Configuration](#configuration)
  - [Deployment](#deployment)
    - [Special cases](#special-cases)
- [What Should you do?](#what-should-you-do)
  - [Roles and Permissions](#roles-and-permissions)
  - [For each of you'r contracts:](#for-each-of-your-contracts)
    - [For immutable contracts (inline protection):](#for-immutable-contracts-inline-protection)
    - [For mutable contracts (proxy protection):](#for-mutable-contracts-proxy-protection)
    - [In the deployment Scripts](#in-the-deployment-scripts)


## Protection  - the big picture
- Spherex protection works by identifying suspicious and malicious behavior patterns of a transaction as it is being executed by the protocol (between any number of contracts)
- The granularity of the protection is **functions** - meaning the smallest unit of code we track behavior of is a function.
  - The data collected and used for each function in each protocol may change, depending on various factors (gas cost in the chain, past history, client requests, etc.)
- `pure` and `view` functions are not protected, as they do not change the state of the contract , and therefore do not require protection.

## Some terms and definitions

#### Contracts in the system

- **Protected Contracts**: The smarts contract that are being protected by Spherex.
- **Spherex Engine**: This is a smart contract written by spherex that acts as manager of the protection: It stores the and allows to configure the various rules applied to the protocol. It is **Provided by spherex** and deployed as part of the protocol
  - The protected contracts in the protocol communicates with the Spherex Engine to track the behavior of a transaction as it's being executed and revert it if it's malicious.

#### Entities and addresses

- **Operator**: The address (whether EOA or a contract) that configures and updates the protection of the contract. This can be either the protocol developer/manager, the SphereX tech team, or any other wallet that has the permission to do so.
- **Admin**: The address (whether EOA or a contract) that controls the operator. This should be the protocol owner , and it's meant to make sure that said protocol owner always has control and final word over the protocol.
- **Allowed Senders** - One of our protection mechanisms is to only allow pre approved addresses to send data to the engine. So this is just a list of all the contracts that are allowed to send data to the engine.
  - This becomes important if you deploy contracts dynamically (for example, using the factory pattern).

This is a good place to emphasize and reiterate: the **Operator** and the **Admin** can be a wallet address (EOA) but cal also be a smart contract (like a DAO contract or a multisig)

This also means that if indeed we use a smart contract as the operator or the admin, we will need to set the various roles accordingly, and also implement in that *management contract* the various management functions needed:
- An Admin should be able to set the operator
- An Operator has many many functionalities (like setting the engine, adding and removing allowed senders and patterns, and even configuring the active rules) - Please talk to the SphereX team to help you understand the various roles and permissions.

If the protocol has some kind of a registry or management contract, it might be a good candidate for the operator/admin roles.

## Integration

### Inline vs Proxy

The SphereX protection has 2 ways to integrate with a given smart contract:
1. **Inline**: The protection logic is integrated directly into the smart contract as function *decorators*, by inheriting from the contract `SphereXProtected`. This is used for immutable contracts.
1. **Proxy**: The protection logic is integrated into a proxy contract that wraps the protected contract. It is the proxy that communicates with the engine before and after passing the calls to the implementation contract. The integration is done by replacing the existing proxy with one of the SphereX proxies (there are many variation of the *protected proxy*) or inheriting directly from `SphereXProtectedProxy`. This is used for mutable\upgradable contracts.
   - Proxy protection also allows to **configure what functions are protected after deployments**. So you can decide for a given function that it does not require protection, and configure the engine and proxy to ignore it.

It is entirely possible (and quite common) to find both types of protection for contracts in a given protocol, as some of the underlying contracts are immutable and some are upgradeable.

### Configuration

All protected contracts (inline or proxy) have these configuration functions:
- `setAdmin` - the admin for the protected logic, can only replace the operator
- `setOperator` - the operator is the entity managing the protected contract
- `setEngine` - set the address of the engine → where the contract will send data about the behavior of the contract

In addition, a protected proxy also has this configuration function:
- `setProtectedSigs` - the functions we wish to protect and send data about their execution to the engine.
  - This is the mechanism with which we configure what functions to protect or ignore in the protection process.
  - **DO NOT** set view or pure function it will cause the engine to revert.

### Deployment

The constructor of our contracts expects three arguments: the **admin**, the **operator** and the **engine**. usually we will set them as follows:

- Admin - `msg.sender` (if we see the integrated contract receives owner as an argument we will use it as the admin)
- Operator - `address(0)`
- Engine - `address(0)`

#### Special cases

- If you are using a **contract to deploy your contract** you probably should change the admin to be `tx.origin` rather then msg.sender
- If u have a **factory pattern** in your project this required some more consideration:
    1. the factory should hold the admin, operator and the engine in his storage (or he should be able to retrieve them somehow) since when it deploys a new contract it should be able to pass them to the deployed contract.
    2. when the factory deploys a new contract it should call the function `_addAllowedSenderOnChain` in the engine to add the address of the new deployed contract.
        1. one of our protection mechanisms is to only allow pre approved addresses to send data to the engine, so the factory should add the new address to the engine allowed list of addresses. (don't worry the factory will get a special role in the engine to only allow him to add allowed addresses not everyone can do it).

## What Should you do?

Here are a few steps we suggest to assure the integration is complete and correct:

### Roles and Permissions
Make sure the roles and permissions are set correctly:
* Who is the admin of the protocol?
* Who is the operator of the protocol?

### For each of you'r contracts:
  
#### For immutable contracts (inline protection):
  * Does the contract inherit from `SphereXProtected`?
  * Does the constructor initializes the values appropriately?
  * Are all the function you wish to protect use the required decorators?
  
#### For mutable contracts (proxy protection):
  * Is the proxy is one of the proxies provided by SphereX or the proxy inherit from `SphereXProtectedProxy`
  * Does the constructor initializes the values appropriately?
  * What are the function you wish to ignore
  * Are the functions you wish to protect configured in the `setProtectedSigs` function?

#### In the deployment Scripts
  * Did we caught all the deployments? Is there a contract that is deployed without protection (inline or proxy)?
    * Are we using the correct integration for each contract?
  * Are the constructor arguments correct for all the deployments?