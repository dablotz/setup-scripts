#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly IMAGE="dev-env-test"

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

echo "==> Building test image..."
docker build -t "$IMAGE" "$SCRIPT_DIR"

echo "==> Running dev_env.sh in container..."
docker run --rm \
  -v "$ROOT_DIR/dev_env.sh:/home/devuser/dev_env.sh:ro" \
  -v "$SCRIPT_DIR/dev_env_test.tsv:/home/devuser/dev_env.tsv:ro" \
  "$IMAGE"

echo "==> Run completed. To inspect the container interactively:"
echo "    docker run -it --rm \\"
echo "      -v \"$ROOT_DIR/dev_env.sh:/home/devuser/dev_env.sh:ro\" \\"
echo "      -v \"$SCRIPT_DIR/dev_env_test.tsv:/home/devuser/dev_env.tsv:ro\" \\"
echo "      --entrypoint /bin/bash $IMAGE"
