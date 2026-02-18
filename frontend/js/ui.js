// UI Helper Functions

function switchTab(tabName) {
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.add('hidden');
    });
    
    document.getElementById(`tab-${tabName}`).classList.remove('hidden');
    
    document.querySelectorAll('.nav-tab').forEach(btn => {
        btn.classList.remove('text-emerald-400');
        btn.classList.add('text-gray-400');
    });
    
    event.target.classList.remove('text-gray-400');
    event.target.classList.add('text-emerald-400');
}

function showToast(title, message) {
    const toast = document.getElementById('toast');
    const toastTitle = document.getElementById('toastTitle');
    const toastMessage = document.getElementById('toastMessage');
    
    toastTitle.textContent = title;
    toastMessage.textContent = message;
    
    toast.classList.add('show');
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 4000);
}

function formatAddress(address) {
    if (!address) return '--';
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function formatTokenAmount(amount) {
    if (!amount) return '0';
    return ethers.utils.formatEther(amount);
}

function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        showToast('Copied', 'Address copied to clipboard');
    });
}