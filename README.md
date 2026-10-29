# Vericarbon Protocol

Vericarbon is an ERC-1155 prototype for issuing, transferring and retiring demonstration carbon credits. The contracts model project registration, account-based verification and fixed-price trading on Ethereum.

**The contracts do not verify that an environmental benefit occurred.** A wallet with the verifier role can mark a credit type as verified. The project does not currently connect to a carbon registry, meter, satellite service or independent environmental auditor.

## Code in this repository

| File | Implemented behaviour |
| --- | --- |
| [CarbonCredit.sol](src/CarbonCredit.sol) | Role-restricted credit-type minting, verifier-set approval flag, ERC-1155 transfers and holder-initiated retirement (burn). |
| [ProjectRegistry.sol](src/ProjectRegistry.sol) | Project registration, auditor approval/rejection and administrator status changes. |
| [Marketplace.sol](src/Marketplace.sol) | ETH-priced listings and purchases of credit types marked verified, with configurable fees and pause controls. |
| [frontend/](frontend/) | Static HTML, CSS and JavaScript interface using ethers.js for wallet and contract interactions. |
| [test/](test/) | Foundry test suites for the three contracts. |

The registry and credit contracts are separate. **Registering or approving a project is not currently enforced as a prerequisite for minting or verifying its credits.** A verified flag records an authorised on-chain decision, not a verified measurement or recognised offset.

The marketplace does not escrow credits when a listing is created. A purchase depends on the seller still owning the listed credits and maintaining the necessary transfer approval. Settlement in the current marketplace contract uses ETH, not stablecoins.

## Reproduce the contract checks

Install Foundry, then run:

```bash
git clone https://github.com/neo-t-maredi/vericarbon-protocol.git
cd vericarbon-protocol
git submodule update --init --recursive
forge build
forge test
```

These are commands to run, not a claim that tests were rerun for this documentation revision. Inspect the results before reporting a pass count or test coverage.

To inspect the web interface locally:

```bash
python3 -m http.server 8000 --bind 127.0.0.1 --directory frontend
```

Open `http://127.0.0.1:8000`. Wallet-dependent actions require a compatible browser wallet, the expected network and the appropriate contract roles. The frontend is a prototype, not a security-reviewed trading application.

## Testnet contract references

The earlier repository documentation recorded these Sepolia addresses. Their deployed bytecode, configuration and current state have **not** been independently revalidated during this README cleanup.

- [CarbonCredit](https://sepolia.etherscan.io/address/0x37A3A1B31bBaee86e8E307240BFB4d1e7f227a57)
- [ProjectRegistry](https://sepolia.etherscan.io/address/0x472fE102833fab6D06d8391fbe2a544Aa10257Cf)
- [Marketplace](https://sepolia.etherscan.io/address/0x1d53f45A37EB832E8C1e951dd1cA03355Ed40064)

## Trust boundaries and limitations

- No `VerificationOracle.sol`, Chainlink feed, IoT ingestion or satellite validation is implemented. External evidence must be evaluated off-chain by trusted parties.
- Administrators can assign roles and, in relevant contracts, pause operations or change marketplace parameters. This governance is not decentralised.
- The contract-level verified flag does not establish offset validity, additionality, exclusive ownership, registry status or freedom from double counting outside this system.
- The static frontend and smart contracts have not undergone an independent security audit. Do not use them to hold real assets or customer funds.
- This repository demonstrates software behaviour, not an issued environmental credit or an investment product.

## Current status

Research prototype. The core contracts and static interface are present; independent environmental verification, registry integration, production governance and security review are not.

This documentation describes the tracked source, not a production service.
