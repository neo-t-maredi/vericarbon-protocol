// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ProjectRegistry
 * @author Neo Maredi
 * @notice Registry for South African carbon offset projects seeking tokenization
 * @dev Manages project approval workflow before credits can be minted
 */
contract ProjectRegistry is AccessControl, Pausable {
    
    // ============ Roles ============
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    
    // ============ Enums ============
    enum ProjectStatus {
        Pending,        // Submitted, awaiting review
        Approved,       // Approved by auditor
        Rejected,       // Rejected by auditor
        Active,         // Currently generating credits
        Suspended       // Temporarily halted
    }
    
    enum ProjectType {
        RenewableEnergy,    // Wind, solar, hydro
        ForestryCarbon,     // Afforestation, reforestation
        WasteToEnergy,      // Biogas, waste management
        CleanCooking,       // Cookstove distribution
        BlueCarbon          // Coastal/marine carbon
    }
    
    // ============ State Variables ============
    uint256 private _nextProjectId;
    
    struct Project {
        uint256 projectId;
        string projectName;         // e.g., "Dorper Wind Farm"
        string location;            // e.g., "Eastern Cape, South Africa"
        ProjectType projectType;
        ProjectStatus status;
        address projectOwner;       // Wallet of project developer
        string description;         // Project details
        uint256 estimatedAnnualCredits; // Expected tonnes CO₂e per year
        uint256 registrationDate;
        uint256 approvalDate;
        string verificationDocuments; // IPFS hash or URI
    }
    
    // Mapping: projectId => Project details
    mapping(uint256 => Project) public projects;
    
    // Mapping: project owner => array of their project IDs
    mapping(address => uint256[]) public projectsByOwner;

    // ============ Events ============
    event ProjectRegistered(
        uint256 indexed projectId,
        string projectName,
        address indexed projectOwner,
        ProjectType projectType
    );
    
    event ProjectStatusChanged(
        uint256 indexed projectId,
        ProjectStatus oldStatus,
        ProjectStatus newStatus,
        address indexed changedBy
    );
    
    event ProjectApproved(
        uint256 indexed projectId,
        address indexed approver,
        uint256 timestamp
    );
    
    event ProjectRejected(
        uint256 indexed projectId,
        address indexed rejector,
        string reason
    );
    
    // ============ Constructor ============
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // ============ Functions ============
    
    /**
     * @notice Register a new South African carbon offset project
     * @param projectName Name of the project
     * @param location Location in South Africa
     * @param projectType Type of carbon offset project
     * @param description Project details and methodology
     * @param estimatedAnnualCredits Expected tonnes CO₂e reduction per year
     * @param verificationDocuments IPFS hash or URI to supporting documents
     */
    function registerProject(
        string memory projectName,
        string memory location,
        ProjectType projectType,
        string memory description,
        uint256 estimatedAnnualCredits,
        string memory verificationDocuments
    ) external whenNotPaused returns (uint256) {
        require(bytes(projectName).length > 0, "Project name required");
        require(bytes(location).length > 0, "Location required");
        require(estimatedAnnualCredits > 0, "Estimated credits must be > 0");
        
        uint256 projectId = _nextProjectId++;
        
        projects[projectId] = Project({
            projectId: projectId,
            projectName: projectName,
            location: location,
            projectType: projectType,
            status: ProjectStatus.Pending,
            projectOwner: msg.sender,
            description: description,
            estimatedAnnualCredits: estimatedAnnualCredits,
            registrationDate: block.timestamp,
            approvalDate: 0,
            verificationDocuments: verificationDocuments
        });
        
        projectsByOwner[msg.sender].push(projectId);
        
        emit ProjectRegistered(projectId, projectName, msg.sender, projectType);
        
        return projectId;
    }
    
    /**
     * @notice Approve a project after auditing
     * @dev Only AUDITOR_ROLE can approve
     * @param projectId The project to approve
     */
    function approveProject(uint256 projectId) 
        external 
        onlyRole(AUDITOR_ROLE) 
        whenNotPaused 
    {
        Project storage project = projects[projectId];
        require(project.projectOwner != address(0), "Project does not exist");
        require(project.status == ProjectStatus.Pending, "Project not pending");
        
        ProjectStatus oldStatus = project.status;
        project.status = ProjectStatus.Approved;
        project.approvalDate = block.timestamp;
        
        emit ProjectStatusChanged(projectId, oldStatus, ProjectStatus.Approved, msg.sender);
        emit ProjectApproved(projectId, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Reject a project after auditing
     * @dev Only AUDITOR_ROLE can reject
     * @param projectId The project to reject
     * @param reason Why the project was rejected
     */
    function rejectProject(uint256 projectId, string memory reason) 
        external 
        onlyRole(AUDITOR_ROLE) 
        whenNotPaused 
    {
        Project storage project = projects[projectId];
        require(project.projectOwner != address(0), "Project does not exist");
        require(project.status == ProjectStatus.Pending, "Project not pending");
        
        ProjectStatus oldStatus = project.status;
        project.status = ProjectStatus.Rejected;
        
        emit ProjectStatusChanged(projectId, oldStatus, ProjectStatus.Rejected, msg.sender);
        emit ProjectRejected(projectId, msg.sender, reason);
    }

    /**
     * @notice Change project status (Admin only)
     * @param projectId The project to update
     * @param newStatus The new status
     */
    function updateProjectStatus(uint256 projectId, ProjectStatus newStatus)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        Project storage project = projects[projectId];
        require(project.projectOwner != address(0), "Project does not exist");
        
        ProjectStatus oldStatus = project.status;
        project.status = newStatus;
        
        emit ProjectStatusChanged(projectId, oldStatus, newStatus, msg.sender);
    }
    
    /**
     * @notice Get all project IDs owned by an address
     * @param owner The project owner address
     * @return Array of project IDs
     */
    function getProjectsByOwner(address owner) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return projectsByOwner[owner];
    }
    
    /**
     * @notice Get detailed project information
     * @param projectId The project to query
     * @return Project struct with all details
     */
    function getProjectInfo(uint256 projectId) 
        external 
        view 
        returns (Project memory) 
    {
        require(projects[projectId].projectOwner != address(0), "Project does not exist");
        return projects[projectId];
    }
    
    /**
     * @notice Check if a project is approved
     * @param projectId The project to check
     * @return bool true if approved, false otherwise
     */
    function isProjectApproved(uint256 projectId) 
        external 
        view 
        returns (bool) 
    {
        return projects[projectId].status == ProjectStatus.Approved;
    }
    
    /**
     * @notice Get total number of registered projects
     * @return uint256 count of projects
     */
    function getTotalProjects() external view returns (uint256) {
        return _nextProjectId;
    }
    
    /**
     * @notice Pause all contract operations (emergency use only)
     * @dev Only admin can pause
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract operations
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