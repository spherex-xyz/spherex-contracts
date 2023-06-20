// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "../src/SphereXEngineUpdater.sol";
import "../src/SphereXProtected.sol";
import "./Utils/MockEngine.sol";

contract MockProtectedContract is SphereXProtected {

    function initialize() public {
        __SphereXProtected_init(msg.sender, msg.sender, address(0));
    }
}

contract SphereXEngineUpdaterTest is Test {
    SphereXEngineUpdater updater;
    MockProtectedContract[] public protectedContracts;
    address[] public protectedAddresses;
    address initialEngineAddress;
    bytes32 private constant SPHEREX_MANAGER_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.spherex.spherex")) - 1);
    bytes32 private constant SPHEREX_ENGINE_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.spherex.spherex_engine")) - 1);

    function setUp() public virtual {
        updater = new SphereXEngineUpdater();
        initialEngineAddress = address(new MockEngine());
        for (uint i = 0; i < 5; i++) {
            protectedContracts.push(new MockProtectedContract());
            protectedContracts[i].changeSphereXEngine(initialEngineAddress);
            protectedAddresses.push(address(protectedContracts[i]));
        }
    }

    function checkProtectedsEngine(address addr) internal {
        for (uint i = 0; i < protectedContracts.length; i++) {
            address current_engine = address(uint160(uint256(vm.load(address(protectedContracts[i]), SPHEREX_ENGINE_STORAGE_SLOT))));
            assertEq(current_engine, addr);
        }
    }

    function updateOwnershipToUpdater() internal {
        for (uint i = 0; i < protectedContracts.length; i++) {
            protectedContracts[i].changeSphereXOperator(address(updater));
        }
    }

    function testUpdateFailureWithoutOwnershipTransfer() external {
        checkProtectedsEngine(initialEngineAddress);
        vm.expectRevert("SphereX error: operator required");
        updater.update(protectedAddresses, address(this));
    }

    function testUpdate() external {
        checkProtectedsEngine(initialEngineAddress);
        updateOwnershipToUpdater();

        address newEngine = address(new MockEngine());
        updater.update(protectedAddresses, newEngine);

        checkProtectedsEngine(newEngine);
    }
}