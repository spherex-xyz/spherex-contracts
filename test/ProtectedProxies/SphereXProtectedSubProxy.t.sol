// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";
import {SphereXProtectedSubProxy} from "../../src/SphereXProtectedSubProxy.sol";
import {CustomerBehindProxy} from "../Utils/CostumerContract.sol";

abstract contract SphereXProtectedSubProxyTest is SphereXProtectedProxyTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function testReInitialize() external {
        vm.expectRevert("SphereXInitializable: contract is already initialized");
        SphereXProtectedSubProxy(payable(proxy_contract)).__SphereXProtectedSubProXy_init(
            address(this), address(0), address(0), address(0), new bytes(0)
        );
    }

    function testInitializeImp() external {
        assertEq(CustomerBehindProxy(address(proxy_contract)).getOwner(), address(this));
    }
}
