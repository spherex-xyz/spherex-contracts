// // SPDX-License-Identifier: UNLICENSED
// // (c) SphereX 2023 Terms&Conditions

// pragma solidity >=0.6.2;

// import "forge-std/Test.sol";
// import "./Utils/CFUtils.sol";

// import "../src/SphereXEngine.sol";
// import {
//     UUPSCustomerUnderProtectedERC1967SubProxy,
//     UUPSCustomerUnderProtectedERC1967SubProxy1,
//     UUPSCustomer1
// } from "./Utils/CostumerContract.sol";
// import {
//     ProtectedERC1967SubProxy,
//     SphereXProtectedSubProxy
// } from "spherex-protect-contracts/ProtectedProxies/ProtectedERC1967SubProxy.sol";
// import {ProtectedUUPSUpgradeable} from "spherex-protect-contracts/ProtectedProxies/ProtectedUUPSUpgradeable.sol";

// import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
// import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// contract ProtectedERC1967SubProxyTest is Test, CFUtils {
//     ERC1967Proxy public proxy_contract;
//     ProtectedERC1967SubProxy public protected_proxy_contract;
//     UUPSCustomerUnderProtectedERC1967SubProxy public customer_contract;
//     bytes4[] protected_sigs;

//     function setUp() public virtual {
//         spherex_engine = new SphereXEngine();
//         customer_contract = new UUPSCustomerUnderProtectedERC1967SubProxy();
//         protected_proxy_contract = new ProtectedERC1967SubProxy(address(customer_contract), bytes(""));

//         bytes memory initialize_data = abi.encodeWithSelector(
//             SphereXProtectedSubProxy.__SphereXProtectedSubProXy_init.selector,
//             address(this),
//             address(this),
//             address(0),
//             address(customer_contract)
//         );

//         proxy_contract = new ERC1967Proxy(address(protected_proxy_contract), initialize_data);

//         int256 try_allowed_flow_hash = int256(uint256(uint32(bytes4(keccak256(bytes("try_allowed_flow()"))))));
//         int256[2] memory allowed_cf = [try_allowed_flow_hash, -try_allowed_flow_hash];

//         uint216 allowed_cf_hash = 1;
//         for (uint256 i = 0; i < allowed_cf.length; i++) {
//             allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
//         }

//         allowed_patterns.push(allowed_cf_hash);
//         allowed_senders.push(address(this));
//         allowed_senders.push(address(proxy_contract));
//         spherex_engine.addAllowedSender(allowed_senders);
//         spherex_engine.addAllowedPatterns(allowed_patterns);
//         spherex_engine.configureRules(CF);

//         protected_sigs.push(bytes4(keccak256(bytes("try_allowed_flow()"))));
//         protected_sigs.push(bytes4(keccak256(bytes("try_blocked_flow()"))));
//         ProtectedERC1967SubProxy(payable(proxy_contract)).addProtectedFuncSigs(protected_sigs);
//         ProtectedERC1967SubProxy(payable(proxy_contract)).changeSphereXEngine(address(spherex_engine));
//     }

//     function testAllowed() external {
//         UUPSCustomerUnderProtectedERC1967SubProxy(address(proxy_contract)).try_allowed_flow();
//         assertFlowStorageSlotsInInitialState();
//     }

//     function testTwoAllowedCall() external {
//         UUPSCustomerUnderProtectedERC1967SubProxy(address(proxy_contract)).try_allowed_flow();
//         UUPSCustomerUnderProtectedERC1967SubProxy(address(proxy_contract)).try_allowed_flow();

//         assertFlowStorageSlotsInInitialState();
//     }

//     function testBlocked() external {
//         vm.expectRevert("SphereX error: disallowed tx pattern");
//         UUPSCustomerUnderProtectedERC1967SubProxy(address(proxy_contract)).try_blocked_flow();

//         assertFlowStorageSlotsInInitialState();
//     }

//     function testReInitialize() external {
//         vm.expectRevert("SphereXInitializable: contract is already initialized");
//         SphereXProtectedSubProxy(payable(proxy_contract)).__SphereXProtectedSubProXy_init(
//             address(this), address(0), address(0), address(0)
//         );
//     }

//     function testSubUpdate() external {
//         UUPSCustomerUnderProtectedERC1967SubProxy1 new_costumer = new UUPSCustomerUnderProtectedERC1967SubProxy1();
//         ProtectedUUPSUpgradeable(address(proxy_contract)).subUpgradeTo(address(new_costumer));

//         vm.expectCall(address(proxy_contract), abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()")))));
//         UUPSCustomerUnderProtectedERC1967SubProxy1(address(proxy_contract)).new_func();
//     }

//     function testSubUpdateAndCall() external {
//         UUPSCustomerUnderProtectedERC1967SubProxy1 new_costumer = new UUPSCustomerUnderProtectedERC1967SubProxy1();
//         bytes memory new_func_data = abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()"))));

//         vm.expectCall(address(new_costumer), new_func_data);
//         UUPSCustomerUnderProtectedERC1967SubProxy1(address(proxy_contract)).subUpgradeToAndCall(
//             address(new_costumer), new_func_data
//         );
//     }

//     function testUpdateTo() external {
//         UUPSCustomer1 new_costumer = new UUPSCustomer1();
//         ProtectedUUPSUpgradeable(address(proxy_contract)).upgradeTo(address(new_costumer));

//         vm.expectCall(address(proxy_contract), abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()")))));
//         UUPSCustomer1(address(proxy_contract)).new_func();
//     }

//     function testUpdateToAndCall() external {
//         UUPSCustomer1 new_costumer = new UUPSCustomer1();
//         bytes memory new_func_data = abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()"))));

//         vm.expectCall(address(new_costumer), new_func_data);
//         UUPSUpgradeable(address(proxy_contract)).upgradeToAndCall(address(new_costumer), new_func_data);
//     }
// }
