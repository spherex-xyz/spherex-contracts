// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "./Proxy.sol";
import "../../src/SphereXProtected.sol";
import "../../src/SphereXProtectedBase.sol";

contract CostumerContractProxy is Proxy {
    bytes32 space; // only so the x variable wont be overriden by the _imp variable
    address private _imp;

    constructor(address implementation) {
        _imp = implementation;
    }

    function _implementation() internal view override returns (address) {
        return _imp;
    }
}

contract SomeContract is SphereXProtectedBase {
    constructor(address admin, address operator, address engine) SphereXProtectedBase(admin, operator, engine) {}

    function someFunc() external sphereXGuardExternal(100){}
}

contract CostumerContract is SphereXProtected {
    uint256 public slot0 = 5;

    SomeContract internal someContract;

    constructor() SphereXProtected() {}

    function initialize(address owner) public {
        slot0 = 5;
        __SphereXProtected_init(owner, msg.sender, address(0));
    }

    function try_allowed_flow() external sphereXGuardExternal(1) {}

    function try_blocked_flow() external sphereXGuardExternal(2) {}

    function call_inner() external sphereXGuardExternal(3) {
        inner();
    }

    function inner() private sphereXGuardInternal(4) {
        try CostumerContract(address(this)).reverts() {} catch {}
    }

    function reverts() external sphereXGuardExternal(5) {
        require(1 == 2, "revert!");
    }

    function publicFunction() public sphereXGuardPublic(6, this.publicFunction.selector) returns (bool) {
        return true;
    }

    function publicCallsPublic() public sphereXGuardPublic(7, this.publicCallsPublic.selector) returns (bool) {
        return publicFunction();
    }

    function publicCallsSamePublic(bool callInternal)
        public
        sphereXGuardPublic(8, this.publicCallsSamePublic.selector)
        returns (bool)
    {
        if (callInternal) {
            return publicCallsSamePublic(false);
        } else {
            return true;
        }
    }

    function changex() public sphereXGuardPublic(9, this.changex.selector) {
        slot0 = 6;
    }

    function arbitraryCall(address to, bytes calldata data) external sphereXGuardExternal(10) {
        (bool success, bytes memory result) = to.call(data);
        require(success, "arbitrary call reverted");
    }

    function externalCallsExternal() external sphereXGuardExternal(11) returns (bool) {
        return this.externalCallee();
    }

    function externalCallee() external sphereXGuardExternal(12) returns (bool) {
        return true;
    }

    function factory() external sphereXGuardExternal(13) returns(address) {
        someContract = new SomeContract(sphereXAdmin(), sphereXOperator(), sphereXEngine()); 
        _addAllowedSenderOnChain(address(someContract));
        return address(someContract);
    }
}
