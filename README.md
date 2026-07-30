# Keryx Image Generation Proof of Concept

This project explores image generation as a native Keryx workload. The proof of concept will run only on a private, isolated devnet and will not connect to Keryx mainnet or official testnet infrastructure.

The core experiment is zero-copy model reuse: an image model remains resident in GPU memory, Proof of Model (PoM) walks the same model tensors, image inference temporarily pauses PoM, and mining resumes without reloading or duplicating the model weights.

## Target Environment

- Windows with WSL2 `Ubuntu-24.04`
- NVIDIA GeForce RTX 3070 with 8 GB VRAM (SM86)
- 31 GB WSL system memory and 8 GB swap
- NVIDIA driver visible in WSL
- CUDA toolkit 12.0
- CUDA 12 `libcudart` and `libcublas`

## Initial Scope

- Private Keryx devnet with unique local configuration and no official peers
- `stable-diffusion.cpp`-based shared library mirroring Keryx's llama.cpp integration
- SD 1.5 GGUF as the first 8 GB-safe model
- PoM over the inference engine's resident image-model tensors
- Pause PoM during image generation and resume without model reload
- One image and one miner reward per request
- Claim-and-lease experiment to prevent duplicate inference
- Minimal web interface after the engine and reward flow work

## Documents

- [`docs/RESEARCH.md`](docs/RESEARCH.md): verified whitepaper, source-code, backend, and environment findings
- [`docs/SPEC.md`](docs/SPEC.md): product and technical specification
- [`docs/PLAN.md`](docs/PLAN.md): phased implementation and verification plan

## Upstream Sources

- https://github.com/Keryx-Labs/keryx-node
- https://github.com/Keryx-Labs/keryx-miner
- https://github.com/leejet/stable-diffusion.cpp
- https://keryx-labs.com/whitepaper
