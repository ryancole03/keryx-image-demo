# Native Windows Baseline

Verified on 2026-07-30 with an RTX 3070, Windows x64, MSVC 19.50.35729, CUDA 13.3, CUDA 12.4, CMake 4.1.0, Ninja 1.13.1, Rust 1.95.0, and Go 1.26.3.

## Pins

- keryx-node: `95c338fd6cae52271aeaea012d41febaf2159980` (v1.4.0)
- keryx-miner: `e48d7e6d11cfc12d565d54c55d4c3c527600ba39` (v0.4.2)
- stable-diffusion.cpp: `e92e86fb11b3028ac9edaf63d93709801d106b12`

All upstream worktrees remained unmodified.

## stable-diffusion.cpp

After loading the x64 MSVC environment with `vcvars64.bat`:

```powershell
cmake --fresh -S . -B build-native -G Ninja -DCMAKE_BUILD_TYPE=Release -DSD_CUDA=ON -DSD_BUILD_SHARED_LIBS=ON -DSD_WEBP=OFF -DSD_WEBM=OFF -DCMAKE_CUDA_ARCHITECTURES=86 -DCMAKE_CXX_FLAGS=/bigobj
cmake --build build-native --config Release -j 8
```

Passed:

- Built `build-native/bin/stable-diffusion.dll` and `sd-cli.exe`.
- `sd-cli.exe --help` reported commit `e92e86f`.
- `sd-cli.exe --list-devices` initialized CUDA and detected the RTX 3070 (compute capability 8.6, 8191 MiB).
- CTest configured no upstream tests (`Total Tests: 0`).

MSVC requires `/bigobj` for `src/stable-diffusion.cpp`.

## keryx-node

```powershell
cargo build --release
cargo test --workspace --release
```

Passed:

- Native release build.
- `keryxd.exe --version`: `keryxd 1.4.0`.
- `simpa.exe --version`: `simpa 1.4.0`.
- `stratum-bridge.exe --version`: `keryx-stratum-bridge 1.4.0`.

Upstream test defect:

- Workspace tests do not compile because `consensus/pow/src/matrix.rs:394` imports removed symbol `KERYX_MATRIX_SALT`; the compiler suggests `KERYX_MATRIX_SALT_V1`.

## keryx-miner

The miner hard-requires PTX for `sm_90,89,86,80,75,70,61`. CUDA 13.3 no longer compiles the oldest targets, so CUDA 12.4 nvcc is required for PTX generation. CUDA 12.4 needs NVIDIA's `-allow-unsupported-compiler` flag with MSVC 19.50. A one-line `nvcc-12.4.cmd` wrapper was used:

```bat
@"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin\nvcc.exe" -allow-unsupported-compiler %*
```

After loading `vcvars64.bat`, set `NVCC` to that wrapper, keep `CUDA_PATH` on CUDA 13.3 for current driver symbols, and build only the core package:

```powershell
$env:NVCC = 'path\to\nvcc-12.4.cmd'
$env:CUDA_PATH = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3'
$env:KERYX_LLAMA_SKIP = '1'
cargo build --release -p keryx-miner
cargo test --release -p keryx-miner
```

Passed:

- Native core release build.
- `keryx-miner.exe --version`: `keryx-miner 0.4.2`.
- Library tests: 15 passed, 2 ignored.
- Binary tests: 11 passed.

Upstream limitations:

- Two binary tests fail because current heavy-hash output differs from stale expected vectors: `test_heavy_hash` and `test_generate_matrix`.
- The Windows llama wrapper assumes a Visual Studio multi-config output at `src/Release/llama.lib`; Ninja emits `src/llama.lib`. LLM support is outside this image-only PoC, so `KERYX_LLAMA_SKIP=1` is intentional.
- Default workspace members include optional CUDA and OpenCL plugins. The OpenCL plugin needs an SDK not installed here. The CUDA plugin must use matching CUDA bindings and libraries. Neither plugin is needed for the core image-only baseline.

## Next

Start `keryxd` as an isolated private devnet, confirm no official peer connectivity, then connect the native core miner before changing inference or reward code.
