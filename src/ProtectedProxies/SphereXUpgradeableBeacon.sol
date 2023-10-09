// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ISphereXBeacon} from "./ISphereXBeacon.sol";

contract SphereXUpgradeableBeacon is SphereXProtectedProxy, UpgradeableBeacon, ISphereXBeacon {
    constructor(address implementation)
        SphereXProtectedProxy(msg.sender, address(0), address(0))
        UpgradeableBeacon(implementation)
    {}

    function upgradeTo(address newImplementation) public virtual override onlySphereXAdmin {
        super.upgradeTo(newImplementation);
    }

    function _implementation() internal view virtual override returns (address) {
        return super.implementation();
    }

    function protectionInfo(bytes4 func_sig) external view returns (address, address, bool) {
        return (_implementation(), sphereXEngine(), isProtectedFuncSig(func_sig));
    }
}
