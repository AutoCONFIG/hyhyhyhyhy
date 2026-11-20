#!/usr/bin/env bash
set -euo pipefail

rust_makefile=${1:-feeds/packages/lang/rust/Makefile}
[[ -f "$rust_makefile" ]] || exit 0

if grep -Fq -- '--set=llvm.download-ci-llvm=true' "$rust_makefile"; then
  sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/g' "$rust_makefile"
fi
