#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH_DIR="${TMPDIR:-/tmp}/mac-cleaner-build"
TESTING_PLUGIN="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"

cd "$ROOT_DIR"

EXTRA_FLAGS=()
if [[ -f "$TESTING_PLUGIN" ]]; then
    EXTRA_FLAGS+=(-Xswiftc -load-plugin-library -Xswiftc "$TESTING_PLUGIN")
fi

swift test --scratch-path "$SCRATCH_DIR" "${EXTRA_FLAGS[@]}" "$@"
