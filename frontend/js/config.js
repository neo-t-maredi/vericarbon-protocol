// Vericarbon Smart Contract Configuration
// Deployed on Ethereum Sepolia Testnet

const CONFIG = {
    NETWORK: {
        chainId: '0xaa36a7', // 11155111 in hex (Sepolia)
        chainName: 'Sepolia Testnet',
        rpcUrl: 'https://sepolia.infura.io/v3/',
        blockExplorer: 'https://sepolia.etherscan.io'
    },
    
    CONTRACTS: {
        CarbonCredit: '0x37A3A1B31bBaee86e8E307240BFB4d1e7f227a57',
        ProjectRegistry: '0x472fE102833fab6D06d8391fbe2a544Aa10257Cf',
        Marketplace: '0x1d53f45A37EB832E8C1e951dd1cA03355Ed40064'
    }
};

// Contract ABIs
const ABIS = {
    ProjectRegistry: [
        "function registerProject(string memory projectName, string memory location, uint8 projectType, string memory description, uint256 estimatedAnnualCredits, string memory verificationDocuments) external returns (uint256)",
        "function getProjectInfo(uint256 projectId) external view returns (tuple(uint256 projectId, string projectName, string location, uint8 projectType, uint8 status, address projectOwner, string description, uint256 estimatedAnnualCredits, uint256 registrationDate, uint256 approvalDate, string verificationDocuments))",
        "function getProjectsByOwner(address owner) external view returns (uint256[])",
        "function getTotalProjects() external view returns (uint256)",
        "function isProjectApproved(uint256 projectId) external view returns (bool)",
        "event ProjectRegistered(uint256 indexed projectId, string projectName, address indexed projectOwner, uint8 projectType)"
    ],
    
    CarbonCredit: [
        "function mintCreditType(string memory projectName, string memory location, string memory creditCategory, uint256 totalSupply) external returns (uint256)",
        "function verifyCreditType(uint256 tokenId) external",
        "function retireCredits(uint256 tokenId, uint256 amount) external",
        "function getCreditTypeInfo(uint256 tokenId) external view returns (tuple(string projectName, string location, string creditCategory, uint256 totalSupply, bool isVerified, uint256 verificationTimestamp))",
        "function isVerified(uint256 tokenId) external view returns (bool)",
        "function balanceOf(address account, uint256 id) external view returns (uint256)",
        "event CreditTypeMinted(uint256 indexed tokenId, string projectName, address indexed minter)",
        "event CreditTypeVerified(uint256 indexed tokenId, address indexed verifier, uint256 timestamp)"
    ],
    
    Marketplace: [
        "function createListing(uint256 tokenId, uint256 amount, uint256 pricePerCredit) external returns (uint256)",
        "function buyCredits(uint256 listingId, uint256 amount) external payable",
        "function cancelListing(uint256 listingId) external",
        "function getListing(uint256 listingId) external view returns (tuple(uint256 listingId, uint256 tokenId, address seller, uint256 amount, uint256 pricePerCredit, bool active, uint256 createdAt))",
        "function getListingsBySeller(address seller) external view returns (uint256[])",
        "function getTotalListings() external view returns (uint256)",
        "function totalVolumeTraded() external view returns (uint256)",
        "function protocolFeePercent() external view returns (uint256)",
        "event ListingCreated(uint256 indexed listingId, uint256 indexed tokenId, address indexed seller, uint256 amount, uint256 pricePerCredit)",
        "event CreditsPurchased(uint256 indexed listingId, uint256 indexed tokenId, address indexed buyer, address seller, uint256 amount, uint256 totalPrice, uint256 protocolFee)"
    ]
};