# Phase 1 Evidence

Verified on native Windows x64 on 2026-07-30 with an RTX 3070 8 GiB.

## Model

- Source: official SD 1.5 `v1-5-pruned-emaonly.safetensors`
- Source SHA-256: `6ce0161689b3853acaa03779ec93eafe75a02f4ced659bee03f50797806fa2fa`
- Converted Q8_0 GGUF SHA-256: `9685394cae6ede69f28d1799ad54bd7c059a941eb3d3054802bf318422294745`
- Resident CUDA tensors: 1,130 totaling 1,882,960,396 bytes
- PoM tensors with complete 32-byte chunks: 1,127
- PoM chunk count: 58,842,511
- Resident PoM root: `49a167b499ca5631bd731e9717adbd41e8ce9a10c5b3222eb34d4289eda9fb2b`

The raw GGUF commitment is not suitable for resident PoM. Stable-diffusion.cpp transforms 356 tensor representations while loading, so the canonical private-devnet commitment is over deterministic name-sorted resident bytes.

## Zero Copy

The `stable-diffusion.dll` ABI exposes the model-owned resident tensor pointers. Miner startup:

1. Builds the host proof index from a captured resident-byte snapshot.
2. Uses stable-diffusion.cpp CUDA pointers directly for the PoM gather.
3. Samples 129 distributed chunks against the host index and fails closed on any mismatch.
4. Rejects raw-GGUF fallback for SD because its bytes differ from resident representations.

Runtime log proof:

```text
PoM SD zero-copy: 1127 tensors, N=58842511 chunks, byte gate passed
```

No second model allocation is made by the miner.

## Private Devnet

The isolated node listened only on loopback ports 32110, 32111, 33110, and 34110, with DNS seeding, UPnP, and outbound peers disabled. Devnet has a private SD tier and skips legacy PoW; mainnet and testnet retain proof-of-work validation.

The native CUDA worker walked the resident SD tensors and repeatedly submitted accepted blocks. A three-cycle stress run produced this sequence for each cycle:

```text
SD smoke: cycle N/3; PoM paused for resident image generation
SD smoke: cycle N/3 generated ...; resident pointers unchanged; PoM resumed
Block submitted successfully!
```

All three 512x512 images were written, each pointer check passed, and accepted block submission continued after cycle 3.

## Verification

- `cmake --build build-native --config Release -j 8`
- `tools\sd_zerocopy_spike.exe ...`: passed image generation with all 1,130 pointers unchanged
- Timed native spike: 3.08 seconds for model load plus a 4-step 512x512 generation
- GPU-wide VRAM observation: 2,608 MiB baseline, 6,381 MiB peak, 3,773 MiB delta
- Direct resident tensor allocation: 1,882,960,396 bytes (about 1,796 MiB)
- `cargo build --release -p keryx-miner`: passed
- `cargo build --release -p keryxcuda`: passed
- `cargo test --release -p keryx-miner --lib`: passed, 15 tests with 2 ignored
- `cargo test --release -p keryx-consensus-core`: passed
- `cargo build --release -p keryxd`: passed
- Three live PoM/image pause-resume cycles: passed

Known upstream-only test defects remain documented in `docs/NATIVE_BASELINE.md`.
