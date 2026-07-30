# Phase 2 Image Reward Claim Evidence

## Scope

Phase 2 adds a private-devnet-only, UTXO-backed claim-and-lease flow for one image request, one active miner, and one payable response. Mainnet and testnet reject the new claim subnetwork contextually. No code was pushed or deployed.

## Protocol Evidence

- `AiClaim` uses subnetwork ID `0x06` and binds the claimant signature to the request transaction ID and spent outpoint.
- A request state has a fixed 1,000-DAA requester refund timeout.
- A lease permits claimant payout, reassignment after 100 DAA blocks, and requester refund at the terminal deadline.
- Competing claims spend the same state UTXO, so canonical UTXO ordering selects one owner.
- Responses spend the active lease and preserve exactly-once reward semantics through normal UTXO single-spend rules.
- Request identity uses the transaction ID, so identical payloads remain independent.
- Miner ownership follows virtual selected-chain additions/removals and retries rejected or rolled-back claims.

## Automated Verification

Passed:

```text
cargo test --release -p keryx-inference
cargo test --release -p keryx-consensus-core
cargo test --release -p keryx-consensus
cargo check -p rothschild --bin ai-request
cargo build --release -p keryxd
cargo test --release -p keryx-inference                 # miner workspace
cargo test --release -p keryx-miner --lib               # 15 passed, 2 ignored
cargo build --release -p keryx-miner
```

The real txscript test `ai_state_scripts_execute_csv_and_selector_branches` proves immediate claim, refund rejection before DAA 1,000 and acceptance at DAA 1,000, and reassignment rejection before DAA 100 and acceptance at DAA 100.

The complete miner package still has two documented upstream heavy-hash vector failures; the Phase 2 library and crypto tests pass.

## Live Private-Devnet Proof

The node ran only with `--devnet`, loopback listeners, zero inbound/outbound peers, DNS seeding disabled, and UPnP disabled. The miner connected only to `127.0.0.1:32110`.

Payable image flow:

```text
request tx:  70ada9e907a72be68b2a283f53ff73d58ca13137fd985d2690a5003d5bc727f6
CID:         QmaWifEyoWmnUWCefFkRcT9KjVtePxzpEsrr57ARYSa9Ft
response:    4878e6d5d171823dfbd958a05f870c6047d8a0b664108b76028d4887c33f1603
```

Observed sequence:

```text
OPoI: claiming image request=70ada9e907a72be6...
OPoI: confirmed AI lease request=70ada9e907a72be6...
OPoI: inference complete, request_hash=70ada9e907a72be6
OPoI: uploading response CID=QmaWifEyoWmnUWCefFkRcT9KjVtePxzpEsrr57ARYSa9Ft
OPoI: registered AiResponse response_hash=4878e6d5d171823dfbd958a05f870c6047d8a0b664108b76028d4887c33f1603
```

`ipfs cat` returned an exact 786,447-byte binary PPM: a 15-byte `P6\n512 512\n255\n` header plus 512 x 512 x 3 RGB bytes.

Terminal refund flow:

```text
unserved request: 8e13b2296e5ffda128224041bc031261ae3ab2c1fbd9b787a545b60b9a8b69b0
refund tx:       bff8e576dbf19558a15146cf92b59e1ccb1248dc8cc979f9214a1173c967d295
```

The requester refund was rejected before maturity and accepted after the fixed 1,000-DAA timeout.

## Two-Miner Contention Proof

The final contention run used an isolated Vast Ubuntu 24.04 host with one RTX 5090 (32 GB), CUDA 13.1, a loopback-only devnet node, offline loopback IPFS, and exactly two simultaneous claim-capable miners with distinct disposable claimant keys. The model SHA-256 matched Phase 1 (`9685394cae6ede69f28d1799ad54bd7c059a941eb3d3054802bf318422294745`); the generated resident snapshot contained 1,130 tensors, 1,882,960,352 bytes, and 58,842,511 chunks.

```text
request tx: 497f2da4f7327df3f344cefb5a27364dfa4f822d263cb4cdf67458f2460218b7
winner:     miner 1
CID:        QmSUnCywaah3WWPj2UGuGYQccSnNhfBy8cPZGSEKGgDr6N
response:   1bcfc97ffdc43eae5246bfd61831ba02dfcd171d12d6a13ed8d67733fec8ad6a
```

After another 60 seconds of heavy virtual-chain churn, miner 1 had observed 1,062 winning lease confirmations but performed exactly one inference and one cached response replay. Miner 2 made 1,082 competing claim attempts but observed no winning lease and performed zero inference. This proves canonical single-owner selection and one expensive inference per request across lease and request-block reorgs.

Remote `ipfs cat` returned exactly 786,447 bytes with the expected `P6\n512 512\n255\n` header. The node registered the payable `AiResponse`. All remote miners, node, and IPFS daemon were then stopped cleanly.
