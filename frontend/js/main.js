// Main Application Initialization

document.addEventListener('DOMContentLoaded', () => {
    console.log('%c⚡ Vericarbon Energy Grid - Initializing...', 'color: #00ffc8; font-size: 16px; font-weight: bold');
    console.log('Deployed Contracts:', CONFIG.CONTRACTS);
    
    // Initialize Three.js background
    initThreeJS();
    
    // Check if wallet is already connected
    checkWalletConnection();
    
    // Listen for account changes
    if (window.ethereum) {
        window.ethereum.on('accountsChanged', handleAccountsChanged);
        window.ethereum.on('chainChanged', handleChainChanged);
    }
});

async function checkWalletConnection() {
    if (typeof window.ethereum === 'undefined') return;
    
    try {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (accounts.length > 0) {
            // Auto-connect if previously connected
            await connectWallet();
        }
    } catch (err) {
        console.error('Error checking wallet connection:', err);
    }
}

function handleAccountsChanged(accounts) {
    if (accounts.length === 0) {
        // User disconnected wallet
        walletConnected = false;
        userAddress = null;
        document.getElementById('walletText').textContent = 'Connect Wallet';
        document.getElementById('networkBadge').classList.add('hidden');
        document.getElementById('contractStatus').textContent = 'DISCONNECTED';
        document.getElementById('contractStatus').className = 'px-2 py-1 rounded bg-gray-500/20 text-gray-400 text-xs font-mono border border-gray-500/30';
        
        const projectsGrid = document.getElementById('projectsGrid');
        projectsGrid.innerHTML = '<div class="col-span-full text-center py-12 text-gray-500">Connect wallet to view energy grid</div>';
        
        showToast('Disconnected', 'Wallet disconnected from grid');
    } else {
        // Account changed, reconnect
        connectWallet();
    }
}

function handleChainChanged(chainId) {
    // Reload page on chain change
    window.location.reload();
}

// Global error handler
window.addEventListener('error', (event) => {
    console.error('Global error:', event.error);
});

// Log version info
console.log('%c⚡ Vericarbon Energy Grid v1.0', 'color: #00ffc8; font-size: 16px; font-weight: bold');
console.log('%c🏆 Built for ETH Cape Town 2026', 'color: #00d4ff; font-size: 12px');
console.log('%c📦 GitHub: github.com/neo-t-maredi/vericarbon-protocol', 'color: #666; font-size: 10px');
