// Web3 & Wallet Management

let provider, signer, contracts = {};
let walletConnected = false;
let userAddress = null;

// Connect Wallet
async function connectWallet() {
    if (typeof window.ethereum === 'undefined') {
        showToast('Error', 'Please install MetaMask');
        return;
    }
    
    try {
        provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        signer = provider.getSigner();
        userAddress = await signer.getAddress();
        
        // Check network
        const network = await provider.getNetwork();
        if (network.chainId !== 11155111) {
            await switchToSepolia();
        }
        
        // Initialize contracts
        contracts.ProjectRegistry = new ethers.Contract(
            CONFIG.CONTRACTS.ProjectRegistry,
            ABIS.ProjectRegistry,
            signer
        );
        
        contracts.CarbonCredit = new ethers.Contract(
            CONFIG.CONTRACTS.CarbonCredit,
            ABIS.CarbonCredit,
            signer
        );
        
        contracts.Marketplace = new ethers.Contract(
            CONFIG.CONTRACTS.Marketplace,
            ABIS.Marketplace,
            signer
        );
        
        walletConnected = true;
        updateWalletUI();
        loadContractData();
        
        showToast('Connected', `Wallet ${userAddress.slice(0, 6)}...${userAddress.slice(-4)} connected to Energy Grid`);
    } catch (err) {
        console.error(err);
        showToast('Error', err.message);
    }
}

async function switchToSepolia() {
    try {
        await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: CONFIG.NETWORK.chainId }],
        });
    } catch (err) {
        showToast('Error', 'Please switch to Sepolia network in MetaMask');
        throw err;
    }
}

function updateWalletUI() {
    document.getElementById('walletText').textContent = `${userAddress.slice(0, 6)}...${userAddress.slice(-4)}`;
    document.getElementById('networkBadge').classList.remove('hidden');
    document.getElementById('contractStatus').textContent = 'CONNECTED';
    document.getElementById('contractStatus').className = 'px-2 py-1 rounded bg-emerald-500/20 text-emerald-400 text-xs font-mono border border-emerald-500/30';
}

// Contract Interactions
async function registerProject() {
    if (!walletConnected) {
        showToast('Error', 'Please connect wallet first');
        return;
    }
    
    const name = document.getElementById('projectName').value;
    const location = document.getElementById('projectLocation').value;
    const type = parseInt(document.getElementById('projectType').value);
    const description = document.getElementById('projectDescription').value;
    const estimatedCredits = document.getElementById('estimatedCredits').value;
    const verificationDocs = document.getElementById('verificationDocs').value || 'ipfs://pending';
    
    if (!name || !location || !description || !estimatedCredits) {
        showToast('Error', 'Please fill all required fields');
        return;
    }
    
    try {
        showToast('Processing', 'Submitting to Energy Grid...');
        
        const tx = await contracts.ProjectRegistry.registerProject(
            name,
            location,
            type,
            description,
            estimatedCredits,
            verificationDocs
        );
        
        showToast('Pending', 'Waiting for blockchain confirmation...');
        const receipt = await tx.wait();
        
        // Clear form
        document.getElementById('projectName').value = '';
        document.getElementById('projectLocation').value = '';
        document.getElementById('projectDescription').value = '';
        document.getElementById('estimatedCredits').value = '';
        document.getElementById('verificationDocs').value = '';
        
        showToast('Success', `Energy Node registered! TX: ${receipt.transactionHash.slice(0, 10)}...`);
        
        // Reload projects
        setTimeout(() => loadProjects(), 2000);
    } catch (err) {
        console.error(err);
        showToast('Error', err.message.slice(0, 100));
    }
}

