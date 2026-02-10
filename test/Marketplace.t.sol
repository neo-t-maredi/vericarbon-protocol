// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/CarbonCredit.sol";

contract MarketplaceTest is Test {
    Marketplace public marketplace;
    CarbonCredit public carbonCredit;
    
    address admin = address(1);
    address feeRecipient = address(2);
    address projectOwner = address(3);
    address verifier = address(4);
    address seller = address(5);
    address buyer = address(6);
    address buyer2 = address(7);
    
    uint256 constant INITIAL_BALANCE = 100 ether;
    
    function setUp() public {
        // Deploy CarbonCredit contract
        carbonCredit = new CarbonCredit();
        
        // Grant roles for CarbonCredit
        carbonCredit.grantRole(carbonCredit.PROJECT_ROLE(), projectOwner);
        carbonCredit.grantRole(carbonCredit.VERIFIER_ROLE(), verifier);
        
        // Mint and verify some credits
        vm.prank(projectOwner);
        uint256 tokenId = carbonCredit.mintCreditType(
            "Dorper Wind Farm",
            "South Africa",
            "Renewable Energy",
            1000
        );
        
        vm.prank(verifier);
        carbonCredit.verifyCreditType(tokenId);
        
        // Transfer credits to seller for marketplace testing
        vm.prank(projectOwner);
        carbonCredit.safeTransferFrom(projectOwner, seller, tokenId, 500, "");
        
        // Deploy Marketplace
        vm.prank(admin);
        marketplace = new Marketplace(address(carbonCredit), feeRecipient);
        
        // Give buyers ETH
        vm.deal(buyer, INITIAL_BALANCE);
        vm.deal(buyer2, INITIAL_BALANCE);
        
        // Approve marketplace to transfer seller's credits
        vm.prank(seller);
        carbonCredit.setApprovalForAll(address(marketplace), true);
    }
    
    // ============ Deployment Tests ============
    
    function testDeployment() public view {
        assertTrue(address(marketplace) != address(0));
        assertEq(address(marketplace.carbonCreditContract()), address(carbonCredit));
        assertEq(marketplace.feeRecipient(), feeRecipient);
    }
    
    function testAdminRoleGranted() public view {
        assertTrue(marketplace.hasRole(marketplace.ADMIN_ROLE(), admin));
    }
    
    function testInitialProtocolFee() public view {
        assertEq(marketplace.protocolFeePercent(), 25); // 2.5%
    }

    // ============ Listing Tests ============
    
    function testSellerCanCreateListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            0,      // tokenId
            100,    // amount
            0.01 ether  // price per credit
        );
        
        assertEq(listingId, 0); // First listing
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.seller, seller);
        assertEq(listing.amount, 100);
        assertEq(listing.pricePerCredit, 0.01 ether);
        assertTrue(listing.active);
    }

    function testListingEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Marketplace.ListingCreated(0, 0, seller, 100, 0.01 ether);
        
        vm.prank(seller);
        marketplace.createListing(0, 100, 0.01 ether);
    }
    
    function testCannotListUnverifiedCredits() public {
        // Mint new unverified credits
        vm.prank(projectOwner);
        uint256 unverifiedTokenId = carbonCredit.mintCreditType(
            "Unverified Project",
            "Location",
            "Type",
            1000
        );
        
        vm.prank(projectOwner);
        vm.expectRevert("Only verified credits can be listed");
        marketplace.createListing(unverifiedTokenId, 100, 0.01 ether);
    }
    
    function testCannotListMoreThanOwned() public {
        vm.prank(seller);
        vm.expectRevert("Insufficient balance");
        marketplace.createListing(0, 1000, 0.01 ether); // Seller only has 500
    }
    
    function testCannotListZeroAmount() public {
        vm.prank(seller);
        vm.expectRevert("Amount must be > 0");
        marketplace.createListing(0, 0, 0.01 ether);
    }
    
    function testCannotListZeroPrice() public {
        vm.prank(seller);
        vm.expectRevert("Price must be > 0");
        marketplace.createListing(0, 100, 0);
    }
    
    function testMultipleListingsIncrementId() public {
        vm.startPrank(seller);
        uint256 id1 = marketplace.createListing(0, 50, 0.01 ether);
        uint256 id2 = marketplace.createListing(0, 50, 0.02 ether);
        vm.stopPrank();
        
        assertEq(id1, 0);
        assertEq(id2, 1);
    }
    
    function testGetListingsBySeller() public {
        vm.startPrank(seller);
        marketplace.createListing(0, 50, 0.01 ether);
        marketplace.createListing(0, 50, 0.02 ether);
        vm.stopPrank();
        
        uint256[] memory sellerListings = marketplace.getListingsBySeller(seller);
        assertEq(sellerListings.length, 2);
    }

    // ============ Buying Tests ============
    
    function testBuyerCanPurchaseCredits() public {
        // Create listing
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        uint256 buyAmount = 50;
        uint256 totalPrice = buyAmount * 0.01 ether; // 0.5 ETH
        
        uint256 sellerBalanceBefore = seller.balance;
        uint256 feeRecipientBalanceBefore = feeRecipient.balance;
        
        // Buyer purchases
        vm.prank(buyer);
        marketplace.buyCredits{value: totalPrice}(listingId, buyAmount);
        
        // Check buyer received credits
        assertEq(carbonCredit.balanceOf(buyer, 0), buyAmount);
        
        // Check listing updated
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.amount, 50); // 100 - 50
        assertTrue(listing.active); // Still active since not fully sold
        
        // Check payments (2.5% fee)
        uint256 expectedFee = (totalPrice * 25) / 1000; // 0.0125 ETH
        uint256 expectedSellerProceeds = totalPrice - expectedFee; // 0.4875 ETH
        
        assertEq(seller.balance, sellerBalanceBefore + expectedSellerProceeds);
        assertEq(feeRecipient.balance, feeRecipientBalanceBefore + expectedFee);
    }
    
    function testBuyingAllCreditsDeactivatesListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        // Buy all credits
        vm.prank(buyer);
        marketplace.buyCredits{value: 1 ether}(listingId, 100);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.amount, 0);
        assertFalse(listing.active); // Should be deactivated
    }
    
    function testPurchaseEmitsEvent() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        uint256 totalPrice = 50 * 0.01 ether;
        uint256 expectedFee = (totalPrice * 25) / 1000;
        
        vm.expectEmit(true, true, true, true);
        emit Marketplace.CreditsPurchased(
            listingId,
            0,
            buyer,
            seller,
            50,
            totalPrice,
            expectedFee
        );
        
        vm.prank(buyer);
        marketplace.buyCredits{value: totalPrice}(listingId, 50);
    }
    
    function testRefundsExcessPayment() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        uint256 requiredPayment = 50 * 0.01 ether; // 0.5 ETH
        uint256 overpayment = 1 ether; // Send 1 ETH
        
        uint256 buyerBalanceBefore = buyer.balance;
        
        vm.prank(buyer);
        marketplace.buyCredits{value: overpayment}(listingId, 50);
        
        // Should refund: 1 ETH - 0.5 ETH = 0.5 ETH
        uint256 expectedBalance = buyerBalanceBefore - requiredPayment;
        assertEq(buyer.balance, expectedBalance);
    }
    
    function testCannotBuyFromInactiveListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        // Cancel listing
        vm.prank(seller);
        marketplace.cancelListing(listingId);
        
        // Try to buy
        vm.prank(buyer);
        vm.expectRevert("Listing not active");
        marketplace.buyCredits{value: 1 ether}(listingId, 50);
    }
    
    function testCannotBuyMoreThanAvailable() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        vm.prank(buyer);
        vm.expectRevert("Insufficient credits in listing");
        marketplace.buyCredits{value: 2 ether}(listingId, 150); // Only 100 available
    }
    
    function testCannotBuyWithInsufficientPayment() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        vm.prank(buyer);
        vm.expectRevert("Insufficient payment");
        marketplace.buyCredits{value: 0.001 ether}(listingId, 50); // Needs 0.5 ETH
    }
    
    function testCannotBuyZeroAmount() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        vm.prank(buyer);
        vm.expectRevert("Amount must be > 0");
        marketplace.buyCredits{value: 1 ether}(listingId, 0);
    }
    
    function testTotalVolumeTracked() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        uint256 totalPrice = 50 * 0.01 ether;
        
        vm.prank(buyer);
        marketplace.buyCredits{value: totalPrice}(listingId, 50);
        
        assertEq(marketplace.totalVolumeTraded(), totalPrice);
    }

    // ============ Cancellation Tests ============
    
    function testSellerCanCancelListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        vm.prank(seller);
        marketplace.cancelListing(listingId);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.active);
    }
    
    function testCancellationEmitsEvent() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        vm.expectEmit(true, true, true, true);
        emit Marketplace.ListingCancelled(listingId, seller);
        
        vm.prank(seller);
        marketplace.cancelListing(listingId);
    }
    
    function testOnlySellerCanCancel() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        vm.prank(buyer);
        vm.expectRevert("Only seller can cancel");
        marketplace.cancelListing(listingId);
    }
    
    function testCannotCancelInactiveListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        vm.prank(seller);
        marketplace.cancelListing(listingId);
        
        // Try to cancel again
        vm.prank(seller);
        vm.expectRevert("Listing not active");
        marketplace.cancelListing(listingId);
    }
    
    // ============ Admin Tests ============
    
    function testAdminCanUpdateProtocolFee() public {
        vm.prank(admin);
        marketplace.updateProtocolFee(50); // 5%
        
        assertEq(marketplace.protocolFeePercent(), 50);
    }
    
    function testProtocolFeeUpdateEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Marketplace.ProtocolFeeUpdated(25, 50);
        
        vm.prank(admin);
        marketplace.updateProtocolFee(50);
    }
    
    function testCannotSetFeeTooHigh() public {
        vm.prank(admin);
        vm.expectRevert("Fee cannot exceed 10%");
        marketplace.updateProtocolFee(101); // > 10%
    }
    
    function testAdminCanUpdateFeeRecipient() public {
        address newRecipient = address(999);
        
        vm.prank(admin);
        marketplace.updateFeeRecipient(newRecipient);
        
        assertEq(marketplace.feeRecipient(), newRecipient);
    }
    
    function testCannotSetZeroAddressAsRecipient() public {
        vm.prank(admin);
        vm.expectRevert("Invalid address");
        marketplace.updateFeeRecipient(address(0));
    }
    
    function testAdminCanPause() public {
        vm.prank(admin);
        marketplace.pause();
        
        assertTrue(marketplace.paused());
    }
    
    function testCannotListWhenPaused() public {
        vm.prank(admin);
        marketplace.pause();
        
        vm.prank(seller);
        vm.expectRevert();
        marketplace.createListing(0, 100, 0.01 ether);
    }
    
    function testCannotBuyWhenPaused() public {
        // Create listing first
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(0, 100, 0.01 ether);
        
        // Pause
        vm.prank(admin);
        marketplace.pause();
        
        // Try to buy
        vm.prank(buyer);
        vm.expectRevert();
        marketplace.buyCredits{value: 1 ether}(listingId, 50);
    }
}
