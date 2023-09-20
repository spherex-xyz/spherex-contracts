// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";

import "../src/SphereXEngine.sol";
import "./Utils/CostumerContract.sol";
import "spherex-protect-contracts/ProtectedProxies/ProtectedERC1967Proxy.sol";
import "spherex-protect-contracts/SphereXProtected.sol";

contract ProtectedERC1967ProxyTest is Test, CFUtils {
    ProtectedERC1967Proxy public proxy_contract;
    CostomerBehindProxy public costumer_contract;
    bytes4[] protected_sigs;

    function setUp() public virtual {
        spherex_engine = new SphereXEngine();
        costumer_contract = new CostomerBehindProxy();
        proxy_contract = new ProtectedERC1967Proxy(
            address(costumer_contract),
            ""
        );

        proxy_contract.changeSphereXOperator(address(this));

        int256 try_allowed_flow_hash = int256(uint256(uint128(bytes16(CostomerBehindProxy.try_allowed_flow.selector))));
        int256[2] memory allowed_cf = [try_allowed_flow_hash, -try_allowed_flow_hash];

        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }
        allowed_patterns.push(allowed_cf_hash);
        allowed_senders.push(address(this));
        allowed_senders.push(address(proxy_contract));
        spherex_engine.addAllowedSender(allowed_senders);
        spherex_engine.addAllowedPatterns(allowed_patterns);
        spherex_engine.configureRules(CF);

        protected_sigs.push(CostomerBehindProxy.try_allowed_flow.selector);
        protected_sigs.push(CostomerBehindProxy.try_blocked_flow.selector);
        proxy_contract.setProtectedSigs(protected_sigs);
        proxy_contract.changeSphereXEngine(address(spherex_engine));
    }

    function testAllowed() external {
        CostomerBehindProxy(address(proxy_contract)).try_allowed_flow();
        assertFlowStorageSlotsInInitialState();
    }

    function testTwoAllowedCall() external {
        CostomerBehindProxy(address(proxy_contract)).try_allowed_flow();
        CostomerBehindProxy(address(proxy_contract)).try_allowed_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function testBlocked() external {
        vm.expectRevert("SphereX error: disallowed tx pattern");
        CostomerBehindProxy(address(proxy_contract)).try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }
}
