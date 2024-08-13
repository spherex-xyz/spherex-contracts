// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXConfiguration} from "../SphereXConfiguration.sol";
import {ProtetedMinimalProxy} from "./ProtectedMinimalProxy.sol";

/**
 * @title A factory contract that deploys the ProtetedMinimalProxy contracts.
 */
contract MinimalProtectedProxyFactory is SphereXConfiguration {
    address private immutable IMPLEMENTATION;
    bytes4[] private /*immutable*/ PROTECTED_SIGS; // this is in effect immutable.

    address private _allowedDeployer;

    constructor(address implementation, bytes4[] memory protectedSigs)
        SphereXConfiguration(msg.sender, address(0), address(0))
    {
        IMPLEMENTATION = implementation;
        PROTECTED_SIGS = protectedSigs;

        _allowedDeployer = address(0);
    }

    event DeployedMinimalProtectedProxy(address proxy_address, address implementation);

    modifier onlyAllowedDeployer() {
        require(_allowedDeployer != address(0), "Must define Allowed deployer");
        require(msg.sender == _allowedDeployer, "Only Allowed Deployer");
        _;
    }

    function initializeAllowedDeployer(address allowedDeployer) external onlySphereXAdmin {
        require(_allowedDeployer == address(0), "Allowed deployer already exists");
        _allowedDeployer = allowedDeployer;
    }

    /**
     * Deploys a new protected minimal proxy. Sets the inital protected values (admin, operator and engie) to equal those of the factory.
     *  If the current engine is not the null address, also updates the engine about a valid new sender
     * @dev notice the deploy function itself is NOT PROTECTED
     */
    function deploy() public virtual onlyAllowedDeployer returns (address proxyAddress) {
        ProtetedMinimalProxy minimalProxy = new ProtetedMinimalProxy(
            address(this),
            address(this), // for configuring the allowed sigs
            sphereXEngine(),
            IMPLEMENTATION
        );
        proxyAddress = address(minimalProxy);

        _addAllowedSenderOnChain(address(proxyAddress));
        minimalProxy.addProtectedFuncSigs(PROTECTED_SIGS);
        // Now that the sigs are set, we can set the real operator
        minimalProxy.changeSphereXOperator(sphereXOperator());

        // the admin will stay this contract until sphereXAdmin() will
        // accept the role using acceptSphereXAdminRole in the proxy
        minimalProxy.transferSphereXAdminRole(sphereXAdmin());

        emit DeployedMinimalProtectedProxy(proxyAddress, IMPLEMENTATION);
    }
}
