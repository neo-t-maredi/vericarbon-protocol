const { before, after, test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const http = require("node:http");
const path = require("node:path");
const { chromium } = require("playwright-core");
const { ethers } = require("../../frontend/vendor/ethers-5.7.2.min.js");

const root = path.resolve(__dirname, "../..");
const rpc = new ethers.providers.Web3Provider({
    async request({ method, params = [] }) {
        const response = await fetch("http://127.0.0.1:18545", {
            method: "POST", headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params })
        });
        const result = await response.json();
        if (result.error) throw Object.assign(new Error(result.error.message), result.error);
        return result.result;
    }
});
const badText = '<img src=x onerror="window.injected=true">';
let browser, server, origin, registry, account;
const addresses = {};

before(async () => {
    account = (await rpc.listAccounts())[0];
    const signer = rpc.getSigner(account);
    for (const name of ["CarbonCredit", "ProjectRegistry", "Marketplace"]) {
        const file = path.join(root, "out", name + ".sol", name + ".json");
        const artifact = JSON.parse(await fs.readFile(file, "utf8"));
        const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode.object, signer);
        const args = name === "Marketplace" ? [addresses.CarbonCredit, account] : [];
        const contract = await factory.deploy(...args);
        await contract.deployed();
        addresses[name] = contract.address;
        if (name === "ProjectRegistry") registry = contract;
    }
    server = http.createServer(async (req, res) => {
        try {
            const pathname = new URL(req.url, "http://localhost").pathname;
            const file = path.resolve(root, "frontend", "." + (pathname === "/" ? "/index.html" : pathname));
            if (!file.startsWith(path.join(root, "frontend") + path.sep)) throw Error("Bad path");
            let body = await fs.readFile(file);
            if (pathname === "/js/config.js") body = body.toString() + "\nObject.assign(CONFIG.CONTRACTS, " + JSON.stringify(addresses) + ");";
            res.setHeader("Content-Type", { ".html": "text/html", ".css": "text/css", ".js": "text/javascript" }[path.extname(file)] || "application/octet-stream");
            res.end(body);
        } catch { res.writeHead(404).end(); }
    });
    await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
    origin = "http://127.0.0.1:" + server.address().port;
    browser = await chromium.launch({ executablePath: process.env.CHROME_BIN || "/usr/bin/google-chrome" });
});

after(async () => {
    await browser?.close();
    if (server) await new Promise(resolve => server.close(resolve));
});

async function openWallet(t) {
    const page = await browser.newPage();
    t.after(() => page.close());
    const wallet = { accounts: [account], chain: "0xaa36a7", marketFails: false, registryFails: false, sends: 0 };
    await page.exposeFunction("walletRpc", async ({ method, params = [] }) => {
        if (method === "eth_accounts" || method === "eth_requestAccounts") return wallet.accounts;
        if (method === "eth_chainId") return wallet.chain;
        if (method === "wallet_switchEthereumChain") throw Error("Network switch declined");
        if (method === "eth_call") {
            const target = params[0].to.toLowerCase();
            if ((wallet.marketFails && target === addresses.Marketplace.toLowerCase()) ||
                (wallet.registryFails && target === addresses.ProjectRegistry.toLowerCase())) return "0x";
        }
        if (method === "eth_sendTransaction") wallet.sends++;
        return rpc.send(method, params);
    });
    await page.addInitScript(() => {
        const listeners = new Map();
        window.ethereum = {
            request: args => window.walletRpc(args),
            on: (name, callback) => listeners.set(name, callback),
            emit: (name, value) => listeners.get(name)?.(value)
        };
    });
    return { page, wallet };
}

test("disconnected desktop and mobile keep navigation usable and all readings unknown", async t => {
    const page = await browser.newPage();
    t.after(() => page.close());
    for (const [name, width, height] of [["desktop", 1365, 900], ["mobile", 390, 844]]) {
        await page.setViewportSize({ width, height });
        await page.goto(origin);
        await page.waitForFunction(() => document.querySelector("#contractLinks a") !== null);
        assert.equal(await page.locator("#totalProjects").textContent(), "—");
        assert.equal(await page.locator("#protocolFee").textContent(), "—");
        assert(await page.locator("#submitBtn").isDisabled());
        assert(await page.getByRole("navigation").getByText("Records").isVisible());
        assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        if (process.env.SCREENSHOT_DIR) {
            await fs.mkdir(process.env.SCREENSHOT_DIR, { recursive: true });
            await page.screenshot({ path: path.join(process.env.SCREENSHOT_DIR, name + ".png") });
        }
    }
});

