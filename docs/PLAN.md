# Implementation Plan

The phases are ordered so that protocol and UI work do not hide a failed zero-copy GPU premise.

## Phase 1: Private Devnet and Zero-Copy Backend Spike

### Work

- Clone pinned upstream revisions of `keryx-node`, `keryx-miner`, and `stable-diffusion.cpp`.
- Record upstream commit hashes and licenses.
- Configure a private devnet with unique local identity, data directories, ports, and no official peers.
- Build the unmodified node and miner first.
- Build stable-diffusion.cpp as a CUDA shared library.
- Add the minimal `libkeryx-sd.so` ABI and Rust loader.
- Load one SD 1.5 GGUF persistently.
- Expose canonical tensor metadata and device pointers.
- Reuse Keryx's resident-tensor PoM byte gate and gather path.
- Pause PoM, generate one image, and resume PoM without reload.

### Acceptance

- Private devnet produces blocks from genesis without external peers.
- Baseline upstream builds pass before modifications.
- Image generation succeeds on the RTX 3070.
- PoM and inference use one resident model allocation.
- Tensor pointers remain stable across generation.
- CUDA synchronization produces no race, illegal access, or out-of-memory error.
- VRAM use, generation latency, pause duration, and resume behavior are recorded.

### Verification

- Upstream Rust test suites appropriate to changed crates
- stable-diffusion.cpp build/tests applicable to the pinned revision
- CUDA tensor-byte sampling check
- Repeated PoM -> image -> PoM stress loop
- `nvidia-smi` memory observations captured before load, during PoM, during inference, and after resume

## Phase 2: Image Transactions and Reward Ownership

### Work

- Define the minimum image request and response payloads.
- Trace current request escrow creation, CSV lock, response handling, and claim spending completely.
- Design deterministic claim-and-lease consensus behavior.
- Bind response authorization and reward release to the active claimant.
- Add request expiry and refund behavior.
- Pin image results to IPFS and validate result size/type at the service boundary.
- Exercise the flow with two miners.

### Acceptance

- Exactly one active claim exists per request at any canonical chain state.
- A second miner does not duplicate payable inference while a valid lease exists.
- An expired claimant cannot receive the reward.
- A replacement miner can complete after lease expiry.
- Exactly one reward spend succeeds.
- Unserved requests refund deterministically.
- Reorg and competing-block tests do not produce divergent claim ownership.

### Verification

- Unit tests for payload encoding/decoding and claim state transitions
- Consensus tests for competing claims, expiry boundaries, reorgs, duplicate responses, and reward spends
- Two-miner private-devnet integration run
- IPFS unavailable and malformed-image failure runs

## Phase 3: Minimal Web Demonstration

### Work

- Add a small backend using a funded devnet wallet.
- Expose submit, status, and result endpoints.
- Build one responsive page for prompt submission and lifecycle display.
- Show request, claim, generation, confirmation, and IPFS status.
- Support multiple images by creating independent requests with derived seeds.

### Acceptance

- A user can generate and view an image without CLI interaction.
- Failed and expired requests display actionable status.
- Multiple-image requests pay each completed image independently.
- No mainnet or official testnet endpoint is configurable in the demo build.

### Verification

- Backend API tests
- Browser lifecycle test against the local devnet
- Desktop and mobile layout check
- Request retry and page-refresh recovery check

## Phase 4: Proposal Evidence and Closeout

Status: Complete (2026-08-01)

### Work

- Record architecture diagrams and protocol deltas.
- Record reproducible setup and launch commands.
- Provide one-command Docker launchers for Ubuntu and Windows.
- Verify model download, conversion, hashes, GPU access, service health, and loopback isolation automatically.
- Capture GPU memory, latency, throughput, mining pause, and reward evidence.
- Document limitations and unresolved verification questions.
- Prepare a concise upstream proposal with links to the working fork and demonstration.

### Acceptance

- A new developer can reproduce the devnet and demonstration from documentation.
- Fresh Ubuntu and Windows machines can reach the browser demo with one supported command after Docker GPU setup.
- Startup failures identify the missing prerequisite instead of leaving a partial stack running.
- All changed-code tests pass with commands and results recorded.
- Product scope, maintainability risks, and remaining work are explicit.
- No phase is marked complete while required product behavior remains unverified.

## Possible Future Roadmap

- Explore optional stablecoin-denominated service payments after the image protocol is proven. Miner payments, development funding, token buybacks, and protocol-owned liquidity require separate economic modeling and regulatory review.

## Immediate Next Steps

1. Ask Keryx developers to run the public demo and record any setup friction.
2. Keep stablecoin settlement and token economics as separate future research.
