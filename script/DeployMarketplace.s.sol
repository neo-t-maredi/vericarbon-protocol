// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/Marketplace.sol";

contract DeployMarketplace is Script {
    function run() external {
        address carbonCreditAddress = 0x37A3A1B31bBaee86e8E307240BFB4d1e7f227a57;
        address feeRecipient = msg.sender; // Deployer receives fees initially
        
        vm.startBroadcast();
        
        Marketplace marketplace = new Marketplace(carbonCreditAddress, feeRecipient);
        
        console.log("Marketplace deployed to:", address(marketplace));
        console.log("CarbonCredit:", carbonCreditAddress);
        console.log("Fee Recipient:", feeRecipient);
        
        vm.stopBroadcast();
    }
}