async function loadContractData() {
    try {
        const totalProjects = await contracts.ProjectRegistry.getTotalProjects();
        const totalListings = await contracts.Marketplace.getTotalListings();
        const volumeTraded = await contracts.Marketplace.totalVolumeTraded();
        const protocolFee = await contracts.Marketplace.protocolFeePercent();
        
        document.getElementById('totalProjects').textContent = totalProjects.toString();
        document.getElementById('totalListings').textContent = totalListings.toString();
        document.getElementById('protocolFee').textContent = (protocolFee / 10) + '%';
        
        loadProjects();
    } catch (err) {
        console.error('Error loading contract data:', err);
    }
}

async function loadProjects() {
    if (!walletConnected) return;
    
    try {
        const total = await contracts.ProjectRegistry.getTotalProjects();
        const projectsGrid = document.getElementById('projectsGrid');
        
        if (total.eq(0)) {
            projectsGrid.innerHTML = '<div class="col-span-full text-center py-12 text-gray-500">No energy nodes registered yet</div>';
            return;
        }
        
        let projectsHTML = '';
        
        for (let i = 0; i < total.toNumber(); i++) {
            const project = await contracts.ProjectRegistry.getProjectInfo(i);
            const isApproved = await contracts.ProjectRegistry.isProjectApproved(i);
            
            const statusColors = ['gray', 'emerald', 'red', 'blue', 'yellow'];
            const statusNames = ['Pending', 'Approved', 'Rejected', 'Active', 'Suspended'];
            
            projectsHTML += `
                <div class="glass-card rounded-2xl overflow-hidden border border-emerald-500/20 hover:border-emerald-500/50 transition-all hover:transform hover:scale-[1.02] group">
                    <div class="h-32 bg-gradient-to-br from-gray-900 to-black relative p-4 overflow-hidden">
                        <div class="absolute inset-0 opacity-30">
                            <svg class="w-full h-full" viewBox="0 0 200 100" preserveAspectRatio="none">
                                <path d="M0 50 Q 50 20 100 50 T 200 50" fill="none" stroke="#00ffc8" stroke-width="2" opacity="0.6">
                                    <animate attributeName="d" dur="3s" repeatCount="indefinite" values="M0 50 Q 50 20 100 50 T 200 50;M0 50 Q 50 80 100 50 T 200 50;M0 50 Q 50 20 100 50 T 200 50"/>
                                </path>
                            </svg>
                        </div>
                        <div class="absolute top-4 right-4 px-2 py-1 rounded-full bg-${statusColors[project.status]}-500/20 border border-${statusColors[project.status]}-500/30 text-xs text-${statusColors[project.status]}-400 font-mono">
                            ${statusNames[project.status]}
                        </div>
                        <div class="absolute bottom-4 left-4 flex items-center space-x-2">
                            <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                            <span class="px-2 py-1 rounded bg-black/50 text-xs font-medium text-emerald-400 border border-emerald-500/30">Node #${i}</span>
                        </div>
                    </div>
                    <div class="p-6">
                        <h3 class="font-display text-lg font-semibold mb-1">${project.projectName}</h3>
                        <p class="text-sm text-gray-500 mb-4">${project.location}</p>
                        
                        <div class="space-y-3 mb-4">
                            <div class="flex justify-between text-sm">
                                <span class="text-gray-500">Est. Annual Output</span>
                                <span class="text-emerald-400 font-semibold">${project.estimatedAnnualCredits.toString()} tCO₂</span>
                            </div>
                            <div class="flex justify-between text-sm">
                                <span class="text-gray-500">Owner</span>
                                <span class="text-gray-400 font-mono text-xs">${project.projectOwner.slice(0, 6)}...${project.projectOwner.slice(-4)}</span>
                            </div>
                        </div>
                        
                        <div class="text-xs text-gray-500 pt-4 border-t border-emerald-500/10">
                            ${project.description.slice(0, 100)}${project.description.length > 100 ? '...' : ''}
                        </div>
                    </div>
                </div>
            `;
        }
        
        projectsGrid.innerHTML = projectsHTML;
        document.getElementById('activeProjects').textContent = total.toString();
    } catch (err) {
        console.error('Error loading projects:', err);
        showToast('Error', 'Failed to sync grid data');
    }
}