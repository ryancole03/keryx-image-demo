# Keryx Image PoC Research Record

## Product Direction

The initial discussion considered chat, asynchronous jobs, embedding models, model specialization, batch inference, and replicated inference. The selected direction is image generation only.

Image generation fits Keryx better than interactive chat because it is naturally asynchronous, does not require token streaming, accepts compact prompts, produces content-addressed artifacts suitable for IPFS, and can expose meaningful variation across miners. Embeddings are intentionally excluded because they are not required unless a later product adds semantic search, similarity detection, or a vector index.

A multi-image user action should initially create multiple independent single-image requests with distinct seeds. Every completed request pays its miner. There should be no winner-takes-all image contest because preference is subjective and unpaid losing work would discourage miners.

## Whitepaper Findings

The reviewed official document was `Keryx: A Decentralized Protocol for Verifiable AI Inference`, version 1.3, July 2026.

Relevant protocol behavior:

- Keryx uses a 10-BPS GHOSTDAG BlockDAG.
- `AiRequest` includes a 32-byte model ID, maximum token count, inference reward, priority fee, and a UTF-8 prompt within a 4,096-byte payload limit.
- `AiResponse` is a compact record containing the request hash, challenge-window end, IPFS CID, and response length.
- Prompt payloads are public and result content is public through IPFS today.
- Proof of Model proves possession of exact registered model weights.
- Each GPU currently serves one registered model tier.
- PoM does not prove that a user-visible inference result is correct.
- The current OPoI challenge executes a deterministic fixed-point surrogate computation rather than validating the generated LLM text.
- Slashing is suspended while deterministic settlement and content commitments are being repaired.

Image generation therefore cannot initially claim cryptographically verified output. The PoC proves model residency, execution flow, result publication, and payment coordination.

## Current Miner Reward Behavior

Inspection of the public `keryx-miner` implementation found no network-wide request claim or lease.

Observed flow:

1. Every miner scans block templates and confirmed blocks for `AiRequest` transactions.
2. A miner queues every unseen request supported by its locally ready model.
3. `ai_seen_prefixes` and `in_progress` prevent duplicate work only within that miner.
4. After inference and IPFS upload, the miner broadcasts an `AiResponse` with no transaction inputs or outputs.
5. The miner then tracks the original request's `output[1]` as inference escrow.
6. Multiple miners may therefore compute the same request and later contend over one single-spend reward UTXO.

Publishing the first response does not appear to atomically reserve or transfer the reward. The eventual winner is determined during later escrow claiming, not cleanly by first completion. This is both wasted GPU work and an ambiguous reward assignment.

Relevant source locations:

- `keryx-miner/src/client/grpc.rs`
- `keryx-miner/src/escrow.rs`
- `keryx-miner/src/inference.rs`
- `keryx-node/inference/src/ai_payload.rs`
- `keryx-node/bridge/src/opoi.rs`

## Existing Zero-Copy Llama Architecture

Keryx already implements the desired model-residency pattern for llama models.

- `libkeryx-llama.so` owns the inference-ready model allocation.
- `PomGpuMiner::load_llama` gathers directly over resident device tensor pointers.
- Tensor pointers are ordered canonically by name.
- A byte-compatibility gate samples resident tensors against canonical GGUF bytes and refuses mining when runtime layout or conversion is incompatible.
- Host-resident tensors are uploaded separately when required.
- PoM mining pauses during inference.
- If the requested GGUF is already active, inference runs without unloading the model.
- PoM resumes over the unchanged resident tensor pointers afterward.
- `pom_gpu::uninstall` exists for actual model swaps, not same-model inference.

Relevant source locations:

- `keryx-miner/src/pom_gpu.rs`
- `keryx-miner/src/llama_engine.rs`
- `keryx-miner/src/slm.rs`
- `keryx-miner/src/client/grpc.rs`
- `keryx-miner/cuda/keryx.cu`

The image integration should copy this architecture rather than introducing a second model allocation or an external ComfyUI process.

## Image Backend Selection

`leejet/stable-diffusion.cpp` is the selected backend. Building a new image engine is unnecessary.

Verified properties:

- MIT licensed and actively maintained
- Pure C/C++ using GGML
- CUDA support on Linux and Windows
- GGUF, safetensors, and checkpoint support
- SD 1.x/2.x, SDXL/Turbo, SD3/3.5, FLUX, Qwen Image, and additional image/video architectures
- Persistent public C API using `new_sd_ctx`, `generate_image`, and `free_sd_ctx`
- Shared-library build through `SD_BUILD_SHARED_LIBS`
- CUDA build through `SD_CUDA`
- Quantization, samplers, flash attention, memory controls, and LoRA support

The public API does not expose resident tensor enumeration or CUDA device pointers. Internally, image model runners maintain named GGML parameter tensors and expose `get_param_tensors(std::map<std::string, ggml_tensor*>&)`. A small Keryx-maintained fork or internal wrapper can expose the same ABI shape used by `libkeryx-llama.so`:

```text
keryx_sd_abi
keryx_sd_load
keryx_sd_tensor_count
keryx_sd_tensor_info
keryx_sd_generate
keryx_sd_free
```

The wrapper must expose canonical tensor names, byte sizes, memory locations, and device pointers. Keryx must retain its byte-compatibility gate because GGML backends may cast, quantize, or repack weights.

## Private Devnet Support

The node already supports the correct foundation:

- `--devnet`
- `--simnet`
- `--testnet`
- `--enable-unsynced-mining` for starting a network from genesis
- `--override-dag-params-file`, restricted to devnet

The PoC should not introduce another network type. It should use built-in devnet support with an isolated data directory, no DNS seeds or official peers, explicit local peer configuration, dedicated ports, and unique devnet/genesis parameters where supported. Official mainnet and testnet must never be used for the experiment.

## Environment Verification

Verified on July 30, 2026:

- WSL default distribution: `Ubuntu-24.04`, WSL version 2
- GPU: NVIDIA GeForce RTX 3070, 8,192 MiB
- Architecture: SM86, covered by Keryx's existing PoM PTX
- Windows NVIDIA driver: 591.44
- WSL NVIDIA driver: 590.44.01
- Driver CUDA capability: 13.1
- Installed `nvcc`: CUDA toolkit 12.0, V12.0.140
- `libcudart.so.12` available
- `libcublas.so.12` available
- WSL memory: 31 GiB total, approximately 30 GiB available during inspection
- WSL swap: 8 GiB

The CUDA driver can run binaries built with the installed CUDA 12 toolkit. Keryx's required CUDA 12 runtime libraries are present.

## Open Technical Questions

- Which complete set of stable-diffusion.cpp tensors must form the PoM canonical working set: diffusion backbone only, or diffusion model plus text encoders and VAE?
- Does the selected GGUF remain byte-compatible after GGML backend loading, or are some tensors converted/repacked?
- Can SD 1.5 inference activations coexist with all PoM metadata and desktop VRAM use on this 8 GB card?
- What minimum image payload fields belong in consensus versus a canonical parameter manifest?
- How should claim ownership bind to the reward UTXO without creating nondeterministic settlement?
- What challenge can prove result availability and basic validity without falsely claiming proof of semantic correctness?
- What retention period and storage fee should apply to image CIDs?
