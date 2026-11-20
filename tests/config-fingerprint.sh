#!/usr/bin/env bash
set -euo pipefail

script=$(realpath "$(dirname "$0")/../.github/scripts/config-fingerprint.sh")
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export GITHUB_WORKSPACE="$fixture"
export BUILD_NAME=target-source SOURCE_REPOSITORY=immortalwrt/immortalwrt SOURCE_REF=v25
export OPENCLASH=true BASE_CONFIG='' TARGET='' PROFILE=''
export CONFIG_FILE=.github/configs/target.config
mkdir -p "$fixture/.github/scripts" "$fixture/.github/configs"
for file in config-fingerprint.sh build-fingerprint.sh previous-build.sh; do
  printf '%s\n' "$file-v1" > "$fixture/.github/scripts/$file"
done
printf 'CONFIG_TARGET=y\n' > "$fixture/.github/configs/target.config"

fingerprint() { bash "$script"; }
before=$(fingerprint)
[[ $(fingerprint) == "$before" ]] || { echo 'FAIL: unstable configuration fingerprint'; exit 1; }
printf 'README change\n' > "$fixture/README.md"
[[ $(fingerprint) == "$before" ]] || { echo 'FAIL: unrelated file changed fingerprint'; exit 1; }
printf 'CONFIG_CHANGED=y\n' >> "$fixture/.github/configs/target.config"
[[ $(fingerprint) != "$before" ]] || { echo 'FAIL: config change ignored'; exit 1; }
before=$(fingerprint)
export BUILD_NAME=target-imagebuilder
[[ $(fingerprint) != "$before" ]] || { echo 'FAIL: build lane change ignored'; exit 1; }

echo 'PASS: stable, scoped, config-sensitive, lane-sensitive fingerprint'
