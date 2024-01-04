// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";

import {CustomerBehindProxy, UUPSCustomer, UUPSCustomer1} from "../Utils/CostumerContract.sol";
import {ProtectedERC1967ProxyUpgradeable} from "../../src/ProtectedProxies/ProtectedERC1967ProxyUpgradeable.sol";
import {SphereXProtectedProxy} from "../../src/SphereXProtectedProxy.sol";
import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

contract ProtectedERC1967ProxyUpgradeableTest is SphereXProtectedProxyTest {
    function setUp() public virtual override {
        p_costumer_contract = new UUPSCustomer();

        bytes memory code = type(ProtectedERC1967ProxyUpgradeable).creationCode;
        address payable proxy_addr = create2_deploy(_get_salt(123), code);
        ProtectedERC1967ProxyUpgradeable(payable(proxy_addr)).initialize(address(p_costumer_contract), "");

        proxy_contract = SphereXProtectedProxy(proxy_addr);

        address otherAddress = address(1);

        vm.prank(tx.origin);
        proxy_contract.transferSphereXAdminRole(address(this));
        proxy_contract.acceptSphereXAdminRole();

        super.setUp();
    }

    function create2_deploy(bytes32 salt, bytes memory bytecode) public returns (address payable) {
        address payable newContract;
        assembly {
            newContract := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(newContract != address(0), "Failed to deploy the contract");
        return newContract;
    }

    function _get_salt(uint256 _salt) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(_salt, msg.sender));
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
