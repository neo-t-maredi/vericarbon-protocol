// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/ProjectRegistry.sol";

contract DeployProjectRegistry is Script {
    function run() external {
        vm.startBroadcast();
        
        ProjectRegistry registry = new ProjectRegistry();
        
        console.log("ProjectRegistry deployed to:", address(registry));
        
        vm.stopBroadcast();
    }
}
