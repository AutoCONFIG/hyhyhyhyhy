#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

rust_makefile="$tmp/Makefile"
printf '%s\n' 'HOST_CONFIGURE_ARGS = --set=llvm.download-ci-llvm=true' > "$rust_makefile"
bash "$root/.github/scripts/patch-rust.sh" "$rust_makefile"
grep -Fqx 'HOST_CONFIGURE_ARGS = --set=llvm.download-ci-llvm=false' "$rust_makefile"

bash "$root/.github/scripts/patch-rust.sh" "$rust_makefile"
grep -Fqx 'HOST_CONFIGURE_ARGS = --set=llvm.download-ci-llvm=false' "$rust_makefile"

bash "$root/.github/scripts/patch-rust.sh" "$tmp/missing"

printf '%s\n' 'HOST_CONFIGURE_ARGS = --release-channel=stable' > "$rust_makefile"
bash "$root/.github/scripts/patch-rust.sh" "$rust_makefile"
grep -Fqx 'HOST_CONFIGURE_ARGS = --release-channel=stable' "$rust_makefile"

echo 'Rust LLVM download patch: PASS'
