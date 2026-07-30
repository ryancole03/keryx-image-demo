# Keryx Image PoC Phase 1: Private Devnet and Zero-Copy Backend

Establish an isolated devnet, verify clean upstream builds, wrap stable-diffusion.cpp as `libkeryx-sd.so`, and prove that PoM and image inference share one resident SD 1.5 GGUF allocation on the RTX 3070.

Do not begin consensus reward changes or web UI work until the model remains loaded, tensor bytes pass the compatibility gate, image generation pauses PoM safely, and PoM resumes over unchanged tensor pointers.

Verification must include upstream tests, CUDA tensor sampling, repeated PoM/image stress cycles, and captured VRAM/latency observations.
