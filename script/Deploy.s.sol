// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/CarbonCredit.sol";

contract DeployScript is Script {
    function run() external {
        // Foundry will use the private key from --private-key flag
        vm.startBroadcast();
        
        // Deploy CarbonCredit contract
        CarbonCredit carbonCredit = new CarbonCredit();
        
        console.log("CarbonCredit deployed to:", address(carbonCredit));
        
        vm.stopBroadcast();
    }
}