# Keryx Image PoC Phase 4: Proposal Evidence and Closeout

Capture reproducible setup commands, architecture and protocol changes, passing verification commands, VRAM use, latency, mining pause behavior, reward behavior, limitations, and maintainability risks.

Prepare a concise upstream proposal backed by the working private-devnet demonstration. Keep the overall project active if any required product behavior remains incomplete or unverified.

## Status

Proposal draft and local evidence closeout are recorded in `docs/PHASE4_PROPOSAL.md`.

The developer demo package uses one Docker Compose runtime with thin Ubuntu and Windows launchers. GPU runs passed on both platforms, and a clean Ubuntu run passed automatic model preparation, funding maturity, image generation, restart recovery, and loopback-only exposure.

Phase 4 completed on 2026-08-01. The Phase 3 work is committed to public user-owned forks, the demo pins exact source revisions as submodules, and a fresh public recursive clone reached Docker healthy status and returned the browser URL. The clean Ubuntu run verified the recorded model download, conversion, and hash checks. Official origin remotes remain read-only.
