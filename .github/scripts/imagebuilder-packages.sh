#!/usr/bin/env bash
set -euo pipefail

config_file=${1:?configuration file required}
target=${2:?target required}
translation_index=${3:?translation index required}
[[ -f "$config_file" ]] || { echo "configuration file not found: $config_file" >&2; exit 1; }

packages=()
diskman=false
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line#"${line%%[![:space:]]*}"}
  case "$line" in
    CONFIG_PACKAGE_*=y)
      key=${line#CONFIG_PACKAGE_}
      key=${key%=y}
      case "$key" in
        luci-app-diskman)
          diskman=true
          packages+=("$key")
          ;;
        *_INCLUDE_*)
          case "$key" in
            luci-app-diskman_INCLUDE_mdadm) packages+=(mdadm) ;;
            luci-app-diskman_INCLUDE_kmod_md_raid456) packages+=(kmod-md-raid456) ;;
            luci-app-diskman_INCLUDE_btrfs_progs) packages+=(btrfs-progs) ;;
            luci-app-diskman_INCLUDE_lsblk) packages+=(lsblk) ;;
            luci-app-diskman_INCLUDE_kmod_md_linears) packages+=(mdadm kmod-md-linear) ;;
            luci-app-rclone_INCLUDE_rclone-ng) packages+=(rclone-ng) ;;
            luci-app-rclone_INCLUDE_rclone-webui) packages+=(rclone-webui-react) ;;
            *) echo "unsupported package option: $key" >&2; exit 1 ;;
          esac
          ;;
        *) packages+=("$key") ;;
      esac
      ;;
  esac
done < "$config_file"

if [[ "$target" == x86/64 && "$diskman" == true ]]; then
  packages+=(btrfs-progs lsblk)
fi

mapfile -t profile_packages
packages+=(luci-i18n-base-zh-cn)
for app in luci-app-firewall luci-app-package-manager "${profile_packages[@]}" "${packages[@]}"; do
  [[ "$app" == luci-app-* ]] || continue
  translation="luci-i18n-${app#luci-app-}-zh-cn"
  if grep -Fxq -- "$translation" "$translation_index"; then
    packages+=("$translation")
  fi
done

printf '%s\n' "${packages[@]}" | sort -u
