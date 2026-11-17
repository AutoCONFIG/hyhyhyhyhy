#!/usr/bin/env bash
set -euo pipefail

script=$(realpath "$(dirname "$0")/../.github/scripts/configure.sh")
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export GITHUB_WORKSPACE="$fixture/configuration"
export CONFIG_FILE=overlay.config
mkdir -p "$GITHUB_WORKSPACE" "$fixture/source/scripts" "$fixture/source/package/utils/mdadm/files"
printf 'CONFIG_DEVICE=y\n# CONFIG_UNWANTED is not set\n' > "$GITHUB_WORKSPACE/$CONFIG_FILE"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/source/scripts/feeds"
chmod +x "$fixture/source/scripts/feeds"
printf 'defconfig:\n\t@test ! -f .fail-defconfig\n\t@cp .config configured.config\n' > "$fixture/source/Makefile"
printf '$PROG --assemble --scan --config="$CONF"\n' > "$fixture/source/package/utils/mdadm/files/mdadm.init"
cd "$fixture/source"

export OPENCLASH=true BASE_CONFIG=''
touch .fail-defconfig
if bash "$script" >/dev/null 2>&1; then
  echo 'FAIL: accepted failed defconfig'
  exit 1
fi
[[ ! -f .build-configured ]] || { echo 'FAIL: recorded failed configuration as complete'; exit 1; }
rm .fail-defconfig
bash "$script"
cmp "$GITHUB_WORKSPACE/$CONFIG_FILE" configured.config
[[ $(grep -c 'echo 800000 > /proc/sys/dev/raid/speed_limit_max' package/utils/mdadm/files/mdadm.init) == 1 ]] \
  || { echo 'FAIL: retry duplicated RAID patch'; exit 1; }

touch .fail-defconfig
bash "$script"
rm .fail-defconfig .build-configured

export OPENCLASH=false BASE_CONFIG=base.config
printf 'CONFIG_BASE=y\n' > "$BASE_CONFIG"
cat "$BASE_CONFIG" "$GITHUB_WORKSPACE/$CONFIG_FILE" > expected.config
bash "$script"
cmp expected.config configured.config

echo 'PASS: exact overlay, inherited base config, failed configuration retry, idempotent RAID patch, completed configuration reuse'
