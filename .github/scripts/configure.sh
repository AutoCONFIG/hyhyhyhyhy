#!/usr/bin/env bash
set -euo pipefail

[[ ! -f .build-configured ]] || exit 0
./scripts/feeds install -a
bash "$GITHUB_WORKSPACE/.github/scripts/patch-rust.sh"

if [[ "$OPENCLASH" == true ]] && ! grep -q 'echo 800000 > /proc/sys/dev/raid/speed_limit_max' package/utils/mdadm/files/mdadm.init; then
  bash "$GITHUB_WORKSPACE/.github/scripts/patch-raid.sh" package/utils/mdadm/files/mdadm.init
fi

rm -f ./.config*
if [[ -n "$BASE_CONFIG" ]]; then
  cp -f "$BASE_CONFIG" .config
else
  touch .config
fi
cat "$GITHUB_WORKSPACE/$CONFIG_FILE" >> .config
if [[ -n "${CCACHE_DIR:-}" ]]; then
  printf 'CONFIG_DEVEL=y\nCONFIG_CCACHE=y\nCONFIG_CCACHE_DIR="%s"\n' "$CCACHE_DIR" >> .config
fi
sed -i 's/^[ \t]*//g' .config
make defconfig
touch .build-configured
