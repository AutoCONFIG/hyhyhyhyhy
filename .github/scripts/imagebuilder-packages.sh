#!/usr/bin/env bash
set -euo pipefail

config_file=${1:?configuration file required}
target=${2:?target required}
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

printf '%s\n' "${packages[@]}" | sort -u
