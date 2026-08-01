# Phase 3 Evidence: Local Web Demo

## Result

Phase 3 is complete on the isolated private devnet. One loopback-only web application funded two independent image requests, recovered them from an NDJSON journal, followed canonical claim and response transitions, retrieved their committed IPFS objects, validated the UnixFS root blocks and PPM payloads, and rendered both images in the browser.

No official-network node, public listener, browser wallet, arbitrary IPFS proxy, or browser-visible private key was used.

## Implementation

- `rothschild/src/lib.rs` contains reusable funded request and refund construction.
- `rothschild/src/bin/ai-request.rs` remains a thin command-line client.
- `rothschild/src/bin/image-web.rs` provides the Axum API, canonical-chain reducer, NDJSON recovery, serialized funding, and validated result endpoint.
- Signed request transactions are journaled and `sync_data`-flushed before broadcast. Restart replay resubmits prepared transactions, while canonical polling continues after ambiguous submission acknowledgements.
- `rothschild/static/index.html` is a dependency-free responsive client with no external assets or frontend build tooling.
- Multiple images reserve disjoint mature UTXOs before submission and create one transaction, payment, and derived seed per image.
- Canonical state comes from `GetVirtualChainFromBlockV2` acceptance data. Reverted blocks are removed before replay.
- Nonstandard AI state scripts return a null verbose address instead of aborting RPC conversion.
- CIDv0 integrity is checked against the raw UnixFS root block from Kubo. Reconstructed file bytes are independently checked against the committed response length and exact `P6\n512 512\n255\n` 512x512 RGB format.
- Derived `u64` seeds are serialized as decimal strings so browsers cannot lose integer precision. Existing numeric journal records remain readable.
- Canonical polling merges updates into live request state, so a submission concurrent with an RPC page cannot be overwritten. Transient result-fetch failures remain retryable until validated image bytes are loaded.

## Live Two-Image Browser Proof

Environment:

- Vast Ubuntu 24.04 host with RTX 5090
- isolated `keryxd --devnet` on loopback with zero peers, DNS seed disabled, and UPnP disabled
- Kubo offline with loopback-only API and no swarm/bootstrap/mDNS discovery
- backend, node RPC, and Kubo API bound to loopback
- exact SD 1.5 Q8_0 model SHA-256 `9685394cae6ede69f28d1799ad54bd7c059a941eb3d3054802bf318422294745`

One browser action requested two images for the public prompt `Two small sailboats crossing a calm copper sea at sunrise`.

Request one:

- transaction: `450927706dfd70112b8965b60356fa83f3bcb6bb9fa8ada88fbc3d1e087e2206`
- derived seed: `1256782942511237445`
- claim: `b25a7ff89914cd280d4269ba39a86b55efd7d220e2791950c482d960d36e793f`
- payable response: `8d98044d5eada15ce6be6532c554dfb13ae1517bb36a775fe4434ea9fbcba91a`
- CID: `QmR8Kb6Xzp7oyA1Lby5r1Mzm1KVNnDGt5ZDw7Uxjvc4Neu`
- validated result: 786,447 bytes

Request two:

- transaction: `d1f8f8f8772adb8bb904f8451d1eaee2aeffda1b05e442c6163070fdccff69f8`
- derived seed: `10077695285938157777`
- claim: `8a625d96a20e9d06c0bd798395136338484481e29263e173906a92cf357392f`
- payable response: `3e6fd7889ec547806e08534fc23dad06bac68c32bfb1dca6838a4820ed5976c`
- CID: `QmZiWygVMYZoUzqx3J5WQ7ocj5jZECKtpbEccbe3XGzfoc`
- validated result: 786,447 bytes

The backend was restarted from the persisted journal. Both requests recovered their canonical claim, response, CID, and final `image_available` state. Both `/api/requests/{txid}/result` endpoints returned the exact committed PPM length.

## Browser Evidence

Playwright verified:

- desktop 1280x800, tablet 768x1024, and mobile 390x844 layouts
- no horizontal overflow at any required viewport
- completed image canvas and canonical chain evidence
- exact 64-bit seed display without JavaScript rounding
- zero browser console errors or warnings
- keyboard-focus styling, semantic regions, labelled controls, live status text, and reduced-motion handling

The final visual system follows `keryx-labs.com`: near-black `#070a08`, emerald `#00e533` and `#30ff67`, sage/ink text, 56px low-opacity grid lines, mono protocol labels, square technical panels, restrained emerald glow, and no external assets.

## Quality Study And Live Proof

The original demo forced four diffusion steps even though stable-diffusion.cpp defaults to 20. A controlled RTX 5090 study generated 144 images from eight prompt categories, three fixed seeds, and six step counts (4, 8, 12, 20, 30, 40). The selected product levels are documented in `docs/SD_QUALITY_GUIDE.md`:

- Standard: 12 steps, the hard floor for consistently useful output
- Balanced: 20 steps, the general default
- Detailed: 30 steps, a selective detail-focused mode
- Max: 40 steps, an experimental ceiling rather than a promise of improvement

The production miner maps legacy zero-step requests to the 12-step floor, consensus prices them in the same surcharge tier, and the miner clamps every SD request to 12-40. Old journal entries without quality metadata display `Legacy / unrecorded`; new web requests default explicitly to 20. The web API accepts only the four studied values. Existing `max_tokens` payload storage carries the chosen step count without a wire-format change, and all four values remain in the same current reward-surcharge tier.

A live browser request selected Detailed / 30 steps and completed end to end:

- request: `daf6e57116f417c6b8f9f6ee2a4b3df4d38ad73b9276cdcb905ee54601b7ae16`
- derived seed: `14274145921211430618`
- claim: `6b6a99c8af24554882401bd74104e78401284a7daf7a0269ec627e592a1039c4`
- payable response: `325af247773c468534633d0c202a876248677a9345bfafdc09aa292452338586`
- CID: `QmVYCSh6ufEvVD37Dfeptde6sNSGhFGJGm6Nx9fXxxghCc`
- browser status: `image_available`, rendered canvas, exact `30 steps / Detailed` evidence
- restart check: request and image recovered with zero browser console errors or warnings

## Verification

Passed:

```powershell
cargo test --release -p keryx-inference -p keryx-consensus-core -p keryx-consensus -p keryx-rpc-service -p rothschild
cargo build --release -p keryxd -p rothschild
```

The focused Rothschild suite also passed after each backend, journal, UnixFS, funding-reservation, and browser-data correction.

## Boundaries

- Private devnet only.
- The browser receives no key material and no raw node or Kubo endpoint.
- The result route serves only tracked canonical CIDs after root-block, response-length, size, header, dimension, and payload validation.
- Result bytes are re-imported through Kubo in `only-hash` mode and must reproduce the committed CID. Kubo remains a fixed loopback dependency under the trusted local-backend threat model.
- Any local process able to reach the loopback POST endpoint can spend the configured requester funds; the demo assumes a trusted single-user machine and is not a public service.
- Exact miner generation progress is not claimed because the protocol does not expose it.
- SD settings remain fixed at SD 1.5, 512x512, and transaction-derived seed. Quality selects one studied step count: 12, 20, 30, or 40.
- Browser wallet, accounts, marketplace behavior, unsupported generation controls, and public deployment remain out of scope.
