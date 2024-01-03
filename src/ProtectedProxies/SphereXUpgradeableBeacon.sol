// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXProxyBase} from "../SphereXProxyBase.sol";
import {UpgradeableBeacon} from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import {ISphereXBeacon} from "./ISphereXBeacon.sol";

contract SphereXUpgradeableBeacon is SphereXProxyBase, UpgradeableBeacon, ISphereXBeacon {
    constructor(address implementation, address admin, address operator, address engine)
        SphereXProxyBase(admin, operator, engine)
        UpgradeableBeacon(implementation)
    {}

    function upgradeTo(address newImplementation) public virtual override onlySphereXAdmin {
        super.upgradeTo(newImplementation);
    }

    function protectedImplementation(bytes4 func_sig) external view returns (address, address, bool) {
        return (implementation(), sphereXEngine(), isProtectedFuncSig(func_sig));
    }
}
