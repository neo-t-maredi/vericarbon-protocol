// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ProjectRegistry.sol";

contract ProjectRegistryTest is Test {
    ProjectRegistry public registry;
    
    address admin = address(1);
    address auditor = address(2);
    address projectDev1 = address(3);
    address projectDev2 = address(4);
    address user = address(5);
    
    function setUp() public {
        // Deploy registry (test contract deploys it)
        registry = new ProjectRegistry();
        
        // Grant admin role to our admin address
        registry.grantRole(registry.ADMIN_ROLE(), admin);
        registry.grantRole(registry.DEFAULT_ADMIN_ROLE(), admin);
        
        // Now admin can grant auditor role
        vm.prank(admin);
        registry.grantRole(registry.AUDITOR_ROLE(), auditor);
    }
    
    // ============ Deployment Tests ============
    
    function testDeployment() public view {
        assertTrue(address(registry) != address(0));
    }
    
    function testAdminRoleGranted() public view {
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), admin));
    }
    
    function testDefaultAdminRole() public view {
        // Test contract is the original deployer
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), address(this)));
        // Admin was granted the role in setUp
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
    }

    // ============ Registration Tests ============
    
    function testProjectDeveloperCanRegister() public {
        vm.prank(projectDev1);
        uint256 projectId = registry.registerProject(
            "Dorper Wind Farm",
            "Eastern Cape, South Africa",
            ProjectRegistry.ProjectType.RenewableEnergy,
            "138MW wind farm generating renewable energy credits",
            50000, // 50,000 tonnes CO₂e per year
            "ipfs://QmXyz123..."
        );
        
        assertEq(projectId, 0); // First project ID
        
        ProjectRegistry.Project memory project = registry.getProjectInfo(projectId);
        assertEq(project.projectName, "Dorper Wind Farm");
        assertEq(project.projectOwner, projectDev1);
        assertEq(uint(project.status), uint(ProjectRegistry.ProjectStatus.Pending));
    }
    
    function testRegistrationEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ProjectRegistry.ProjectRegistered(
            0, 
            "Dorper Wind Farm", 
            projectDev1, 
            ProjectRegistry.ProjectType.RenewableEnergy
        );
        
        vm.prank(projectDev1);
        registry.registerProject(
            "Dorper Wind Farm",
            "Eastern Cape, South Africa",
            ProjectRegistry.ProjectType.RenewableEnergy,
            "138MW wind farm",
            50000,
            "ipfs://QmXyz123..."
        );
    }
    
    function testCannotRegisterWithEmptyName() public {
        vm.prank(projectDev1);
        vm.expectRevert("Project name required");
        registry.registerProject(
            "",
            "Eastern Cape, South Africa",
            ProjectRegistry.ProjectType.RenewableEnergy,
            "Description",
            50000,
            "ipfs://QmXyz123..."
        );
    }
    
    function testCannotRegisterWithEmptyLocation() public {
        vm.prank(projectDev1);
        vm.expectRevert("Location required");
        registry.registerProject(
            "Dorper Wind Farm",
            "",
            ProjectRegistry.ProjectType.RenewableEnergy,
            "Description",
            50000,
            "ipfs://QmXyz123..."
        );
    }
    
    function testCannotRegisterWithZeroCredits() public {
        vm.prank(projectDev1);
        vm.expectRevert("Estimated credits must be > 0");
        registry.registerProject(
            "Dorper Wind Farm",
            "Eastern Cape, South Africa",
            ProjectRegistry.ProjectType.RenewableEnergy,
            "Description",
            0,
            "ipfs://QmXyz123..."
        );
    }
    
    function testMultipleProjectsIncrementId() public {
        vm.startPrank(projectDev1);
        uint256 id1 = registry.registerProject(
            "Project 1", "Cape Town", ProjectRegistry.ProjectType.RenewableEnergy, 
            "Solar", 10000, "ipfs://1"
        );
        uint256 id2 = registry.registerProject(
            "Project 2", "Johannesburg", ProjectRegistry.ProjectType.WasteToEnergy, 
            "Biogas", 15000, "ipfs://2"
        );
        vm.stopPrank();
        
        assertEq(id1, 0);
        assertEq(id2, 1);
    }
    
    function testGetProjectsByOwner() public {
        vm.startPrank(projectDev1);
        registry.registerProject(
            "Project 1", "Cape Town", ProjectRegistry.ProjectType.RenewableEnergy, 
            "Solar", 10000, "ipfs://1"
        );
        registry.registerProject(
            "Project 2", "Durban", ProjectRegistry.ProjectType.ForestryCarbon, 
            "Forestry", 5000, "ipfs://2"
        );
        vm.stopPrank();
        
        vm.prank(projectDev2);
        registry.registerProject(
            "Project 3", "Pretoria", ProjectRegistry.ProjectType.CleanCooking, 
            "Cookstoves", 3000, "ipfs://3"
        );
        
        uint256[] memory dev1Projects = registry.getProjectsByOwner(projectDev1);
        uint256[] memory dev2Projects = registry.getProjectsByOwner(projectDev2);
        
        assertEq(dev1Projects.length, 2);
        assertEq(dev2Projects.length, 1);
    }

    // ============ Approval Tests ============
    
    function testAuditorCanApproveProject() public {
        // Register project first
        vm.prank(projectDev1);
        uint256 projectId = registry.registerProject(
            "Dorper Wind Farm",
            "Eastern Cape, South Africa",
            ProjectRegistry.ProjectType.RenewableEnergy,
            "Wind farm",
            50000,
            "ipfs://docs"
        );
        
        // Auditor approves
        vm.prank(auditor);
        registry.approveProject(projectId);
        
        // Check status changed
        assertTrue(registry.isProjectApproved(projectId));
        
        ProjectRegistry.Project memory project = registry.getProjectInfo(projectId);
        assertEq(uint(project.status), uint(ProjectRegistry.ProjectStatus.Approved));
        assertGt(project.approvalDate, 0);
    }
    
    function testApprovalEmitsEvents() public {
        vm.prank(projectDev1);
        uint256 projectId = registry.registerProject(
            "Dorper Wind Farm",
            "Eastern Cape",
            ProjectRegistry.ProjectType.RenewableEnergy,
            "Wind",
            50000,
            "ipfs://docs"
        );
        
        // Expect both events
        vm.expectEmit(true, true, true, true);
        emit ProjectRegistry.ProjectStatusChanged(
            projectId,
            ProjectRegistry.ProjectStatus.Pending,
            ProjectRegistry.ProjectStatus.Approved,
            auditor
        );
        
        vm.prank(auditor);
        registry.approveProject(projectId);
    }
    
    function testNonAuditorCannotApprove() public {
        vm.prank(projectDev1);
        uint256 projectId = registry.registerProject(
            "Project", "Location", ProjectRegistry.ProjectType.RenewableEnergy,
            "Desc", 1000, "ipfs://1"
        );
        
        // Random user tries to approve
        vm.prank(user);
        vm.expectRevert();
        registry.approveProject(projectId);
    }
    
    function testCannotApproveNonExistentProject() public {
        vm.prank(auditor);
        vm.expectRevert("Project does not exist");
        registry.approveProject(999);
    }
    
    function testCannotApproveNonPendingProject() public {
        // Register and approve
        vm.prank(projectDev1);
        uint256 projectId = registry.registerProject(
            "Project", "Location", ProjectRegistry.ProjectType.RenewableEnergy,
            "Desc", 1000, "ipfs://1"
        );
        
        vm.prank(auditor);
        registry.approveProject(projectId);
        
        // Try to approve again
        vm.prank(auditor);
        vm.expectRevert("Project not pending");
        registry.approveProject(projectId);
    }
    
    // ============ Rejection Tests ============
    
    function testAuditorCanRejectProject() public {
        vm.prank(projectDev1);
        uint256 projectId = registry.registerProject(
            "Fake Project",
            "Nowhere",
            ProjectRegistry.ProjectType.RenewableEnergy,
            "Scam",
            1000,
            "ipfs://fake"
        );
        
        vm.prank(auditor);
        registry.rejectProject(projectId, "Insufficient documentation");
        
        ProjectRegistry.Project memory project = registry.getProjectInfo(projectId);
        assertEq(uint(project.status), uint(ProjectRegistry.ProjectStatus.Rejected));
    }
    
    function testRejectionEmitsEvent() public {
        vm.prank(projectDev1);
        uint256 projectId = registry.registerProject(
            "Project", "Location", ProjectRegistry.ProjectType.RenewableEnergy,
            "Desc", 1000, "ipfs://1"
        );
        
        vm.expectEmit(true, true, true, true);
        emit ProjectRegistry.ProjectRejected(projectId, auditor, "Invalid data");
        
        vm.prank(auditor);
        registry.rejectProject(projectId, "Invalid data");
    }
    
    function testNonAuditorCannotReject() public {
        vm.prank(projectDev1);
        uint256 projectId = registry.registerProject(
            "Project", "Location", ProjectRegistry.ProjectType.RenewableEnergy,
            "Desc", 1000, "ipfs://1"
        );
        
        vm.prank(user);
        vm.expectRevert();
        registry.rejectProject(projectId, "Reason");
    }
    
    function testCannotRejectNonExistentProject() public {
        vm.prank(auditor);
        vm.expectRevert("Project does not exist");
        registry.rejectProject(999, "Reason");
    }

    
}




