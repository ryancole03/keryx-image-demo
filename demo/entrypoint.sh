#!/usr/bin/env bash
set -Eeuo pipefail

readonly SOURCE_MODEL=/models/v1-5-pruned-emaonly.safetensors
readonly SOURCE_URL=https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors
readonly SOURCE_SHA256=6ce0161689b3853acaa03779ec93eafe75a02f4ced659bee03f50797806fa2fa
readonly MODEL_SHA256=9685394cae6ede69f28d1799ad54bd7c059a941eb3d3054802bf318422294745

pids=()

cleanup() {
    trap - EXIT INT TERM
    if ((${#pids[@]})); then
        kill "${pids[@]}" 2>/dev/null || true
        wait "${pids[@]}" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

verify_sha256() {
    local file=$1 expected=$2 actual
    actual=$(sha256sum "$file" | cut -d' ' -f1)
    [[ "$actual" == "$expected" ]] || {
        echo "SHA-256 mismatch for $file" >&2
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        return 1
    }
}

wait_for_port() {
    local port=$1 name=$2
    for _ in $(seq 1 180); do
        if (echo >/dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1; then
            return
        fi
        sleep 1
    done
    echo "$name did not become ready on port $port" >&2
    return 1
}

prepare_model() {
    mkdir -p /models
    if [[ -f "$KERYX_SD_MODEL" ]]; then
        verify_sha256 "$KERYX_SD_MODEL" "$MODEL_SHA256"
        return
    fi

    echo "Downloading the official SD 1.5 source model (cached in ./models)..."
    if [[ ! -f "$SOURCE_MODEL" ]]; then
        curl -fL --retry 3 --continue-at - -o "$SOURCE_MODEL" "$SOURCE_URL"
    fi
    verify_sha256 "$SOURCE_MODEL" "$SOURCE_SHA256"

    echo "Converting SD 1.5 to the verified Q8_0 GGUF..."
    sd-cli --mode convert --model "$SOURCE_MODEL" --output "$KERYX_SD_MODEL" --type q8_0
    verify_sha256 "$KERYX_SD_MODEL" "$MODEL_SHA256"
}

prepare_ipfs() {
    if [[ ! -f "$IPFS_PATH/config" ]]; then
        ipfs init --profile=lowpower
        ipfs bootstrap rm --all
        ipfs config Addresses.API /ip4/127.0.0.1/tcp/5001
        ipfs config Addresses.Gateway /ip4/127.0.0.1/tcp/8082
        ipfs config --json Addresses.Swarm '[]'
        ipfs config --json Discovery.MDNS.Enabled false
    fi
}

nvidia-smi >/dev/null
prepare_model
mkdir -p /data

requester_address=$(demo-keygen /data/requester.key)
chmod 600 /data/requester.key
echo "Disposable requester/miner address: $requester_address"

prepare_ipfs
ipfs daemon --offline --routing=none &
pids+=("$!")
wait_for_port 5001 Kubo

keryxd \
    --devnet \
    --appdir=/data/keryxd \
    --nologfiles \
    --rpclisten=127.0.0.1:32110 \
    --listen=127.0.0.1:32111 \
    --outpeers=0 \
    --maxinpeers=0 \
    --nodnsseed \
    --disable-upnp \
    --enable-unsynced-mining \
    --utxoindex &
pids+=("$!")
wait_for_port 32110 keryxd

keryx-miner \
    --keryxd-address 127.0.0.1 \
    --port 32110 \
    --mining-address "$requester_address" \
    --ipfs-url http://127.0.0.1:5001 \
    --escrow-key-file /data/miner-escrow.key \
    --escrow-state-file /data/miner-escrow.json \
    --mine-when-not-synced &
pids+=("$!")

image-web \
    --listen 127.0.0.1:8080 \
    --rpc 127.0.0.1:32110 \
    --private-key-file /data/requester.key \
    --ipfs-api 127.0.0.1:5001 \
    --journal /data/image-web.ndjson &
pids+=("$!")
wait_for_port 8080 image-web

echo "Waiting for mature requester funds..."
until curl -fsS http://127.0.0.1:8080/ready >/dev/null; do
    kill -0 "${pids[1]}" 2>/dev/null || { echo "keryxd exited before requester funds matured" >&2; exit 1; }
    kill -0 "${pids[2]}" 2>/dev/null || { echo "keryx-miner exited before requester funds matured" >&2; exit 1; }
    kill -0 "${pids[3]}" 2>/dev/null || { echo "image-web exited before requester funds matured" >&2; exit 1; }
    sleep 2
done

socat TCP-LISTEN:8081,bind=0.0.0.0,reuseaddr,fork TCP:127.0.0.1:8080 &
pids+=("$!")

echo "Keryx image demo ready at http://127.0.0.1:8080"
wait -n "${pids[@]}"
