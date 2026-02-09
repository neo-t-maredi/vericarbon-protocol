// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CarbonCredit
 * @author Neo Maredi
 * @notice ERC-1155 token representing verified carbon offset credits from African projects
 * @dev Supports multiple credit types: forestry, renewable energy, cookstoves, etc.
 */
contract CarbonCredit is ERC1155, AccessControl, Pausable {
    
    // ============ Roles ============
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant PROJECT_ROLE = keccak256("PROJECT_ROLE");

    // ============ State Variables ============
    uint256 private _nextTokenId;
    
    struct CreditType {
        string projectName;        // e.g., "Dorper Wind Farm"
        string location;           // e.g., "Molteno"
        string creditCategory;     // e.g., "Renewable Energy"
        uint256 totalSupply;       // Total credits minted for this type
        bool isVerified;           // Verification status
        uint256 verificationTimestamp;
    }
    
    // Mapping: tokenId => CreditType details
    mapping(uint256 => CreditType) public creditTypes;

    // ============ Events ============
    event CreditTypeMinted(
        uint256 indexed tokenId,
        string projectName,
        string location,
        string creditCategory,
        uint256 amount
    );
    
    event CreditVerified(
        uint256 indexed tokenId,
        uint256 timestamp
    );
    
    event CreditRetired(
        uint256 indexed tokenId,
        address indexed retiree,
        uint256 amount
    );

    // ============ Constructor ============
    constructor() ERC1155("https://vericarbon.io/api/metadata/{id}.json") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ============ Functions ============
    /**
     * @dev Override required by Solidity when inheriting from both ERC1155 and AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Mint a new carbon credit type for a verified project
     * @dev Only accounts with PROJECT_ROLE can mint new credit types
     * @param projectName Name of the carbon offset project
     * @param location Geographic location of the project
     * @param creditCategory Type of carbon offset (e.g., "Renewable Energy", "Forestry")
     * @param amount Number of credits to mint for this project
     */
    function mintCreditType(
        string memory projectName,
        string memory location,
        string memory creditCategory,
        uint256 amount
    ) external onlyRole(PROJECT_ROLE) whenNotPaused returns (uint256) {
        // Get current token ID and increment for next use
        uint256 tokenId = _nextTokenId++;
        
        // Create the credit type with unverified status initially
        creditTypes[tokenId] = CreditType({
            projectName: projectName,
            location: location,
            creditCategory: creditCategory,
            totalSupply: amount,
            isVerified: false,  // Starts unverified until verifier approves
            verificationTimestamp: 0
        });
        
        // Mint the tokens to the project owner (msg.sender)
        _mint(msg.sender, tokenId, amount, "");
        
        // Emit event for off-chain tracking
        emit CreditTypeMinted(tokenId, projectName, location, creditCategory, amount);
        
        return tokenId; 
    }

    /**
     * @notice Verify a carbon credit type after validating the project
     * @dev Only accounts with VERIFIER_ROLE can verify credits
     * @param tokenId The token ID to verify
     */
    function verifyCreditType(uint256 tokenId) 
        external 
        onlyRole(VERIFIER_ROLE) 
        whenNotPaused 
    {
        // Make sure this credit type exists
        require(creditTypes[tokenId].totalSupply > 0, "Credit type does not exist");
        
        // Make sure it hasn't already been verified
        require(!creditTypes[tokenId].isVerified, "Credit type already verified");
        
        // Mark as verified and record timestamp
        creditTypes[tokenId].isVerified = true;
        creditTypes[tokenId].verificationTimestamp = block.timestamp;
        
        // Emit event for tracking
        emit CreditVerified(tokenId, block.timestamp);
    }
    /**
     * @notice Retire (burn) carbon credits to claim the offset
     * @dev Burns credits permanently - cannot be undone
     * @param tokenId The token ID to retire
     * @param amount Number of credits to retire
     */
    function retireCredits(uint256 tokenId, uint256 amount) 
        external 
        whenNotPaused 
    {
        // Make sure the credits are verified before allowing retirement
        require(creditTypes[tokenId].isVerified, "Cannot retire unverified credits");
        
        // Make sure caller owns enough credits
        require(balanceOf(msg.sender, tokenId) >= amount, "Insufficient balance");
        
        // Burn the credits permanently
        _burn(msg.sender, tokenId, amount);
        
        // Emit event for carbon offset tracking
        emit CreditRetired(tokenId, msg.sender, amount);
    }

    /**
     * @notice Get detailed information about a credit type
     * @param tokenId The token ID to query
     * @return CreditType struct with all project details
     */
    function getCreditTypeInfo(uint256 tokenId) 
        external 
        view 
        returns (CreditType memory) 
    {
        require(creditTypes[tokenId].totalSupply > 0, "Credit type does not exist");
        return creditTypes[tokenId];
    }

    /**
     * @notice Check if a credit type is verified
     * @param tokenId The token ID to check
     * @return bool true if verified, false otherwise
     */
    function isVerified(uint256 tokenId) external view returns (bool) {
        return creditTypes[tokenId].isVerified;
    }

    /**
     * @notice Pause all contract operations (emergency use only)
     * @dev Only admin can pause
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract operations
     * @dev Only admin can unpause
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause(); 
    }
}
