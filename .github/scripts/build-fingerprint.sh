#!/usr/bin/env bash
set -euo pipefail
: "${1:?source directory required}"

{
  printf '%s\n' "${GITHUB_SHA:?}" "${SOURCE_FINGERPRINT:-}"
  for repo in "$@"; do
    if [[ -d "$repo/.git" ]]; then
      git -C "$repo" rev-parse HEAD
    fi
  done
  tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
    --exclude=.git -cf - "$@"
} | sha256sum | cut -d ' ' -f 1
