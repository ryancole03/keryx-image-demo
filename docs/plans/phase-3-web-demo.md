# Keryx Image PoC Phase 3: Minimal Web Demo

## Objective

Build a loopback-only funded-devnet backend and one responsive page that submits image prompts, tracks canonical request/claim/response/IPFS status, and renders validated committed images.

**Status:** Complete. See `docs/PHASE3_EVIDENCE.md`.

The product and technical contract is defined in `docs/PHASE3_SPEC.md`.

## Scope

- Extract the funded request builder for reuse by CLI and backend.
- Add one embedded Axum web application to `rothschild`.
- Track canonical lifecycle through existing high-verbosity virtual-chain RPC.
- Persist and recover tracked requests through a small NDJSON journal.
- Proxy only validated on-chain CIDs from fixed loopback IPFS.
- Present one responsive, dependency-free page with a fixed model/frame and bounded, truthful quality levels.
- Treat multiple images as independent funded requests with derived transaction-ID seeds.

## Product Acceptance

- Devnet and loopback boundaries are enforced.
- Keys and arbitrary node/IPFS access never reach the browser.
- Request submission, competing claim, payable response, rollback, refund, restart recovery, and IPFS validation are tested.
- One live browser request completes through rendered image.
- A two-image action proves independent request IDs, payment, seed, tracking, and output.
- Desktop, tablet, and mobile layouts plus loading, empty, error, stale, and completed states are verified.

## Verification

```powershell
cargo fmt --manifest-path "rothschild\Cargo.toml" -- --check
cargo check -p rothschild --bin ai-request --bin image-web
cargo test -p rothschild
cargo build --release -p rothschild --bin image-web
cargo test --release -p keryx-inference -p keryx-consensus-core -p keryx-consensus -p keryx-rpc-service -p rothschild
cargo build --release -p keryxd -p rothschild
```

Live and browser evidence is recorded in `docs/PHASE3_EVIDENCE.md`. Browser-wallet integration, official networks, generic IPFS proxying, unsupported generation controls, and production UI scope are excluded.
