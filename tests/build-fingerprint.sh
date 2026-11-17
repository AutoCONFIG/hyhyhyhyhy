#!/usr/bin/env bash
set -euo pipefail

script=$(realpath "$(dirname "$0")/../.github/scripts/build-fingerprint.sh")
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export GITHUB_SHA=workflow-v1
mkdir -p "$fixture/source/openclash" "$fixture/feeds/packages"
printf 'source-v1\n' > "$fixture/source/Makefile"
printf 'config-v1\n' > "$fixture/source/.config"
printf 'openclash-v1\n' > "$fixture/source/openclash/Makefile"
printf 'feed-v1\n' > "$fixture/feeds/packages/Makefile"
ln -s Makefile "$fixture/source/link"
cd "$fixture"

fingerprint() {
  local source_hash
  source_hash=$(bash "$script" source)
  SOURCE_FINGERPRINT="$source_hash" bash "$script" feeds/packages
}

before=$(fingerprint)
touch -t 202001010000 source/Makefile source/.config feeds/packages/Makefile
[[ $(fingerprint) == "$before" ]] || { echo 'FAIL: timestamps changed fingerprint'; exit 1; }

for input in source/Makefile source/.config source/openclash/Makefile feeds/packages/Makefile; do
  before=$(fingerprint)
  printf 'changed\n' >> "$input"
  [[ $(fingerprint) != "$before" ]] || { echo "FAIL: ignored change to $input"; exit 1; }
done

before=$(fingerprint)
ln -sfn .config source/link
[[ $(fingerprint) != "$before" ]] || { echo 'FAIL: ignored symlink change'; exit 1; }

before=$(fingerprint)
export GITHUB_SHA=workflow-v2
[[ $(fingerprint) != "$before" ]] || { echo 'FAIL: ignored workflow revision'; exit 1; }

before=$(fingerprint)
printf 'gitdir: /checkout-specific/path\n' > source/.git
[[ $(fingerprint) == "$before" ]] || { echo 'FAIL: Git bookkeeping changed fingerprint'; exit 1; }

if bash "$script" missing-directory >/dev/null 2>&1; then
  echo 'FAIL: accepted missing inputs'
  exit 1
fi

echo 'PASS: unchanged inputs, timestamps, source, config, OpenClash, feeds, symlinks, workflow revision, Git bookkeeping, missing inputs'
