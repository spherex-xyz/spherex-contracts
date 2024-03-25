The Process of integrating spherex's platform into the smart contracts is based on an automatic pipeline and can be done either independantly by the customer or by spherex.

That being said, it is important for the developer of the protected contracts to understand the integration process and its various aspects.

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
- Spherex protection is blocking suspicious and malicious behavior patterns of transactions during execution.
- The granularity of the protection is configurable. By default, **functions** is the smallest unit of code we track behavior of is a f.
  - The data collected and used for each function in each protocol may change, depending on various factors (gas cost in the chain, past history, client requests, etc.)
- `pure` and `view` functions are not protected, as they do not change the state of the contract , and therefore do not require protection.

## Terminology and definitions

#### Contracts in the system

- **Target Contracts**: These are the original protocol contracts
- **SphereXProtected**: SphereX protection platform. An abstract contract that is inherited and imported into the target contracts 
- **Protected Contracts**: The protocol's contracts integrated with SphereX Platform.
- **Spherex Engine**: A smart contract **Provided by spherex** and deployed as part of the protocol. This is the heart of the system.
  - The protected contracts in the protocol communicate with the SphereX Engine. The engine tracks the behavior of the transaction as it's being executed and reverts it if it's malicious.


#### Entities and addresses

- **Operator**: The address (EOA / smart contract) that configures and updates the protection of the contract.
- **Admin**: The address (EOA / smart contract) that assigns/denounces the operator role. This is the highest permission level, and its purpose is to make sure that the protocol's governance (whether a centralized entity / multisig contract / DAO) is always in full control over the protocol.
- **Allowed Senders** - A list of all the contracts that are allowed to send data to the engine.
  - This becomes important if you deploy contracts dynamically (for example, using the factory pattern).

If the either to operator and/or the admin roles are set as smart contracts, we need to implement the following management functions:
- The Admin smart contract should include a functionality that sets the operator
- The Operator smart contract should include the following functionalities: A, B, C, ...

If the protocol already has a registry or management contract, it might be a good place to insert the operator/admin logic.

## Integration

### Inline vs Proxy

The SphereX protection has 2 ways to integrate with a given smart contract:
1. **Inline**: The protection logic is integrated directly into the code as function *decorators*, and inheriting from the contract `SphereXProtected`. This is used for either immutable or upgradable contracts. 
2. **Proxy**: The protection logic is integrated into the proxy contract that wraps the protected contract. It is the proxy that communicates with the engine before and after passing the calls to the implementation contract. The integration is done by using SphereX's provided proxies (there are many variation of the *protected proxy*) or inheriting directly from `SphereXProtectedProxy`. This is naturally relevant only for upgradable protocols.
In both integraion modes, onw can **configure what functions are protected after deployments**. So you can decide for a given function that it does not require protection, and configure the engine and proxy to ignore it.

It is entirely possible (and quite common) to find both types of protection for contracts in a given protocol, as some of the underlying contracts are immutable and some are upgradeable (hybrid).

### Configuration

All protected contracts (inline or proxy) have these configuration functions:
- `setAdmin` - the admin for the protected logic, can only replace the operator
- `setOperator` - the operator is the entity managing the protected contracts
- `setEngine` - set the address of the protection engine

In addition, a protected proxy also has this configuration function:
- `setProtectedSigs` - A list of function selectors to protect.
  - This is the mechanism with which we configure what functions to protect or ignore in the protection process.
  - **DO NOT** set the protection on for view or pure function it will cause the engine to revert.

### Deployment

The constructor of our contracts expects three arguments: the **admin**, the **operator** and the **engine**. By default, those are set as follows:

- Admin = `msg.sender`
    - This can change if the manager or creator if the contracts is aother smart contract. For instance for a factory pattern, the factory might be the admin of the deployed pool contracts
- Operator = `address(0)`
- Engine = `address(0)`

#### Special cases

- If you are using a **contract to deploy your contract** you probably should change the admin to be `tx.origin` rather then msg.sender
- If u have a **factory pattern** in your project this required some more consideration:
    1. the factory should hold the admin, operator and the engine in his storage (or he should be able to retrieve them somehow) since when it deploys a new contract it should be able to pass them to the deployed contract.
    2. when the factory deploys a new contract it should call the function `_addAllowedSenderOnChain` in the engine to add the address of the new deployed contract.
       One of our protection mechanisms is to only allow pre approved addresses to send data to the engine, so the factory should add the new address to the engine allowed list of addresses. (don't worry the factory will get a special role in the engine to only allow him to add allowed addresses not everyone can do it).

## What Should you do?

Here are a few steps we suggest to assure the integration is complete and correct:

### Roles and Permissions
Make sure the roles and permissions are set correctly:
* Who is the admin of the protocol?
* Who is the operator of the protocol?

### For each of your contracts:
  
#### Immutable contracts (inline protection):
  * Does the contract inherit from `SphereXProtected`?
  * Does the constructor initializes the values appropriately?
  * Are all the function you wish to protect use the required decorators?
  
#### Upgradable contracts (proxy protection):
  * Is the proxy one of the proxies provided by SphereX or inherits from `SphereXProtectedProxy`?
  * Does the constructor initializes the values appropriately?
  * What functions do you wish to ignore?
  * Are the functions you wish to protect configured in the `setProtectedSigs` function?

#### In the deployment Scripts
  * Did we caught all the deployments? Is there a contract that is deployed without protection (inline or proxy)?
    * Are we using the correct integration for each contract?
  * Are the constructor arguments correct for all the deployments?
