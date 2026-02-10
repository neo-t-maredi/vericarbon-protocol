// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/CarbonCredit.sol";

contract CarbonCreditTest is Test {
    CarbonCredit public carbonCredit;
    
    address admin = address(1);
    address projectOwner = address(2);
    address verifier = address(3);
    address user = address(4);
    
    // Setup runs before each test
    function setUp() public {
        // Deploy contract as admin
        vm.prank(admin);
        carbonCredit = new CarbonCredit();
        
        // Grant roles
        vm.startPrank(admin);
        carbonCredit.grantRole(carbonCredit.PROJECT_ROLE(), projectOwner);
        carbonCredit.grantRole(carbonCredit.VERIFIER_ROLE(), verifier);
        vm.stopPrank();
    }

    // ============ Deployment Tests ============
    
    function testDeployment() public view {
        // Check that contract was deployed
        assertTrue(address(carbonCredit) != address(0));
    }
    
    function testAdminRoleGrantedOnDeployment() public view {
        // Admin should have DEFAULT_ADMIN_ROLE
        assertTrue(carbonCredit.hasRole(carbonCredit.DEFAULT_ADMIN_ROLE(), admin));
    }
    
    function testRolesGrantedCorrectly() public view {
        // Check PROJECT_ROLE was granted
        assertTrue(carbonCredit.hasRole(carbonCredit.PROJECT_ROLE(), projectOwner));
        
        // Check VERIFIER_ROLE was granted
        assertTrue(carbonCredit.hasRole(carbonCredit.VERIFIER_ROLE(), verifier));
    }
    
    function testRandomUserHasNoRoles() public view {
        // User should NOT have any special roles
        assertFalse(carbonCredit.hasRole(carbonCredit.PROJECT_ROLE(), user));
        assertFalse(carbonCredit.hasRole(carbonCredit.VERIFIER_ROLE(), user));
        assertFalse(carbonCredit.hasRole(carbonCredit.DEFAULT_ADMIN_ROLE(), user));
    }

    // ============ Minting Tests ============
    
    function testProjectOwnerCanMint() public {
        // Project owner mints credits
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Check token ID is 0 (first mint)
        assertEq(tokenId, 0);
        
        // Check project owner received the credits
        assertEq(carbonCredit.balanceOf(projectOwner, tokenId), 1000);
    }
    
    function testMintedCreditsStartUnverified() public {
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Should be unverified initially
        assertFalse(carbonCredit.isVerified(tokenId));
    }
    
    function testMintEmitsEvent() public {
        // Expect the CreditTypeMinted event
        vm.expectEmit(true, true, true, true);
        emit CarbonCredit.CreditTypeMinted(0, "Dorper Wind Farm", "South Africa", "Renewable Energy", 1000);
        
        vm.prank(projectOwner);
        carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
    }
    
    function testRandomUserCannotMint() public {
        // Random user tries to mint - should revert
        vm.prank(user);
        vm.expectRevert();
        carbonCredit.mintCreditType(
            "Fake Project",
            "Nowhere",
            "Scam",
            1000
        );
    }
    
    function testTokenIdIncrementsCorrectly() public {
        vm.startPrank(projectOwner);
        
        uint256 tokenId1 = carbonCredit.mintCreditType("Project 1", "Kenya", "Forestry", 500);
        uint256 tokenId2 = carbonCredit.mintCreditType("Project 2", "Ghana", "Solar", 750);
        uint256 tokenId3 = carbonCredit.mintCreditType("Project 3", "Nigeria", "Wind", 1000);
        
        vm.stopPrank();
        
        // Check IDs increment: 0, 1, 2
        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);
    }

    // ============ Verification Tests ============
    
    function testVerifierCanVerifyCredits() public {
        // First mint credits
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Verifier verifies the credits
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
        
        // Check credits are now verified
        assertTrue(carbonCredit.isVerified(tokenId));
        
        // Check verification timestamp was set
        (,,,, bool isVerified, uint256 timestamp) = carbonCredit.creditTypes(tokenId);
        assertTrue(isVerified);
        assertGt(timestamp, 0); // timestamp should be greater than 0
    }
    
    function testVerificationEmitsEvent() public {
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Expect the CreditVerified event
        vm.expectEmit(true, true, true, true);
        emit CarbonCredit.CreditVerified(tokenId, block.timestamp);
        
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
    }
    
    function testCannotVerifyNonExistentToken() public {
        // Try to verify token that doesn't exist
        vm.prank(verifier);
        vm.expectRevert("Credit type does not exist");
        carbonCredit.verifyCreditType(999);
    }
    
    function testCannotDoubleVerify() public {
        // Mint and verify
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
        
        // Try to verify again - should fail
        vm.prank(verifier);
        vm.expectRevert("Credit type already verified");
        carbonCredit.verifyCreditType(tokenId);
    }
    
    function testProjectOwnerCannotVerifyOwnCredits() public {
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Project owner tries to verify their own credits - should fail
        vm.prank(projectOwner);
        vm.expectRevert();
        carbonCredit.verifyCreditType(tokenId);
    }
    
    function testRandomUserCannotVerify() public {
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Random user tries to verify - should fail
        vm.prank(user);
        vm.expectRevert();
        carbonCredit.verifyCreditType(tokenId);
    }

    // ============ Retirement Tests ============
    
    function testUserCanRetireVerifiedCredits() public {
        // Mint credits
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Verify credits
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
        
        // Transfer some credits to user
        vm.prank(projectOwner);
        carbonCredit.safeTransferFrom(projectOwner, user, tokenId, 100, "");
        
        // User retires credits
        vm.prank(user);
        carbonCredit.retireCredits(tokenId, 50);
        
        // Check balance decreased
        assertEq(carbonCredit.balanceOf(user, tokenId), 50);
    }
    
    function testRetirementEmitsEvent() public {
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
        
        // Expect the CreditRetired event
        vm.expectEmit(true, true, true, true);
        emit CarbonCredit.CreditRetired(tokenId, projectOwner, 100);
        
        vm.prank(projectOwner);
        carbonCredit.retireCredits(tokenId, 100);
    }
    
    function testCannotRetireUnverifiedCredits() public {
        // Mint but DON'T verify
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Try to retire unverified credits - should fail
        vm.prank(projectOwner);
        vm.expectRevert("Cannot retire unverified credits");
        carbonCredit.retireCredits(tokenId, 100);
    }
    
    function testCannotRetireMoreThanOwned() public {
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
        
        // User has 0 credits, tries to retire 100 - should fail
        vm.prank(user);
        vm.expectRevert("Insufficient balance");
        carbonCredit.retireCredits(tokenId, 100);
    }
    
    function testRetirementBurnsCredits() public {
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
        
        uint256 balanceBefore = carbonCredit.balanceOf(projectOwner, tokenId);
        
        // Retire 300 credits
        vm.prank(projectOwner);
        carbonCredit.retireCredits(tokenId, 300);
        
        uint256 balanceAfter = carbonCredit.balanceOf(projectOwner, tokenId);
        
        // Balance should decrease by exactly 300
        assertEq(balanceBefore - balanceAfter, 300);
        assertEq(balanceAfter, 700);
    }

    // ============ Pause Functionality Tests ============
    
    function testAdminCanPause() public {
        vm.prank(admin);
        carbonCredit.pause();
        
        // Contract should be paused
        assertTrue(carbonCredit.paused());
    }
    
    function testAdminCanUnpause() public {
        // Pause first
        vm.prank(admin);
        carbonCredit.pause();
        
        // Then unpause
        vm.prank(admin);
        carbonCredit.unpause();
        
        // Should not be paused anymore
        assertFalse(carbonCredit.paused());
    }
    
    function testNonAdminCannotPause() public {
        vm.prank(user);
        vm.expectRevert();
        carbonCredit.pause();
    }
    
    function testCannotMintWhenPaused() public {
        vm.prank(admin);
        carbonCredit.pause();
        
        vm.prank(projectOwner);
        vm.expectRevert();
        carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
    }
    
    function testCannotVerifyWhenPaused() public {
        // Mint first while unpaused
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Pause
        vm.prank(admin);
        carbonCredit.pause();
        
        // Try to verify - should fail
        vm.prank(verifier);
        vm.expectRevert();
        carbonCredit.verifyCreditType(tokenId);
    }
    
    function testCannotRetireWhenPaused() public {
        // Mint and verify while unpaused
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
        
        // Pause
        vm.prank(admin);
        carbonCredit.pause();
        
        // Try to retire - should fail
        vm.prank(projectOwner);
        vm.expectRevert();
        carbonCredit.retireCredits(tokenId, 100);
    }
    
    // ============ View Function Tests ============
    
    function testGetCreditTypeInfo() public {
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        // Get credit type info
        CarbonCredit.CreditType memory info = carbonCredit.getCreditTypeInfo(tokenId);
        
        // Verify all fields
        assertEq(info.projectName, "Dorper Wind Farm");
        assertEq(info.location, "South Africa");
        assertEq(info.creditCategory, "Renewable Energy");
        assertEq(info.totalSupply, 1000);
        assertFalse(info.isVerified);
        assertEq(info.verificationTimestamp, 0);
    }
    
    function testGetCreditTypeInfoRevertsForNonExistent() public {
        vm.expectRevert("Credit type does not exist");
        carbonCredit.getCreditTypeInfo(999);
    }
    
}