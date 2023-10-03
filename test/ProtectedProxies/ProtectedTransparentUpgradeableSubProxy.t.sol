// // SPDX-License-Identifier: UNLICENSED
// // (c) SphereX 2023 Terms&Conditions

// pragma solidity >=0.6.2;

// import "forge-std/Test.sol";
// import "./Utils/CFUtils.sol";

// import "../src/SphereXEngine.sol";
// import "./Utils/CostumerContract.sol";
// import {
//     ProtectedTransparentUpgradeableSubProxy,
//     SphereXProtectedSubProxy,
//     ISphereXProtectedSubProxy
// } from "spherex-protect-contracts/ProtectedProxies/ProtectedTransparentUpgradeableSubProxy.sol";
// import "spherex-protect-contracts/SphereXProtected.sol";

// import {
//     TransparentUpgradeableProxy,
//     ITransparentUpgradeableProxy
// } from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

// contract ProtectedTransparentUpgradeableSubProxyTest is Test, CFUtils {
//     TransparentUpgradeableProxy public proxy_contract;
//     address proxy_admin = vm.addr(12345);
//     address spherex_admin = vm.addr(19345098);

//     ProtectedTransparentUpgradeableSubProxy public protected_proxy_contract;
//     CustomerBehindProxy public customer_contract;
//     bytes4[] protected_sigs;

//     function setUp() public virtual {
//         spherex_engine = new SphereXEngine();
//         customer_contract = new CustomerBehindProxy();
//         protected_proxy_contract =
//             new ProtectedTransparentUpgradeableSubProxy(address(customer_contract), spherex_admin, bytes(""));

//         bytes memory initialize_data = abi.encodeWithSelector(
//             SphereXProtectedSubProxy.__SphereXProtectedSubProXy_init.selector,
//             spherex_admin,
//             address(this),
//             address(0),
//             address(customer_contract)
//         );
//         proxy_contract = new TransparentUpgradeableProxy(
//             address(protected_proxy_contract),
//             address(proxy_admin),
//             initialize_data
//         );

//         int256 try_allowed_flow_hash = int256(uint256(uint32(CustomerBehindProxy.try_allowed_flow.selector)));
//         int256[2] memory allowed_cf = [try_allowed_flow_hash, -try_allowed_flow_hash];

//         uint216 allowed_cf_hash = 1;
//         for (uint256 i = 0; i < allowed_cf.length; i++) {
//             allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
//         }
//         allowed_patterns.push(allowed_cf_hash);
//         allowed_senders.push(address(proxy_contract));
//         spherex_engine.addAllowedSender(allowed_senders);
//         spherex_engine.addAllowedPatterns(allowed_patterns);
//         spherex_engine.configureRules(CF);

//         protected_sigs.push(CustomerBehindProxy.try_allowed_flow.selector);
//         protected_sigs.push(CustomerBehindProxy.try_blocked_flow.selector);
//         ProtectedTransparentUpgradeableSubProxy(payable(proxy_contract)).addProtectedFuncSigs(protected_sigs);
//         ProtectedTransparentUpgradeableSubProxy(payable(proxy_contract)).changeSphereXEngine(address(spherex_engine));
//     }

//     function testAllowed() external {
//         CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
//         assertFlowStorageSlotsInInitialState();
//     }

//     function testTwoAllowedCall() external {
//         CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
//         CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();

//         assertFlowStorageSlotsInInitialState();
//     }

//     function testBlocked() external {
//         vm.expectRevert("SphereX error: disallowed tx pattern");
//         CustomerBehindProxy(address(proxy_contract)).try_blocked_flow();

//         assertFlowStorageSlotsInInitialState();
//     }

//     function testReInitialize() external {
//         vm.expectRevert("SphereXInitializable: contract is already initialized");
//         vm.prank(spherex_admin);
//         SphereXProtectedSubProxy(payable(proxy_contract)).__SphereXProtectedSubProXy_init(
//             address(this), address(0), address(0), address(0)
//         );
//     }

//     function testTransparentAdminBehavior() external {
//         vm.expectRevert("TransparentUpgradeableProxy: admin cannot fallback to proxy target");
//         vm.prank(proxy_admin);
//         CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
//     }

//     function testProtectedTransparentAdminBehavior() external {
//         vm.expectRevert("ProtectedTransparentUpgradeableSubProxy: admin cannot fallback to sub-proxy target");
//         vm.prank(spherex_admin);
//         CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
//     }

//     function testSubUpdate() external {
//         CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
//         vm.prank(spherex_admin);
//         ISphereXProtectedSubProxy(address(proxy_contract)).subUpgradeTo(address(new_costumer));

//         vm.expectCall(address(proxy_contract), abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector));
//         CustomerBehindProxy1(address(proxy_contract)).new_func();
//     }

//     function testSubUpdateAndCall() external {
//         CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
//         bytes memory new_func_data = abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector);

//         vm.prank(spherex_admin);
//         vm.expectCall(address(new_costumer), new_func_data);
//         ISphereXProtectedSubProxy(address(proxy_contract)).subUpgradeToAndCall(address(new_costumer), new_func_data);
//     }

//     function testUpdateTo() external {
//         CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
//         vm.prank(proxy_admin);
//         ITransparentUpgradeableProxy(address(proxy_contract)).upgradeTo(address(new_costumer));

//         vm.expectCall(address(proxy_contract), abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()")))));
//         UUPSCustomer1(address(proxy_contract)).new_func();
//     }

//     function testUpdateToAndCall() external {
//         CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
//         vm.prank(proxy_admin);
//         bytes memory new_func_data = abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()"))));

//         vm.expectCall(address(new_costumer), new_func_data);
//         ITransparentUpgradeableProxy(address(proxy_contract)).upgradeToAndCall(address(new_costumer), new_func_data);
//     }
// }
