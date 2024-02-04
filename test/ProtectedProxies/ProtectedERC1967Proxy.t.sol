// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";

import {CustomerBehindProxy, UUPSCustomer, UUPSCustomer1} from "../Utils/CostumerContract.sol";
import {ProtectedERC1967Proxy} from "../../src/ProtectedProxies/ProtectedERC1967Proxy.sol";
import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

contract ProtectedERC1967ProxyTest is SphereXProtectedProxyTest {
    function setUp() public virtual override {
        p_costumer_contract = new UUPSCustomer();
        proxy_contract = new ProtectedERC1967Proxy(address(p_costumer_contract), "");

        super.setUp();
    }

    function testUpdateTo() external {
        UUPSCustomer1 new_costumer = new UUPSCustomer1();
        UUPSUpgradeable(address(proxy_contract)).upgradeTo(address(new_costumer));

        vm.expectCall(address(new_costumer), abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()")))));
        UUPSCustomer1(address(proxy_contract)).new_func();
    }

    function testUpdateToAndCall() external {
        UUPSCustomer1 new_costumer = new UUPSCustomer1();
        bytes memory new_func_data = abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()"))));

        vm.expectCall(address(new_costumer), new_func_data);
        UUPSCustomer1(address(proxy_contract)).upgradeToAndCall(address(new_costumer), new_func_data);
    }
}
