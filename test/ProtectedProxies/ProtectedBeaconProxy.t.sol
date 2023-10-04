// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";

import {CustomerBehindProxy, CustomerBehindProxy1} from "../Utils/CostumerContract.sol";
import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";
import {ProtectedBeaconProxy} from "spherex-protect-contracts/ProtectedProxies/ProtectedBeaconProxy.sol";
import {UpgradeableBeacon} from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

contract ProtectedBeaconProxyTest is SphereXProtectedProxyTest {
    UpgradeableBeacon public beacon;

    function setUp() public virtual override {
        p_costumer_contract = new CustomerBehindProxy();
        beacon = new UpgradeableBeacon(address(p_costumer_contract));
        proxy_contract = new ProtectedBeaconProxy(address(beacon), bytes(""));

        super.setUp();
    }

    function testUpdate() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
        beacon.upgradeTo(address(new_costumer));

        protected_sigs.push(CustomerBehindProxy1.new_func.selector);
        proxy_contract.addProtectedFuncSigs(protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy1(address(proxy_contract)).new_func();

        allowed_patterns.push(calc_pattern_by_selector(CustomerBehindProxy1.new_func.selector));
        spherex_engine.addAllowedPatterns(allowed_patterns);

        vm.expectCall(address(proxy_contract), abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector));
        CustomerBehindProxy1(address(proxy_contract)).new_func();
    }
}
