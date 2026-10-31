renderContractLinks();
byId("connectBtn").addEventListener("click", () => connectWallet(true));
byId("refresh").addEventListener("click", () => refreshData());
byId("newer").addEventListener("click", () => refreshData(session.offset - pageSize));
byId("older").addEventListener("click", () => refreshData(session.offset + pageSize));
byId("projectForm").addEventListener("submit", registerProject);

const wallet = window.ethereum;
if (wallet?.on) {
    wallet.on("accountsChanged", accounts => accounts.length ? connectWallet() : resetWallet());
    wallet.on("chainChanged", () => connectWallet());
    wallet.on("disconnect", resetWallet);
}
connectWallet();
