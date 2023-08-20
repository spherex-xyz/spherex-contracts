// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "../src/SphereXEngine.sol";
import "spherex-protect-contracts/SphereXProtected.sol";
import "./SphereXProtected.t.sol";

contract SphereXProtectedProxyTest is Test, SphereXProtectedTest {
    CostumerContractProxy public costumer_proxy_contract;
    CostumerContract public p_costumerContract;

    function setUp() public override {
        spherex_engine = new SphereXEngine();
        costumer_contract = new CostumerContract();
        costumer_contract.changeSphereXOperator(address(this));

        costumer_proxy_contract = new CostumerContractProxy(address(costumer_contract));

        int16[2] memory allowed_cf = [int16(1), -1];
        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }
        allowed_patterns.push(allowed_cf_hash);
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
