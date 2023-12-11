// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "../src/SphereXEngine.sol";
import "../src/SphereXProtected.sol";
import "./SphereXProtected.t.sol";

contract SphereXProtectedProxyTest is Test, SphereXProtectedTest {
    CustomerContractProxy public costumer_proxy_contract;
    CostumerContract public p_costumerContract;

    function setUp() public override {
        spherex_engine = new SphereXEngine();
        costumer_contract = new CostumerContract();
        costumer_contract.changeSphereXOperator(address(this));

        costumer_proxy_contract = new CustomerContractProxy(address(costumer_contract));

        allowed_patterns.push(calc_pattern_by_selector(CostumerContract.try_allowed_flow.selector));

        allowed_senders.push(address(costumer_proxy_contract));
        spherex_engine.addAllowedSender(allowed_senders);
        spherex_engine.addAllowedPatterns(allowed_patterns);
        spherex_engine.configureRules(CF);
        p_costumerContract = CostumerContract(address(costumer_proxy_contract));
        p_costumerContract.initialize(address(this));
        p_costumerContract.changeSphereXEngine(address(spherex_engine));

        costumer_contract = p_costumerContract;
    }
}
