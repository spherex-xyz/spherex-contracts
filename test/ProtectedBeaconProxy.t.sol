// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";

import "../src/SphereXEngine.sol";
import "./Utils/CostumerContract.sol";

import {ProtectedBeaconProxy} from "spherex-protect-contracts/ProtectedProxies/ProtectedBeaconProxy.sol";
import {UpgradeableBeacon} from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

contract ProtectedBeaconProxyTest is Test, CFUtils {
    ProtectedBeaconProxy public proxy_contract;
    CustomerBehindProxy public costumer_contract;
    UpgradeableBeacon public beacon;
    bytes4[] protected_sigs;

    function setUp() public virtual {
        spherex_engine = new SphereXEngine();
        costumer_contract = new CustomerBehindProxy();
        beacon = new UpgradeableBeacon(address(costumer_contract));
        proxy_contract = new ProtectedBeaconProxy(address(beacon), bytes(""));

        proxy_contract.changeSphereXOperator(address(this));

        int256 try_allowed_flow_hash = int256(uint256(uint32(CustomerBehindProxy.try_allowed_flow.selector)));
        int256[2] memory allowed_cf = [try_allowed_flow_hash, -try_allowed_flow_hash];

        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }
        allowed_patterns.push(allowed_cf_hash);
        allowed_senders.push(address(proxy_contract));
        spherex_engine.addAllowedSender(allowed_senders);
        spherex_engine.addAllowedPatterns(allowed_patterns);
        spherex_engine.configureRules(CF);

        protected_sigs.push(CustomerBehindProxy.try_allowed_flow.selector);
        protected_sigs.push(CustomerBehindProxy.try_blocked_flow.selector);
        proxy_contract.addProtectedFuncSigs(protected_sigs);
        proxy_contract.changeSphereXEngine(address(spherex_engine));
    }

    function testAllowed() external {
        CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
        assertFlowStorageSlotsInInitialState();
    }

    function testTwoAllowedCall() external {
        CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
        CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function testBlocked() external {
        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function testUpdate() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
        beacon.upgradeTo(address(new_costumer));

        protected_sigs.push(CustomerBehindProxy1.new_func.selector);
        proxy_contract.addProtectedFuncSigs(protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy1(address(proxy_contract)).new_func();

        int256 new_funcflow_hash = int256(uint256(uint32(CustomerBehindProxy1.new_func.selector)));
        int256[2] memory allowed_cf = [new_funcflow_hash, -new_funcflow_hash];

        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }

        allowed_patterns.push(allowed_cf_hash);
        spherex_engine.addAllowedPatterns(allowed_patterns);

        vm.expectCall(address(proxy_contract), abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector));
        CustomerBehindProxy1(address(proxy_contract)).new_func();
    }
}
