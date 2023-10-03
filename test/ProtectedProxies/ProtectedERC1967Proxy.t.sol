// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";

import {CustomerBehindProxy, UUPSCustomer, UUPSCustomer1} from "../Utils/CostumerContract.sol";
import {ProtectedERC1967Proxy} from "spherex-protect-contracts/ProtectedProxies/ProtectedERC1967Proxy.sol";
import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

contract ProtectedERC1967ProxyTest is SphereXProtectedProxyTest {
    function setUp() public virtual override {
        p_costumer_contract = new UUPSCustomer();
        proxy_contract = new ProtectedERC1967Proxy(
            address(p_costumer_contract),
            ""
        );

        super.setUp();
    }

    function testUpdateTo() external {
        UUPSCustomer1 new_costumer = new UUPSCustomer1();
        UUPSUpgradeable(address(proxy_contract)).upgradeTo(address(new_costumer));

        vm.expectCall(address(proxy_contract), abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()")))));
        UUPSCustomer1(address(proxy_contract)).new_func();
    }
}
