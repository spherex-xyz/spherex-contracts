// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXProxyBase} from "../SphereXProxyStorage.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract SphereXUpgradeableBeacon is SphereXProxyBase, UpgradeableBeacon {
    constructor(address implementation)
        SphereXProxyBase(msg.sender, address(0), address(0))
        UpgradeableBeacon(implementation)
    {}

    function upgradeTo(address newImplementation) public virtual override onlySphereXAdmin {
        super.upgradeTo(newImplementation);
    }
}
