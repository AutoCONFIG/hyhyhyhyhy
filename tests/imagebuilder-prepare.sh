#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/cache" "$tmp/metadata"
printf 'OpenClash fixture\n' > "$tmp/cache/openclash.apk"
digest=$(sha256sum "$tmp/cache/openclash.apk" | cut -d ' ' -f 1)
printf 'OPENCLASH_NAME=openclash.apk\nOPENCLASH_URL=unused\nOPENCLASH_SHA256=%s\n' "$digest" > "$tmp/metadata/env"
printf '%s\n' '#!/bin/sh' 'start_service() {' '  $PROG --assemble --scan --config="$CONF"' '}' > "$tmp/metadata/mdadm.init"

export GITHUB_WORKSPACE=$root IMAGEBUILDER_METADATA_DIR=$tmp/metadata IMAGEBUILDER_CACHE=$tmp/cache
export SOURCE_REPOSITORY=immortalwrt/immortalwrt CONFIG_FILE=.github/configs/openclash-x86.config TARGET=x86/64 PROFILE=generic
bash "$root/.github/scripts/imagebuilder-build.sh" prepare
overlay="$tmp/metadata/files/etc/init.d/mdadm"
grep -Fq 'echo 200000 > /proc/sys/dev/raid/speed_limit_min' "$overlay"
grep -Fq 'echo 800000 > /proc/sys/dev/raid/speed_limit_max' "$overlay"
first=$(sha256sum "$overlay")
printf '%s\n' 'extra_source_line' >> "$tmp/metadata/mdadm.init"
bash "$root/.github/scripts/imagebuilder-build.sh" prepare
second=$(sha256sum "$overlay")
[[ "$first" != "$second" ]] || { echo "mdadm source change did not update the overlay" >&2; exit 1; }
grep -Fq 'extra_source_line' "$overlay"
printf 'imagebuilder overlay preparation: PASS\n'
