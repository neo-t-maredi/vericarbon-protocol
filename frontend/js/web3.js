const pageSize = 8n;
let session = null;
let connectionAttempt = 0;
let readAttempt = 0;

function clearReadings() {
    byId("totalProjects").textContent = "—";
    byId("totalListings").textContent = "—";
    byId("protocolFee").textContent = "—";
    byId("projectsGrid").replaceChildren();
    byId("pager").hidden = true;
    byId("projectFields").disabled = true;
    message("marketState", "Marketplace data has not been read.");
}

function resetWallet() {
    session = null;
    connectionAttempt++;
    readAttempt++;
    clearReadings();
    byId("connectBtn").hidden = false;
    byId("connectBtn").disabled = false;
    byId("refresh").disabled = true;
    message("walletState", "Wallet disconnected.");
    message("recordsState", "Connect a Sepolia wallet to read the registry.");
    message("txState", "Registration opens after the registry responds.");
}

async function connectWallet(prompt = false) {
    resetWallet();
    const attempt = connectionAttempt;
    const wallet = window.ethereum;
    if (!wallet || !window.ethers) {
        message("walletState", wallet ? "Wallet library unavailable. Reload to retry." : "Open in a browser with an Ethereum wallet to connect.");
        return;
    }
    byId("connectBtn").disabled = true;
    try {
        const accounts = await wallet.request({ method: prompt ? "eth_requestAccounts" : "eth_accounts" });
        if (attempt !== connectionAttempt || !accounts.length) return;
        let chain = await wallet.request({ method: "eth_chainId" });
        if (attempt !== connectionAttempt) return;
        if (BigInt(chain) !== BigInt(CONFIG.NETWORK.chainId) && prompt) {
            await wallet.request({ method: "wallet_switchEthereumChain", params: [{ chainId: CONFIG.NETWORK.chainId }] });
            chain = await wallet.request({ method: "eth_chainId" });
        }
        if (attempt !== connectionAttempt) return;
        if (BigInt(chain) !== BigInt(CONFIG.NETWORK.chainId)) {
            message("walletState", "Wrong network. Connect on Sepolia to continue.", true);
            return;
        }
        const provider = new ethers.providers.Web3Provider(wallet);
        session = {
            account: accounts[0], provider,
            registry: new ethers.Contract(CONFIG.CONTRACTS.ProjectRegistry, ABIS.ProjectRegistry, provider),
            market: new ethers.Contract(CONFIG.CONTRACTS.Marketplace, ABIS.Marketplace, provider),
            offset: 0n, ready: false, submitting: false
        };
        byId("connectBtn").hidden = true;
        message("walletState", "Wallet on Sepolia · " + accounts[0].slice(0, 6) + "…" + accounts[0].slice(-4));
        await refreshData();
    } catch (error) {
        if (attempt === connectionAttempt) {
            message("walletState", error.code === 4001 ? "Wallet request declined. You can reconnect." : "Could not connect to Sepolia. Check your wallet and retry.", true);
        }
    } finally {
        if (attempt === connectionAttempt) byId("connectBtn").disabled = false;
    }
}

async function readRegistry(current, attempt) {
    try {
        const total = BigInt((await current.registry.getTotalProjects()).toString());
        if (attempt !== readAttempt) return;
        if (current.offset >= total) current.offset = 0n;
        const ids = [];
        for (let id = total - current.offset - 1n; id >= 0n && ids.length < Number(pageSize); id--) {
            ids.push(id.toString());
        }
        const projects = await Promise.allSettled(ids.map(id => current.registry.getProjectInfo(id)));
        if (attempt !== readAttempt) return;
        let missing = 0;
        const cards = projects.map((result, index) => {
            if (result.status === "fulfilled") return projectCard(result.value);
            missing++;
            return textElement("p", "Project #" + ids[index] + " could not be read.");
        });
        byId("projectsGrid").replaceChildren(...cards);
        byId("totalProjects").textContent = total.toString();
        byId("pager").hidden = total <= pageSize;
        byId("newer").disabled = current.offset === 0n;
        byId("older").disabled = current.offset + pageSize >= total;
        let label = total ? "Newest first · showing " + (current.offset + 1n) + "–" + (current.offset + BigInt(ids.length)) + " of " + total + "." : "No projects registered.";
        if (missing) label += " Some records are unavailable. Refresh to retry.";
        message("recordsState", label, missing > 0);
        current.ready = true;
        byId("projectFields").disabled = current.submitting;
        if (byId("txState").textContent === "Registration opens after the registry responds.") {
            message("txState", "Your wallet must confirm the submission.");
        }
    } catch {
        if (attempt === readAttempt) {
            current.ready = false;
            byId("projectFields").disabled = true;
            message("recordsState", "Registry unavailable. Check the network and refresh to retry.", true);
        }
    }
}

