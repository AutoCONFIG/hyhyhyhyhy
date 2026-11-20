#!/usr/bin/env bash
set -euo pipefail

mode=${1:-build}
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${IMAGEBUILDER_METADATA_DIR:?IMAGEBUILDER_METADATA_DIR is required}"
: "${SOURCE_REPOSITORY:?SOURCE_REPOSITORY is required}"
: "${CONFIG_FILE:?CONFIG_FILE is required}"
: "${TARGET:?TARGET is required}"
: "${PROFILE:?PROFILE is required}"

metadata_dir=$IMAGEBUILDER_METADATA_DIR
source "$metadata_dir/env"
cache_dir=${IMAGEBUILDER_CACHE:-$GITHUB_WORKSPACE/.imagebuilder-cache}
mkdir -p "$cache_dir"

download_cached() {
  local url=$1 destination=$2 expected=$3
  if [[ -f "$destination" ]] && printf '%s  %s\n' "$expected" "$destination" | sha256sum -c - >/dev/null 2>&1; then
    return
  fi
  local temporary="${destination}.part.$$"
  curl -fL --retry 3 --retry-all-errors "$url" -o "$temporary"
  printf '%s  %s\n' "$expected" "$temporary" | sha256sum -c -
  mv -f "$temporary" "$destination"
}

prepare_openclash() {
  local cached="$cache_dir/$OPENCLASH_NAME"
  download_cached "$OPENCLASH_URL" "$cached" "$OPENCLASH_SHA256"
  cp -f "$cached" "$metadata_dir/$OPENCLASH_NAME"
  printf '%s  %s\n' "$OPENCLASH_SHA256" "$metadata_dir/$OPENCLASH_NAME" | sha256sum -c -
}

if [[ "$mode" == prepare ]]; then
  prepare_openclash
  if [[ "$TARGET" == x86/64 ]]; then
    files_dir="$metadata_dir/files"
    mkdir -p "$files_dir/etc/init.d"
    cp -f "$metadata_dir/mdadm.init" "$files_dir/etc/init.d/mdadm"
    chmod 0755 "$files_dir/etc/init.d/mdadm"
    bash "$GITHUB_WORKSPACE/.github/scripts/patch-raid.sh" "$files_dir/etc/init.d/mdadm"
    grep -Fq 'echo 200000 > /proc/sys/dev/raid/speed_limit_min' "$files_dir/etc/init.d/mdadm"
    grep -Fq 'echo 800000 > /proc/sys/dev/raid/speed_limit_max' "$files_dir/etc/init.d/mdadm"
  fi
  exit 0
fi
[[ "$mode" == build ]] || { echo "usage: $0 [prepare|build]" >&2; exit 2; }

prepare_openclash
archive_url="$RELEASE_BASE/$ARCHIVE_NAME"
archive="$cache_dir/$ARCHIVE_NAME"
download_cached "$archive_url" "$archive" "$ARCHIVE_SHA256"

build_root="$RUNNER_TEMP/imagebuilder-${GITHUB_RUN_ID:-$$}"
mkdir -p "$build_root"
tar --zstd -xf "$archive" -C "$build_root"
mapfile -t imagebuilder_dirs < <(find "$build_root" -mindepth 1 -maxdepth 1 -type d -print)
[[ "${#imagebuilder_dirs[@]}" -eq 1 ]] || { echo "expected one ImageBuilder directory in $archive" >&2; exit 1; }
imagebuilder_dir=${imagebuilder_dirs[0]}
mkdir -p "$cache_dir/dl"
find "$cache_dir/dl" -maxdepth 1 -type f -name 'APKINDEX.*' -delete
ln -s "$cache_dir/dl" "$imagebuilder_dir/dl"

mkdir -p "$imagebuilder_dir/packages"
cp -f "$metadata_dir/$OPENCLASH_NAME" "$imagebuilder_dir/packages/"
apk="$imagebuilder_dir/staging_dir/host/bin/apk"
package_version=$("$apk" adbdump "$metadata_dir/$OPENCLASH_NAME" |
  awk '$1 == "version:" && !found { print $2; found = 1 }')
[[ "$package_version" == "${OPENCLASH_VERSION#v}" ]] || {
  echo "OpenClash package version $package_version does not match $OPENCLASH_VERSION" >&2
  exit 1
}
translation_index="$metadata_dir/zh-cn-packages"
"$apk" adbdump "$metadata_dir/indexes/"*.packages.adb |
  awk '$1 == "-" && $2 == "name:" && $3 ~ /^luci-i18n-.*-zh-cn$/ { print $3 }' > "$translation_index"
