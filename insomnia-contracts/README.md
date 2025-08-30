````markdown
# 🔧 Insomnia Protocol – Foundry  

This repository contains the smart contracts for **Insomnia Protocol** deployed on **Somnia Testnet**.  
Contracts are written in Solidity and tested using **Foundry**.  

---

## 📦 Requirements  

- [Foundry](https://book.getfoundry.sh/getting-started/installation)  
- [Node.js](https://nodejs.org/) (optional, for scripts & integrations)  
- [pnpm](https://pnpm.io/) (if using JS tooling)  

Install Foundry:  
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
````

---

## ⚡ Usage

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Format

```bash
forge fmt
```

### Gas Snapshot

```bash
forge snapshot
```

### Deploy (example)

```bash
forge script script/Deploy.s.sol --rpc-url $SOMNIA_RPC --private-key $PRIVATE_KEY --broadcast
```

---

## 🌐 Network – Somnia Testnet

| Item               | Value                                                                  |
| ------------------ | ---------------------------------------------------------------------- |
| **Network Name**   | Somnia Testnet                                                         |
| **Chain ID**       | `50312`                                                                |
| **Symbol**         | STT                                                                    |
| **RPC URL**        | [https://dream-rpc.somnia.network/](https://dream-rpc.somnia.network/) |
| **Block Explorer** | [Shannon Explorer](https://shannon-explorer.somnia.network/)           |
| **Alt Explorer**   | [SocialScan](https://somnia-testnet.socialscan.io/)                    |
| **Faucet**         | [Somnia Testnet Faucet](https://testnet.somnia.network/)               |

Set RPC in your environment:

```bash
export SOMNIA_RPC="https://dream-rpc.somnia.network/"
```

---

## 📜 Deployed Contracts

### SomETH Vault (sEth)

* **Vault:** [`0x0fBCa75D8cD14dCf3AF4A45DCBF223aA1E7910F7`](https://shannon-explorer.somnia.network/address/0x0fBCa75D8cD14dCf3AF4A45DCBF223aA1E7910F7)
* **Router:** [`0xC39a9DdfE7f647DDb5a66b6eD64b1dc6B6766928`](https://shannon-explorer.somnia.network/address/0xC39a9DdfE7f647DDb5a66b6eD64b1dc6B6766928)
* **Adapter:** [`0x2fbd7a1c4864e917175ceD737D759E6bb88f4c65`](https://shannon-explorer.somnia.network/address/0x2fbd7a1c4864e917175ceD737D759E6bb88f4c65)

### SomPoints Boost Vault (sPoints)

* **Vault:** [`0x6261514Ee799666265c8c371bf21d0B0F6D85E76`](https://shannon-explorer.somnia.network/address/0x6261514Ee799666265c8c371bf21d0B0F6D85E76)
* **Router:** [`0xC61408c9966c15813e69F81388C4fddb7DB3069D`](https://shannon-explorer.somnia.network/address/0xC61408c9966c15813e69F81388C4fddb7DB3069D)
* **Adapter:** [`0x9096c1984Cd885Fed73148ec23ACe51E77d59EB4`](https://shannon-explorer.somnia.network/address/0x9096c1984Cd885Fed73148ec23ACe51E77d59EB4)

### SomUSD Stable Vault (sUSDC)

* **Vault:** [`0xD1edDafEb54071Bc78894B554Ad4bc66FA072678`](https://shannon-explorer.somnia.network/address/0xD1edDafEb54071Bc78894B554Ad4bc66FA072678)
* **Router:** [`0xD303929cA5D85e5b99AC301f7f4B431e448a8d8D`](https://shannon-explorer.somnia.network/address/0xD303929cA5D85e5b99AC301f7f4B431e448a8d8D)
* **Adapter:** [`0x3E339dD52694A94D60E829dF41d9768537aeBED2`](https://shannon-explorer.somnia.network/address/0x3E339dD52694A94D60E829dF41d9768537aeBED2)

### Points Controller

* **PointsController:** [`0x185427782C214f1455180bf6f1E47Cd52E9096d6`](https://shannon-explorer.somnia.network/address/0x185427782C214f1455180bf6f1E47Cd52E9096d6)

---

## 📜 License

This project is licensed under the **MIT License**.
