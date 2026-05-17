#!/usr/bin/env bash
# Run the test suite inside a Linux Swift container.
# Requires Docker (OrbStack works fine).
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="${SWIFT_IMAGE:-swift:6.3}"
# Run as the host user so the container can write .build/ inside the bind mount,
# and so POSIX permission checks don't get root's "bypass everything" treatment.
# HOME points at /tmp because the unmapped uid has no /etc/passwd entry; Swift's
# FileManager.homeDirectoryForCurrentUser reads HOME on Linux.
exec docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -v "$PWD:/work" \
    -w /work \
    "$IMAGE" \
    swift test "$@"