test("registration reaches the real contract once and untrusted strings stay literal", async t => {
    const { page, wallet } = await openWallet(t);
    await page.goto(origin);
    await page.waitForFunction(() => !document.querySelector("#projectFields").disabled);
    const initial = await registry.getTotalProjects();
    for (const id of ["projectName", "projectLocation", "projectDescription"]) await page.locator("#" + id).fill(badText);
    await page.locator("#estimatedCredits").fill("-1");
    await page.locator("#submitBtn").click();
    assert.equal(wallet.sends, 0);
    await page.locator("#estimatedCredits").fill("42");
    await page.evaluate(() => {
        const form = document.querySelector("#projectForm");
        form.requestSubmit();
        form.requestSubmit();
    });
    await page.waitForFunction(() => document.querySelector("#txState").textContent.startsWith("Application confirmed"));
    await page.waitForSelector(".project");
    assert.equal(wallet.sends, 1);
    const stored = await registry.getProjectInfo(initial);
    assert.equal(stored.verificationDocuments, "");
    assert.equal(stored.status, 0);
    const card = page.locator(".project").first();
    assert.equal(await card.locator("h3").textContent(), badText);
    assert.equal(await card.locator("p").nth(0).textContent(), badText);
    assert.equal(await card.locator("p").nth(1).textContent(), badText);
    assert.equal(await card.locator("img").count(), 0);
    assert((await card.textContent()).includes("Pending"));
    assert.equal(await page.evaluate(() => window.injected), undefined);
    assert.equal(await page.locator("#totalProjects").textContent(), initial.add(1).toString());
    assert.equal(await page.locator("#protocolFee").textContent(), "2.5%");
});

test("a failed market read leaves registry usable; a failed registry read clears old data", async t => {
    const { page, wallet } = await openWallet(t);
    wallet.marketFails = true;
    await page.goto(origin);
    await page.waitForFunction(() => !document.querySelector("#refresh").disabled);
    assert((await page.locator("#marketState").textContent()).includes("unavailable"));
    assert(await page.locator("#submitBtn").isEnabled());
    assert.equal(await page.locator("#totalListings").textContent(), "—");
    wallet.registryFails = true;
    await page.locator("#refresh").click();
    await page.waitForFunction(() => document.querySelector("#recordsState").textContent.includes("unavailable"));
    assert.equal(await page.locator("#totalProjects").textContent(), "—");
    assert.equal(await page.locator(".project").count(), 0);
    assert(await page.locator("#submitBtn").isDisabled());
    wallet.marketFails = wallet.registryFails = false;
    await page.locator("#refresh").click();
    await page.waitForFunction(() => document.querySelector("#protocolFee").textContent === "2.5%");
    wallet.accounts = [];
    await page.evaluate(() => window.ethereum.emit("accountsChanged", []));
    assert.equal(await page.locator("#totalProjects").textContent(), "—");
    assert.equal(await page.locator("#protocolFee").textContent(), "—");
    assert(await page.locator("#submitBtn").isDisabled());
});

test("wrong chain stays disconnected after a refused switch", async t => {
    const { page, wallet } = await openWallet(t);
    wallet.chain = "0x1";
    await page.goto(origin);
    await page.waitForFunction(() => document.querySelector("#walletState").textContent.includes("Wrong network"));
    await page.locator("#connectBtn").click();
    await page.waitForFunction(() => document.querySelector("#walletState").textContent.includes("retry"));
    assert(await page.locator("#submitBtn").isDisabled());
    assert.equal(await page.locator("#totalProjects").textContent(), "—");
});

test("the project list pages newest first with eight reads per full page", async t => {
    for (let i = 0; i < 10; i++) await (await registry.registerProject("Page " + i, "Test", 0, "Fixture", 1, "")).wait();
    const { page } = await openWallet(t);
    await page.goto(origin);
    await page.waitForSelector(".project");
    assert.equal(await page.locator(".project").count(), 8);
    assert.equal(await page.locator(".project h3").first().textContent(), "Page 9");
    await page.locator("#older").click();
    await page.waitForFunction(() => document.querySelector(".project h3")?.textContent === "Page 1");
    assert(await page.locator("#older").isDisabled());
    await page.locator("#newer").click();
    await page.waitForFunction(() => document.querySelector(".project h3")?.textContent === "Page 9");
});
