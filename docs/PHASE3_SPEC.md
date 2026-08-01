# Phase 3: Minimal Web Demo Specification

## Goal

Provide one responsive local page that funds an image request, shows its canonical request/claim/response lifecycle, retrieves the committed IPFS image, and renders it without exposing the requester key or node/IPFS APIs to the browser.

## Product Scope

- Run only against a loopback private devnet.
- Accept a public image prompt and an image count from 1 to 4.
- Create one independently funded request per image.
- Show each request transaction ID, derived seed, fixed model settings, lifecycle status, CID, and actionable errors.
- Restore tracked requests after browser or backend restart.
- Fetch only the CID committed by a canonical payable response.
- Validate the CID digest, declared response length, PPM header, dimensions, and one MiB size ceiling before returning image bytes.
- Render the validated 512x512 PPM through a browser canvas.

## Non-Goals

- Mainnet or official testnet support.
- Browser wallet integration.
- Generic IPFS proxying.
- Miner progress percentages or claims that GPU execution is directly observable on-chain.
- Arbitrary model, negative prompt, seed, dimensions, sampler, guidance, or deadline controls. Diffusion steps are limited to the studied 12, 20, 30, and 40-step quality levels.
- A production marketplace, account system, database, or public deployment.

## Design Read

Reading this as a local developer demo for technical reviewers, with an evidence-first industrial interface: one asymmetric workspace, a large image canvas, a compact chain timeline, high contrast, one restrained signal accent, responsive single-column mobile layout, and no external assets or build tool.

## Architecture

Add an `image-web` binary to the existing `rothschild` package.

- Axum handles correct HTTP parsing, body limits, routing, and graceful shutdown.
- The existing funded request/refund logic moves into `rothschild/src/lib.rs` so the CLI and web backend share one implementation.
- The backend owns the requester key file, Keryx gRPC connection, UTXO submission lock, canonical-chain reducer, and fixed loopback Kubo endpoint.
- A small append-only NDJSON journal stores submitted request IDs, pre-submit chain anchors, and canonical transitions. Startup replays the journal and reconciles from the saved cursor.
- Existing `GetVirtualChainFromBlockV2` high-verbosity polling is authoritative. Block-added or mempool observations are labelled pending only. Nonstandard AI scripts return no derived address instead of aborting RPC conversion.
- The page is one embedded HTML/CSS/JavaScript file. It uses same-origin JSON APIs and draws validated PPM bytes to canvas.

## API

```text
GET  /
POST /api/requests
GET  /api/requests/{request_txid}
GET  /api/requests/{request_txid}/result
```

`POST /api/requests` accepts a prompt, count, and one studied quality level (`quality_steps`: 12, 20, 30, or 40). Reward and priority fee are backend configuration, not browser-controlled payment fields. Count creates separate transactions with independently derived transaction-ID seeds.

Lifecycle values are `submitted`, `request_pending`, `request_confirmed`, `claim_pending`, `lease_stabilizing`, `lease_active`, `response_pending`, `response_confirmed`, `image_available`, `refund_available`, `refunded`, `stale`, and `failed`. The UI may describe stable lease eligibility as generation expected, but must not claim exact GPU progress.

## Security Boundary

- Refuse startup unless RPC reports `Devnet`.
- Refuse non-loopback listen addresses.
- Read the private key from a file; never return it or store it in browser state.
- Keep node and IPFS URLs fixed by backend configuration.
- Same-origin only; no CORS.
- Limit request bodies and prompts to protocol bounds.
- Serialize funded submissions and reserve selected outpoints until reconciliation.
- Use `textContent` for prompt and chain values.
- Serve restrictive content and cache headers, including `X-Content-Type-Options: nosniff`.

## Files

- `upstream/keryx-node/rothschild/src/lib.rs`
- `upstream/keryx-node/rothschild/src/bin/ai-request.rs`
- `upstream/keryx-node/rothschild/src/bin/image-web.rs`
- `upstream/keryx-node/rothschild/static/index.html`
- `upstream/keryx-node/rothschild/Cargo.toml`
- `docs/PHASE3_EVIDENCE.md`
- `docs/plans/phase-3-web-demo.md`

## Maintainability Risks

- Canonical-chain rollback is the main correctness risk. Keep it in a pure idempotent reducer with block-scoped reversible events and focused tests.
- Funded concurrent submissions can double-select UTXOs. One backend mutex owns selection, reservation, signing, and submission.
- The response field names retain legacy text semantics. The image path treats `request_hash` as request transaction ID and `response_length` as byte length, matching Phase 2 consensus behavior.
- PPM browser support is inconsistent. Validate the original bytes and render through canvas rather than adding image conversion machinery.
- Keep the frontend as one file until product requirements justify a frontend toolchain.

## Acceptance Criteria

1. The server refuses non-devnet RPC and non-loopback binding.
2. One prompt submits one funded request without exposing the key.
3. Count 2 submits two independent requests, payments, transaction IDs, and derived seeds.
4. Canonical request, claim/lease, payable response, rollback, refund, stale, and error states reduce deterministically.
5. Refresh and backend restart recover submitted requests.
6. Result retrieval accepts only a tracked canonical response and rejects arbitrary CID, malformed CID, digest mismatch, length mismatch, oversized data, and malformed PPM.
7. The page works at 390x844, 768x1024, and 1280x800; supports keyboard use, visible focus, reduced motion, and system light/dark preferences.
8. A funded private-devnet run completes from browser submission to rendered image, then a two-image action proves independent requests and rewards.

## Verification

From `upstream/keryx-node`:

```powershell
cargo fmt --manifest-path "rothschild\Cargo.toml" -- --check
cargo check -p rothschild --bin ai-request --bin image-web
cargo test -p rothschild
cargo build --release -p rothschild --bin image-web
```

Protocol regressions:

```powershell
cargo test --release -p keryx-inference
cargo test --release -p keryx-consensus-core
cargo test --release -p keryx-consensus
cargo build --release -p keryxd
```

Browser verification uses Playwright at the three target viewports and checks empty, submitting, active, completed, stale, and error states. Live evidence records request IDs, CIDs, response IDs, image byte validation, restart recovery, and independent two-image payment.
