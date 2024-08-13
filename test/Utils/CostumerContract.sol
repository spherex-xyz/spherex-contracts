// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {Proxy} from "openzeppelin/proxy/Proxy.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

import "../../src/SphereXProtected.sol";
import "../../src/SphereXProtectedBase.sol";

import {ProtectedUUPSUpgradeable} from "../../src/ProtectedProxies/ProtectedUUPSUpgradeable.sol";

contract CustomerContractProxy is Proxy {
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

    function someFunc() external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) {}
}

contract SomeContractBehindProxy {
    constructor() {}

    function someFunc() external {}
}

contract CustomerBehindProxy {
    uint256 public slot0 = 5;
    address private _owner;

    SomeContractBehindProxy internal someContract;

    function initialize(address owner) public {
        slot0 = 5;
        _owner = owner;
    }

    function getOwner() external view returns (address) {
        return _owner;
    }

    function try_allowed_flow() external {}

    function try_blocked_flow() external {}

    function call_inner() external {
        inner();
    }

    function inner() private {
        try CostumerContract(address(this)).reverts() {} catch {}
    }

    function reverts() external {
        require(1 == 2, "revert!");
    }

    function publicFunction() public returns (bool) {
        return true;
    }

    function publicCallsPublic() public returns (bool) {
        return publicFunction();
    }

    function publicCallsSamePublic(bool callInternal) public returns (bool) {
        if (callInternal) {
            return publicCallsSamePublic(false);
        } else {
            return true;
        }
    }

    function changex() public {
        slot0 = 6;
    }

    function arbitraryCall(address to, bytes calldata data) external {
        (bool success, bytes memory result) = to.call(data);
        require(success, "arbitrary call reverted");
    }

    function externalCallsExternal() external returns (bool) {
        return this.externalCallee();
    }

    function externalCallee() external returns (bool) {
        return true;
    }

    function factory() external returns (address) {
        someContract = new SomeContractBehindProxy();
        return address(someContract);
    }

    function static_method() external pure returns (uint256) {
        return 5;
    }

    function setEngine(address newEngine) external {
        SphereXProtected(address(this)).changeSphereXEngine(newEngine);
    }

    function to_block_2() external {}
    function to_block_3() external {}
}

contract CustomerBehindProxy1 {
    function new_func() external {}
}

contract UUPSCustomerUnderProtectedERC1967SubProxy is ProtectedUUPSUpgradeable, CustomerBehindProxy {
    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}

contract UUPSCustomerUnderProtectedERC1967SubProxy1 is ProtectedUUPSUpgradeable, CustomerBehindProxy1 {
    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}

contract UUPSCustomer is UUPSUpgradeable, CustomerBehindProxy {
    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}

contract UUPSCustomer1 is UUPSUpgradeable, CustomerBehindProxy1 {
    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}

contract CostumerContract is SphereXProtected {
    uint256 public slot0 = 5;

    SomeContract internal someContract;

    constructor() SphereXProtected() {}

    function initialize(address owner) public {
        slot0 = 5;
        __SphereXProtectedBase_init(owner, msg.sender, address(0));
    }

    function try_allowed_flow() external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) {}

    function try_blocked_flow() external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) {}

    function call_inner() external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) {
        inner();
    }

    function inner() private sphereXGuardInternal(int256(uint256(uint32(bytes4(keccak256(bytes("inner()"))))))) {
        try CostumerContract(address(this)).reverts() {} catch {}
    }

    function reverts() external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) {
        require(1 == 2, "revert!");
    }

    function publicFunction()
        public
        sphereXGuardPublic(int256(uint256(uint32(this.publicFunction.selector))), this.publicFunction.selector)
        returns (bool)
    {
        return true;
    }

    function publicCallsPublic()
        public
        sphereXGuardPublic(int256(uint256(uint32(this.publicCallsPublic.selector))), this.publicCallsPublic.selector)
        returns (bool)
    {
        return publicFunction();
    }

    function publicCallsSamePublic(bool callInternal)
        public
        sphereXGuardPublic(
            int256(uint256(uint32(this.publicCallsSamePublic.selector))),
            this.publicCallsSamePublic.selector
        )
        returns (bool)
    {
        if (callInternal) {
            return publicCallsSamePublic(false);
        } else {
            return true;
        }
    }

    function changex()
        public
        sphereXGuardPublic(int256(uint256(uint32(this.changex.selector))), this.changex.selector)
    {
        slot0 = 6;
    }

    function arbitraryCall(address to, bytes calldata data)
        external
        sphereXGuardExternal(int256(uint256(uint32(msg.sig))))
    {
        (bool success, bytes memory result) = to.call(data);
        require(success, "arbitrary call reverted");
    }

    function externalCallsExternal() external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) returns (bool) {
        return this.externalCallee();
    }

    function externalCallee() external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) returns (bool) {
        return true;
    }

    function factory() external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) returns (address) {
        someContract = new SomeContract(sphereXAdmin(), sphereXOperator(), sphereXEngine());
        _addAllowedSenderOnChain(address(someContract));
        return address(someContract);
    }

    function setEngine(address newEngine) external sphereXGuardExternal(int256(uint256(uint32(msg.sig)))) {
        SphereXProtected(address(this)).changeSphereXEngine(newEngine);
    }
}