jq_bin=${JQ:-jq}
profile_packages=$("$jq_bin" -r --arg profile "$PROFILE" '.default_packages[], .profiles[$profile].device_packages[]' "$metadata_dir/profiles.json")
packages=$(bash "$GITHUB_WORKSPACE/.github/scripts/imagebuilder-packages.sh" "$GITHUB_WORKSPACE/$CONFIG_FILE" "$TARGET" "$translation_index" <<< "$profile_packages" | paste -sd' ' -)
rootfs_partsize=$(sed -n 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=//p' "$GITHUB_WORKSPACE/$CONFIG_FILE" | tail -n1)
[[ "$rootfs_partsize" =~ ^[0-9]+$ ]] || { echo "CONFIG_TARGET_ROOTFS_PARTSIZE is missing" >&2; exit 1; }

files_dir=
if [[ "$TARGET" == x86/64 ]]; then
  files_dir="$metadata_dir/files"
  [[ -s "$files_dir/etc/init.d/mdadm" ]] || { echo "mdadm overlay was not prepared" >&2; exit 1; }
  sed -Ei \
    -e 's/^CONFIG_((ISO|QCOW2|VDI|VMDK|VHDX)_IMAGES|TARGET_ROOTFS_TARGZ)=y$/# CONFIG_\1 is not set/' \
    -e '/^(# )?CONFIG_TARGET_IMAGES_GZIP(=| )/d' "$imagebuilder_dir/.config"
  printf '\nCONFIG_TARGET_IMAGES_GZIP=y\n' >> "$imagebuilder_dir/.config"
fi

make_args=(image "PROFILE=$PROFILE" "PACKAGES=$packages" "ROOTFS_PARTSIZE=$rootfs_partsize")
[[ -n "$files_dir" ]] && make_args+=("FILES=$files_dir")
(cd "$imagebuilder_dir" && make "${make_args[@]}")

manifest=$(find "$imagebuilder_dir/bin/targets" -type f -name '*.manifest' -print -quit)
[[ -n "$manifest" ]] || { echo "ImageBuilder produced no package manifest" >&2; exit 1; }
if [[ " $packages " == *" luci-app-openclash "* ]]; then
  awk -v version="$package_version" '$1 == "luci-app-openclash" && $2 == "-" && $3 == version { found = 1 } END { exit !found }' "$manifest" || {
    echo "image does not contain OpenClash $package_version" >&2
    exit 1
  }
fi
find "$imagebuilder_dir/bin/targets" -type f -name '*.img.gz' -print -quit | grep -q . || {
  echo "ImageBuilder produced no firmware image" >&2
  exit 1
}

artifact_dir=${ARTIFACT_DIR:-$GITHUB_WORKSPACE/.imagebuilder-artifact}
[[ "$artifact_dir" == "$GITHUB_WORKSPACE/.imagebuilder-artifact" ]] || { echo "unsafe artifact path: $artifact_dir" >&2; exit 1; }
mkdir -p "$artifact_dir/buildinfo" "$artifact_dir/package" "$artifact_dir/firmware"
find "$artifact_dir/buildinfo" "$artifact_dir/package" "$artifact_dir/firmware" -mindepth 1 -exec rm -rf -- {} +

find "$imagebuilder_dir/bin/targets" -type f \( -name '*.manifest' -o -name '*.buildinfo' \) -exec cp -f -t "$artifact_dir/buildinfo" {} +
{
  printf 'source=%s\ntarget=%s\nprofile=%s\nrootfs_partsize=%s\npackages=%s\n' \
    "$SOURCE_VERSION" "$TARGET" "$PROFILE" "$rootfs_partsize" "$packages"
} > "$artifact_dir/buildinfo/imagebuilder.buildinfo"
find "$imagebuilder_dir/packages" "$cache_dir/dl" -maxdepth 1 -type f \( -name '*.apk' -o -name '*.ipk' \) -exec cp -f -t "$artifact_dir/package" {} +
cp -a "$imagebuilder_dir/bin/targets/." "$artifact_dir/firmware/"

find "$artifact_dir/buildinfo" -type f -print -quit | grep -q . || { echo "ImageBuilder produced no buildinfo" >&2; exit 1; }
find "$artifact_dir/package" -type f -print -quit | grep -q . || { echo "ImageBuilder produced no package artifact" >&2; exit 1; }
find "$artifact_dir/firmware" -type f -print -quit | grep -q . || { echo "ImageBuilder produced no firmware artifact" >&2; exit 1; }
