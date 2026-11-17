#!/usr/bin/env bash
set -euo pipefail

[[ ! -f .build-configured ]] || exit 0
./scripts/feeds install -a

if [[ "$OPENCLASH" == true ]] && ! grep -q 'echo 800000 > /proc/sys/dev/raid/speed_limit_max' package/utils/mdadm/files/mdadm.init; then
  sed -i '/\$PROG --assemble --scan --config="\$CONF"/a\\n\t[ -w /proc/sys/dev/raid/speed_limit_min ] && {\n\t\techo 200000 > /proc/sys/dev/raid/speed_limit_min\n\t\techo 800000 > /proc/sys/dev/raid/speed_limit_max\n\t}' package/utils/mdadm/files/mdadm.init
fi

rm -f ./.config*
if [[ -n "$BASE_CONFIG" ]]; then
  cp -f "$BASE_CONFIG" .config
else
  touch .config
fi
cat "$GITHUB_WORKSPACE/$CONFIG_FILE" >> .config
sed -i 's/^[ \t]*//g' .config
make defconfig
touch .build-configured
