#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$root"

action=${1:-up}

check_docker() {
    command -v docker >/dev/null || { echo "Docker is required." >&2; exit 1; }
    docker info >/dev/null || { echo "Docker is not running." >&2; exit 1; }
    docker compose version >/dev/null || { echo "Docker Compose v2 is required." >&2; exit 1; }
    docker compose config -q
}

wait_until_ready() {
    echo "Waiting for model preparation and the private devnet..."
    for _ in $(seq 1 360); do
        if docker compose exec -T demo curl -fsS http://127.0.0.1:8081/ >/dev/null 2>&1; then
            echo "Keryx image demo: http://127.0.0.1:8080"
            command -v xdg-open >/dev/null && xdg-open http://127.0.0.1:8080 >/dev/null 2>&1 || true
            return
        fi
        if [[ -n "$(docker compose ps --status exited -q demo)" ]]; then
            docker compose logs --tail=100 demo
            echo "The demo stopped before becoming ready." >&2
            exit 1
        fi
        sleep 10
    done
    docker compose logs --tail=100 demo
    echo "The demo did not become ready within one hour." >&2
    exit 1
}

case "$action" in
    up)
        check_docker
        mkdir -p models
        docker compose up --build -d
        wait_until_ready
        ;;
    doctor)
        check_docker
        docker run --rm --gpus all nvidia/cuda:13.0.1-base-ubuntu24.04 nvidia-smi
        ;;
    logs)
        docker compose logs -f demo
        ;;
    status)
        docker compose ps
        ;;
    down)
        docker compose down
        ;;
    reset)
        docker compose down --volumes --remove-orphans
        echo "Devnet state reset. Downloaded models were preserved."
        ;;
    *)
        echo "Usage: ./demo.sh [up|doctor|logs|status|down|reset]" >&2
        exit 2
        ;;
esac
