#!/usr/bin/env bash
# Run the test suite inside a Linux Swift container.
# Requires Docker (OrbStack works fine).
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="${SWIFT_IMAGE:-swift:6.3}"
exec docker run --rm \
    -v "$PWD:/work" \
    -w /work \
    "$IMAGE" \
    swift test "$@"
