#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/zh-cn" <<'PACKAGES'
luci-i18n-base-zh-cn
luci-i18n-cpufreq-zh-cn
luci-i18n-diskman-zh-cn
luci-i18n-firewall-zh-cn
luci-i18n-package-manager-zh-cn
luci-i18n-upnp-zh-cn
PACKAGES

cat > "$tmp/x86.config" <<'CFG'
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_mdadm=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_kmod_md_raid456=y
CONFIG_PACKAGE_luci-app-openclash=y
# CONFIG_PACKAGE_luci-app-rclone_INCLUDE_rclone-ng is not set
CONFIG_PACKAGE_openvpn-openssl=y
CFG
x86_packages=$(bash "$root/.github/scripts/imagebuilder-packages.sh" "$tmp/x86.config" x86/64 "$tmp/zh-cn" < /dev/null | paste -sd' ' -)
expected_x86='btrfs-progs kmod-md-raid456 lsblk luci-app-diskman luci-app-openclash luci-i18n-base-zh-cn luci-i18n-diskman-zh-cn luci-i18n-firewall-zh-cn luci-i18n-package-manager-zh-cn mdadm openvpn-openssl'
[[ "$x86_packages" == "$expected_x86" ]] || { echo "unexpected x86 packages: $x86_packages" >&2; exit 1; }

cat > "$tmp/r66s.config" <<'CFG'
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-rclone=y
CONFIG_PACKAGE_luci-app-upnp=y
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_mdadm is not set
# CONFIG_PACKAGE_luci-app-rclone_INCLUDE_rclone-ng is not set
CFG
r66s_packages=$(bash "$root/.github/scripts/imagebuilder-packages.sh" "$tmp/r66s.config" rockchip/armv8 "$tmp/zh-cn" <<< luci-app-cpufreq | paste -sd' ' -)
expected_r66s='luci-app-openclash luci-app-rclone luci-app-upnp luci-i18n-base-zh-cn luci-i18n-cpufreq-zh-cn luci-i18n-firewall-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-upnp-zh-cn'
[[ "$r66s_packages" == "$expected_r66s" ]] || { echo "unexpected R66s packages: $r66s_packages" >&2; exit 1; }

printf '%s\n' 'CONFIG_PACKAGE_luci-app-rclone_INCLUDE_unknown=y' > "$tmp/unknown.config"
if bash "$root/.github/scripts/imagebuilder-packages.sh" "$tmp/unknown.config" x86/64 "$tmp/zh-cn" < /dev/null > "$tmp/output" 2>&1; then
  echo "unsupported package option unexpectedly accepted" >&2
  exit 1
fi
grep -q 'unsupported package option:' "$tmp/output"

printf 'imagebuilder package translation: PASS\n'