async function readMarket(current, attempt) {
    try {
        const [listings, fee] = await Promise.all([current.market.getTotalListings(), current.market.protocolFeePercent()]);
        if (attempt !== readAttempt) return;
        byId("totalListings").textContent = listings.toString();
        byId("protocolFee").textContent = Number(fee.toString()) / 10 + "%";
        message("marketState", "Marketplace readings available.");
    } catch {
        if (attempt === readAttempt) message("marketState", "Marketplace readings unavailable. Refresh to retry.", true);
    }
}

async function refreshData(offset = 0n) {
    const current = session;
    if (!current) return;
    const attempt = ++readAttempt;
    current.offset = offset;
    current.ready = false;
    clearReadings();
    byId("refresh").disabled = true;
    message("recordsState", "Reading the registry…");
    message("marketState", "Reading marketplace data…");
    await Promise.all([readRegistry(current, attempt), readMarket(current, attempt)]);
    if (attempt === readAttempt) byId("refresh").disabled = false;
}

async function registerProject(event) {
    event.preventDefault();
    const current = session;
    if (!current?.ready || current.submitting) return;
    const value = id => byId(id).value.trim();
    const name = value("projectName"), location = value("projectLocation"), description = value("projectDescription");
    const amount = value("estimatedCredits"), type = Number(value("projectType"));
    if (!name || !location || !description || !Number.isInteger(type) || type < 0 || type > 4 ||
        !/^\d{1,78}$/.test(amount) || BigInt(amount) === 0n || BigInt(amount) >= 2n ** 256n) {
        message("txState", "Enter the project details and a positive whole number within the contract limit.", true);
        return;
    }
    const evidence = value("verificationDocs");
    current.submitting = true;
    byId("projectFields").disabled = true;
    let hash;
    try {
        const chain = await window.ethereum.request({ method: "eth_chainId" });
        if (session !== current) return;
        if (BigInt(chain) !== BigInt(CONFIG.NETWORK.chainId)) {
            resetWallet();
            message("walletState", "Wrong network. Reconnect on Sepolia.", true);
            return;
        }
        message("txState", "Confirm the application in your wallet.");
        const signed = current.registry.connect(current.provider.getSigner(current.account));
        const tx = await signed.registerProject(name, location, type, description, amount, evidence);
        if (session !== current) return;
        hash = tx.hash;
        message("txState", "Submitted. Waiting for confirmation: " + hash);
        const receipt = await tx.wait();
        if (session !== current) return;
        byId("projectForm").reset();
        message("txState", "Application confirmed. Transaction: " + receipt.transactionHash);
        await refreshData();
    } catch (error) {
        if (session !== current) return;
        if (error.code === "TRANSACTION_REPLACED" && !error.cancelled && error.receipt?.status === 1) {
            byId("projectForm").reset();
            message("txState", "Application confirmed. Transaction: " + error.receipt.transactionHash);
            await refreshData();
        } else {
            const details = error.reason || error.message || "Wallet or network error.";
            message("txState", hash ? "Check transaction " + hash + " before retrying. " + details : "Application was not confirmed. " + details, true);
        }
    } finally {
        if (session === current) {
            current.submitting = false;
            byId("projectFields").disabled = !current.ready;
        }
    }
}
