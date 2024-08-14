// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "../Utils/CFUtils.sol";
import "../Utils/MockEngine.sol";
import "../Utils/CostumerContract.sol";
import "../../src/ProtectedProxies/MinimalProtectedProxyFactory.sol";
import "../../src/ProtectedProxies/ProtectedMinimalProxy.sol";

contract SphereXProtectedTest is Test {
    bytes8 constant CF_RULE = bytes8(uint64(1));

    CustomerBehindProxy public costumer_contract;
    SphereXEngine public spherex_engine;
    MinimalProtectedProxyFactory public factory;
    address random_address = 0x6A08098568eE90b71dD757F070D79364197f944B;
    bytes4[] public allowed_sigs = [costumer_contract.try_allowed_flow.selector];
    int256 internal constant ADD_ALLOWED_SENDER_ONCHAIN_INDEX = int256(uint256(keccak256("factory.allowed.sender")));

    function setUp() public {
        spherex_engine = new SphereXEngine();
        costumer_contract = new CustomerBehindProxy();
        factory = new MinimalProtectedProxyFactory(address(costumer_contract), allowed_sigs);
        factory.changeSphereXOperator(address(this));
        factory.changeSphereXEngine(address(spherex_engine));
        factory.initializeAllowedDeployer(address(this));
        spherex_engine.grantSenderAdderRole(address(factory));
    }

    function test_deploy_check_operator() public {
        address minimal_proxy = factory.deploy();
        assertEq(ProtetedMinimalProxy(payable(minimal_proxy)).sphereXOperator(), address(this));
    }

    // this test also check that the minimal proxy is an allowed sender because
    // if it wasnt we would get disallowed sender revert
    function test_deploy_check_protected_sigs() public {
        address minimal_proxy = factory.deploy();
        spherex_engine.configureRules(CF_RULE);
        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(minimal_proxy).try_allowed_flow();
    }

    function test_deploy_check_not_protected_sigs() public {
        address minimal_proxy = factory.deploy();
        spherex_engine.configureRules(CF_RULE);
        CustomerBehindProxy(minimal_proxy).publicFunction();
    }

    function test_accept_proxy_admin() public {
        address minimal_proxy = factory.deploy();
        ProtetedMinimalProxy(payable(minimal_proxy)).acceptSphereXAdminRole();
        ProtetedMinimalProxy(payable(minimal_proxy)).changeSphereXOperator(random_address);
    }
}
