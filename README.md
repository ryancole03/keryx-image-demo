# Keryx Image Generation Proof of Concept

This project explores image generation as a native Keryx workload. The proof of concept will run only on a private, isolated devnet and will not connect to Keryx mainnet or official testnet infrastructure.

The core experiment is zero-copy model reuse: an image model remains resident in GPU memory, Proof of Model (PoM) walks the same model tensors, image inference temporarily pauses PoM, and mining resumes without reloading or duplicating the model weights.

## Run The Demo

The supported demo uses one GPU-enabled Docker Compose stack on Ubuntu and Windows. It downloads and converts the official SD 1.5 model once, verifies both model hashes, creates disposable devnet keys, starts an isolated node, mines mature requester funds, starts offline Kubo, and opens the browser application. Completed images can be downloaded as PNG files.

The packaged workflow has been validated on Windows Docker Desktop and a clean Ubuntu 22.04 GPU VM.

Requirements:

- NVIDIA GPU with at least 8 GB VRAM and a CUDA 13-compatible driver
- Ubuntu with Docker Engine and NVIDIA Container Toolkit, or Windows with Docker Desktop, WSL2, and GPU support
- Docker Compose v2.30 or newer
- About 30 GB of free disk space for the build cache, images, source weights, and the cached Q8_0 model

Clone the demo and its pinned source forks:

```bash
git clone --recurse-submodules https://github.com/ryancole03/keryx-image-demo.git
cd keryx-image-demo
```

Ubuntu:

```bash
bash demo.sh doctor
bash demo.sh up
```

Windows PowerShell:

```powershell
.\demo.ps1 doctor
.\demo.ps1 up
```

Open `http://127.0.0.1:8080` if the launcher does not open it automatically. The launcher waits until the requester can fund a job. The first run builds the native CUDA components and prepares the model, so later starts are much faster.

Use `logs`, `status`, `down`, or `reset` with either launcher. `reset` removes disposable chain and wallet state but preserves the downloaded models.

All node, miner, backend, and Kubo interfaces remain inside one container on loopback. Docker publishes only the browser endpoint to host `127.0.0.1`.

## SD 1.5 License and Responsible Use

The SD 1.5 model weights use the CreativeML Open RAIL-M license. Commercial use and hosted generation are permitted without a model royalty or revenue threshold, but the license includes binding use restrictions. This model license is separate from the licenses covering stable-diffusion.cpp and the Keryx source code.

For a hosted or distributed service, the license requires operators to:

- Make the paragraph 5 use restrictions enforceable through the terms governing model access.
- Require users to comply with the prohibited uses in Attachment A.
- Provide the license and preserve applicable copyright, patent, trademark, and attribution notices when redistributing the model or derivatives.
- Mark modified model files. The Q8_0 GGUF produced by this demo is a quantized derivative of the source checkpoint.
- Treat users as responsible for generated outputs. The model provider claims no rights in outputs but does not guarantee that an output is lawful or non-infringing.

This repository downloads the source checkpoint and converts it locally rather than redistributing model weights. Any separately hosted Q8_0 artifact should include a copy of the license, retained notices, and a prominent quantization notice.

Attachment A prohibits uses including unlawful activity, exploitation or harm of minors, deliberately harmful false information, harmful disclosure of personal information, harassment or defamation, adverse automated legal decisions, discrimination, exploitation of vulnerable groups, and medical advice or interpretation. Read the complete list rather than relying on this summary.

This private-devnet PoC does not implement production content moderation. Before any public or commercial deployment:

- Require acceptance of an acceptable-use policy containing the license restrictions.
- Apply prompt checks at the service boundary before writing a request to the chain. Browser-only checks are bypassable.
- Check generated images on the miner before IPFS pinning or CID publication. Rejected results should be quarantined rather than published.
- Add rate limits, abuse reporting, operator audit records, and a documented review and appeal process.
- Record the model, moderation-policy version, and operator responsible for each response.
- Define miner obligations and violation handling separately from PoM. PoM proves model residency, not license compliance or semantic safety.

No classifier or blocklist can guarantee prevention. Controls should combine user terms, server-side enforcement, output review, and incident handling, with qualified legal review before deployment.

Sources:

- [CreativeML Open RAIL-M license](https://github.com/CompVis/stable-diffusion/blob/main/LICENSE)
- [Stable Diffusion v1.5 model card](https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5)
- [Stability AI public release and commercial-use statement](https://stability.ai/news-updates/stable-diffusion-public-release)

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
- [`docs/PHASE4_PROPOSAL.md`](docs/PHASE4_PROPOSAL.md): architecture, evidence, reproduction, and publication limits

## Upstream Sources

- https://github.com/Keryx-Labs/keryx-node
- https://github.com/Keryx-Labs/keryx-miner
- https://github.com/leejet/stable-diffusion.cpp
- https://keryx-labs.com/whitepaper
