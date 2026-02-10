// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CarbonCredit.sol";

/**
 * @title Marketplace
 * @author Neo Maredi
 * @notice Decentralized marketplace for trading verified carbon credits
 * @dev Enables listing, buying, and price discovery for South African carbon offset projects
 */
contract Marketplace is AccessControl, Pausable, ReentrancyGuard {
    // ============ Roles ============
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // ============ State Variables ============
    CarbonCredit public carbonCreditContract;
    
    uint256 public protocolFeePercent = 25; // 2.5% (basis points: 25/1000 = 0.025)
    address public feeRecipient;
    
    uint256 private _nextListingId;
    
    struct Listing {
        uint256 listingId;
        uint256 tokenId;           // CarbonCredit token ID
        address seller;
        uint256 amount;            // Number of credits for sale
        uint256 pricePerCredit;    // Price in wei per credit
        bool active;
        uint256 createdAt;
    }
    
    // Mapping: listingId => Listing details
    mapping(uint256 => Listing) public listings;
    
    // Mapping: seller => array of their listing IDs
    mapping(address => uint256[]) public listingsBySeller;
    
    // Track total volume traded
    uint256 public totalVolumeTraded;

    // ============ Events ============
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 amount,
        uint256 pricePerCredit
    );
    
    event ListingCancelled(
        uint256 indexed listingId,
        address indexed seller
    );
    
    event CreditsPurchased(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 amount,
        uint256 totalPrice,
        uint256 protocolFee
    );
    
    event ProtocolFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );
    
    event FeeRecipientUpdated(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    
    // ============ Constructor ============
    constructor(address _carbonCreditContract, address _feeRecipient) {
        require(_carbonCreditContract != address(0), "Invalid CarbonCredit address");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        carbonCreditContract = CarbonCredit(_carbonCreditContract);
        feeRecipient = _feeRecipient;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // ============ Functions ============
    
    /**
     * @notice List carbon credits for sale
     * @param tokenId The CarbonCredit token ID to sell
     * @param amount Number of credits to list
     * @param pricePerCredit Price in wei per credit
     */

    // ============ Functions ============
    
    /**
     * @notice List carbon credits for sale
     * @param tokenId The CarbonCredit token ID to sell
     * @param amount Number of credits to list
     * @param pricePerCredit Price in wei per credit
     */
    function createListing(
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerCredit
    ) external whenNotPaused returns (uint256) {
        require(amount > 0, "Amount must be > 0");
        require(pricePerCredit > 0, "Price must be > 0");
        
        // Check seller owns enough credits
        require(
            carbonCreditContract.balanceOf(msg.sender, tokenId) >= amount,
            "Insufficient balance"
        );
        
        // Check credits are verified
        require(
            carbonCreditContract.isVerified(tokenId),
            "Only verified credits can be listed"
        );
        
        uint256 listingId = _nextListingId++;
        
        listings[listingId] = Listing({
            listingId: listingId,
            tokenId: tokenId,
            seller: msg.sender,
            amount: amount,
            pricePerCredit: pricePerCredit,
            active: true,
            createdAt: block.timestamp
        });
        
        listingsBySeller[msg.sender].push(listingId);
        
        emit ListingCreated(listingId, tokenId, msg.sender, amount, pricePerCredit);
        
        return listingId;
    }
    
    /**
     * @notice Purchase carbon credits from a listing
     * @param listingId The listing to purchase from
     * @param amount Number of credits to buy
     */
    function buyCredits(uint256 listingId, uint256 amount) 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
    {
        Listing storage listing = listings[listingId];
        
        require(listing.active, "Listing not active");
        require(amount > 0, "Amount must be > 0");
        require(amount <= listing.amount, "Insufficient credits in listing");
        
        // Calculate prices
        uint256 totalPrice = amount * listing.pricePerCredit;
        uint256 protocolFee = (totalPrice * protocolFeePercent) / 1000;
        uint256 sellerProceeds = totalPrice - protocolFee;
        
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
        }
        
        // Transfer credits from seller to buyer
        carbonCreditContract.safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId,
            amount,
            ""
        );
        
        // Transfer payments
        (bool successSeller, ) = listing.seller.call{value: sellerProceeds}("");
        require(successSeller, "Seller payment failed");
        
        (bool successFee, ) = feeRecipient.call{value: protocolFee}("");
        require(successFee, "Fee payment failed");
        
        // Refund excess payment
        if (msg.value > totalPrice) {
            (bool successRefund, ) = msg.sender.call{value: msg.value - totalPrice}("");
            require(successRefund, "Refund failed");
        }
        
        // Update stats
        totalVolumeTraded += totalPrice;
        
        emit CreditsPurchased(
            listingId,
            listing.tokenId,
            msg.sender,
            listing.seller,
            amount,
            totalPrice,
            protocolFee
        );
    }
    
    /**
     * @notice Cancel an active listing
     * @param listingId The listing to cancel
     */
    function cancelListing(uint256 listingId) external whenNotPaused {
        Listing storage listing = listings[listingId];
        
        require(listing.seller == msg.sender, "Only seller can cancel");
        require(listing.active, "Listing not active");
        
        listing.active = false;
        
        emit ListingCancelled(listingId, msg.sender);
    }

    /**
     * @notice Get listing details
     * @param listingId The listing to query
     * @return Listing struct with all details
     */
    function getListing(uint256 listingId) 
        external 
        view 
        returns (Listing memory) 
    {
        return listings[listingId];
    }
    
    /**
     * @notice Get all listings by a seller
     * @param seller The seller address
     * @return Array of listing IDs
     */
    function getListingsBySeller(address seller) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return listingsBySeller[seller];
    }
    
    /**
     * @notice Get total number of listings created
     * @return uint256 count
     */
    function getTotalListings() external view returns (uint256) {
        return _nextListingId;
    }
    
    /**
     * @notice Update protocol fee (Admin only)
     * @param newFeePercent New fee in basis points (e.g., 25 = 2.5%)
     */
    function updateProtocolFee(uint256 newFeePercent) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(newFeePercent <= 100, "Fee cannot exceed 10%");
        
        uint256 oldFee = protocolFeePercent;
        protocolFeePercent = newFeePercent;
        
        emit ProtocolFeeUpdated(oldFee, newFeePercent);
    }
    
    /**
     * @notice Update fee recipient (Admin only)
     * @param newRecipient New fee recipient address
     */
    function updateFeeRecipient(address newRecipient) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(newRecipient != address(0), "Invalid address");
        
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }
    
    /**
     * @notice Pause marketplace operations (emergency)
     * @dev Only admin can pause
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause marketplace operations
     * @dev Only admin can unpause
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Override required by Solidity for AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}



