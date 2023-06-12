// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.0;

import "./Ownable.sol";
import "./ISphereXEngine.sol";
import "./ISphereXProtected.sol";


/**
 * @title Management contract used for atomic engine update.
 */
contract SphereXEngineUpdater is Ownable {

    function update(address[] calldata protectedContracts, address newSphereXEngine) external onlyOwner {
        for (uint256 i = 0; i < protectedContracts.length; ++i) {
            ISphereXProtected(protectedContracts[i]).changeSphereXEngine(newSphereXEngine);
            ISphereXProtected(protectedContracts[i]).changeSphereXManager(owner());
        }
    }
}