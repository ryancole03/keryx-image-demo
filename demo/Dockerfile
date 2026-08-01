# syntax=docker/dockerfile:1.7

ARG CUDA_VERSION=13.0.1
ARG MINER_CUDA_VERSION=12.4.1
ARG KUBO_VERSION=v0.36.0

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu24.04 AS build

ARG RUST_VERSION=1.95.0

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential ca-certificates clang cmake curl git libssl-dev ninja-build pkg-config protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain ${RUST_VERSION}

ENV PATH=/root/.cargo/bin:${PATH}

COPY upstream/stable-diffusion.cpp /src/stable-diffusion.cpp
RUN cmake -S /src/stable-diffusion.cpp -B /build/stable-diffusion -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DSD_CUDA=ON \
        -DSD_BUILD_SHARED_LIBS=ON \
        -DSD_WEBP=OFF \
        -DSD_WEBM=OFF \
        -DCMAKE_CUDA_ARCHITECTURES="75;80;86;89;90;120" \
    && cmake --build /build/stable-diffusion --target stable-diffusion sd-cli -j "$(nproc)"

COPY upstream/keryx-node /src/keryx-node
RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    cd /src/keryx-node \
    && CARGO_TARGET_DIR=/build/node-target cargo build --locked --release -p keryxd \
    && CARGO_TARGET_DIR=/build/node-target cargo build --locked --release -p rothschild --bin image-web --bin demo-keygen

FROM nvidia/cuda:${MINER_CUDA_VERSION}-devel-ubuntu22.04 AS miner-build

ARG RUST_VERSION=1.95.0

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git libssl-dev pkg-config protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain ${RUST_VERSION}

ENV PATH=/root/.cargo/bin:${PATH}

COPY upstream/keryx-miner /src/keryx-miner
RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    cd /src/keryx-miner \
    && CARGO_TARGET_DIR=/build/miner-target \
       KERYX_LLAMA_SKIP=1 \
       cargo build --locked --release -p keryx-miner -p keryxcuda

FROM ipfs/kubo:${KUBO_VERSION} AS kubo

FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu24.04 AS runtime

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl libgomp1 libssl3 socat \
    && rm -rf /var/lib/apt/lists/*

COPY --from=kubo /usr/local/bin/ipfs /usr/local/bin/ipfs
COPY --from=build /build/node-target/release/keryxd /opt/keryx/bin/keryxd
COPY --from=build /build/node-target/release/image-web /opt/keryx/bin/image-web
COPY --from=build /build/node-target/release/demo-keygen /opt/keryx/bin/demo-keygen
COPY --from=miner-build /build/miner-target/release/keryx-miner /opt/keryx/bin/keryx-miner
COPY --from=miner-build /build/miner-target/release/libkeryxcuda.so /opt/keryx/bin/libkeryxcuda.so
COPY --from=build /build/stable-diffusion/bin/libstable-diffusion.so /opt/keryx/bin/libstable-diffusion.so
COPY --from=build /build/stable-diffusion/bin/sd-cli /opt/keryx/bin/sd-cli
COPY demo/entrypoint.sh /opt/keryx/bin/demo-entrypoint

ENV PATH=/opt/keryx/bin:${PATH} \
    LD_LIBRARY_PATH=/opt/keryx/bin \
    KERYX_SD_DLL=/opt/keryx/bin/libstable-diffusion.so \
    KERYX_SD_MODEL=/models/sd-v1-5-q8_0.gguf \
    IPFS_PATH=/data/ipfs

RUN chmod +x /opt/keryx/bin/demo-entrypoint

EXPOSE 8081
ENTRYPOINT ["demo-entrypoint"]
