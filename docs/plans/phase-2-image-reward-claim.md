# Keryx Image PoC Phase 2: Image Transactions and Reward Claim

Add minimum image request/response payloads and deterministic claim-and-lease ownership so two miners do not perform the same payable inference.

Trace the existing escrow path completely before changing consensus. Prove competing-claim ordering, lease expiry, reassignment, exactly-once reward spending, requester refund, and reorg safety with automated tests and a two-miner private-devnet run.

## Status

Implementation, automated consensus coverage, a live payable image response, IPFS retrieval, and a live terminal refund are complete. Evidence is recorded in `docs/PHASE2_EVIDENCE.md`.

The plan remains active because the workstation has one RTX 3070 and cannot run two resident SD 1.5 miners concurrently. Complete the final contention proof on two GPUs or two hosts.
