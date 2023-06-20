// SPDX-License-Identifier: Unlicensed
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.17;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ISphereXEngine} from "./ISphereXEngine.sol";
import {ISphereXProtected} from "./ISphereXProtected.sol";


/**
 * @title Management contract used for atomic engine update.
 * It is expected for this contract to be the operator of all the protected contracts, otherwise it will revert.
 */
contract SphereXEngineUpdater is Ownable {

    function update(address[] calldata protectedContracts, address newSphereXEngine) external onlyOwner {
        for (uint256 i = 0; i < protectedContracts.length; ++i) {
            ISphereXProtected(protectedContracts[i]).changeSphereXEngine(newSphereXEngine);
        }
    }
}
