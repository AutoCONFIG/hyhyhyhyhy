#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_REPOSITORY:?SOURCE_REPOSITORY is required}"
: "${SOURCE_REF:?SOURCE_REF is required}"
: "${TARGET:?TARGET is required}"
: "${PROFILE:?PROFILE is required}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

jq_bin=${JQ:-$(command -v jq || true)}
[[ -x "$jq_bin" ]] || { echo "jq is required to inspect release metadata" >&2; exit 1; }

api_base=${GITHUB_API_URL:-https://api.github.com}
downloads_base=${DOWNLOADS_BASE_URL:-https://downloads.immortalwrt.org}
metadata_dir=${IMAGEBUILDER_METADATA_DIR:-$GITHUB_WORKSPACE/.imagebuilder-metadata}
mkdir -p "$metadata_dir"
find "$metadata_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
mkdir -p "$metadata_dir/indexes"

case "$TARGET" in
  x86/64)
    target_path=x86/64
    archive_target=x86-64
    ;;
  rockchip/armv8)
    target_path=rockchip/armv8
    archive_target=rockchip-armv8
    ;;
  *) echo "unsupported target: $TARGET" >&2; exit 1 ;;
esac

api_get() {
  local url=$1
  local -a args=(-fsSL --retry 3 --retry-all-errors -H 'Accept: application/vnd.github+json')
  if [[ -n "${GH_TOKEN:-}" ]]; then
    args+=(-H "Authorization: Bearer $GH_TOKEN")
  fi
  curl "${args[@]}" "$url"
}

source_tags="$metadata_dir/source-tags.json"
api_get "$api_base/repos/$SOURCE_REPOSITORY/tags?per_page=100" > "$source_tags"
if [[ "$SOURCE_REF" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  source_version=$SOURCE_REF
else
  source_version=$($jq_bin -r --arg prefix "$SOURCE_REF." '
    [.[] | select(.name | startswith($prefix)) | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))]
    | sort_by([.name | capture("^v(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.(?<patch>[0-9]+)$") | (.major|tonumber), (.minor|tonumber), (.patch|tonumber)])
    | last.name // empty
  ' "$source_tags")
fi
[[ -n "$source_version" ]] || { echo "no release tag found for $SOURCE_REPOSITORY/$SOURCE_REF" >&2; exit 1; }

if [[ "$TARGET" == x86/64 ]]; then
  mdadm_source="$metadata_dir/mdadm-source.json"
  api_get "$api_base/repos/$SOURCE_REPOSITORY/contents/package/utils/mdadm/files/mdadm.init?ref=$source_version" > "$mdadm_source"
  [[ "$($jq_bin -r '.encoding // empty' "$mdadm_source")" == base64 ]] || {
    echo "mdadm.init API response is not base64" >&2
    exit 1
  }
  $jq_bin -r '.content' "$mdadm_source" | tr -d '\n' | base64 -d > "$metadata_dir/mdadm.init"
fi

release_base="$downloads_base/releases/${source_version#v}/targets/$target_path"
profiles="$metadata_dir/profiles.json"
curl -fL --retry 3 --retry-all-errors "$release_base/profiles.json" -o "$profiles"
[[ "$($jq_bin -r --arg profile "$PROFILE" '.profiles | has($profile)' "$profiles")" == true ]] || {
  echo "profile $PROFILE is not present in $release_base/profiles.json" >&2
  exit 1
}

arch_packages=$($jq_bin -r '.arch_packages' "$profiles")
kernel_version=$($jq_bin -r '.linux_kernel.version' "$profiles")
kernel_release=$($jq_bin -r '.linux_kernel.release' "$profiles")
kernel_vermagic=$($jq_bin -r '.linux_kernel.vermagic' "$profiles")
[[ "$arch_packages" != null && "$kernel_version" != null && "$kernel_vermagic" != null ]] || {
  echo "release metadata has no package or kernel information" >&2
  exit 1
}

sha256sums="$metadata_dir/sha256sums"
curl -fL --retry 3 --retry-all-errors "$release_base/sha256sums" -o "$sha256sums"
archive_name="immortalwrt-imagebuilder-${source_version#v}-${archive_target}.Linux-x86_64.tar.zst"
archive_sha=$(awk -v name="$archive_name" '$2 == "*" name { print $1; exit }' "$sha256sums")
[[ "$archive_sha" =~ ^[0-9a-f]{64}$ ]] || { echo "archive checksum missing for $archive_name" >&2; exit 1; }

index_urls=(
  "$release_base/packages/packages.adb"
  "$downloads_base/releases/${source_version#v}/packages/$arch_packages/base/packages.adb"
  "$release_base/kmods/${kernel_version}-${kernel_release}-${kernel_vermagic}/packages.adb"
  "$downloads_base/releases/${source_version#v}/packages/$arch_packages/luci/packages.adb"
  "$downloads_base/releases/${source_version#v}/packages/$arch_packages/packages/packages.adb"
  "$downloads_base/releases/${source_version#v}/packages/$arch_packages/routing/packages.adb"
  "$downloads_base/releases/${source_version#v}/packages/$arch_packages/telephony/packages.adb"
)
index_names=(target base kmods luci packages routing telephony)
for i in "${!index_urls[@]}"; do
  curl -fL --retry 3 --retry-all-errors "${index_urls[$i]}" -o "$metadata_dir/indexes/${index_names[$i]}.packages.adb"
done

openclash_tags="$metadata_dir/openclash-tags.json"
api_get "$api_base/repos/vernesong/OpenClash/tags?per_page=100" > "$openclash_tags"
openclash_version=$($jq_bin -r '
  [.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))]
  | sort_by([.name | capture("^v(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.(?<patch>[0-9]+)$") | (.major|tonumber), (.minor|tonumber), (.patch|tonumber)])
  | last.name // empty
' "$openclash_tags")
[[ -n "$openclash_version" ]] || { echo "no OpenClash release tag found" >&2; exit 1; }

openclash_release="$metadata_dir/openclash-release.json"
api_get "$api_base/repos/vernesong/OpenClash/releases/tags/$openclash_version" > "$openclash_release"
openclash_name="luci-app-openclash-${openclash_version#v}.apk"
openclash_url=$($jq_bin -r --arg name "$openclash_name" '.assets[] | select(.name == $name) | .browser_download_url' "$openclash_release" | head -n1)
openclash_digest=$($jq_bin -r --arg name "$openclash_name" '.assets[] | select(.name == $name) | .digest // empty' "$openclash_release" | head -n1)
[[ -n "$openclash_url" ]] || { echo "OpenClash release $openclash_version has no $openclash_name asset" >&2; exit 1; }
openclash_digest=${openclash_digest#sha256:}
[[ "$openclash_digest" =~ ^[0-9a-f]{64}$ ]] || { echo "OpenClash asset has no sha256 digest: $openclash_name" >&2; exit 1; }

fingerprint_files=("$metadata_dir/profiles.json" "$metadata_dir/sha256sums" "$metadata_dir/indexes"/*)
[[ "$TARGET" == x86/64 ]] && fingerprint_files+=("$metadata_dir/mdadm.init")
fingerprint="$metadata_dir/fingerprint"
{
  printf 'SOURCE_VERSION=%s\nTARGET=%s\nPROFILE=%s\nARCHIVE_NAME=%s\nARCHIVE_SHA256=%s\n' \
    "$source_version" "$TARGET" "$PROFILE" "$archive_name" "$archive_sha"
  printf 'OPENCLASH_VERSION=%s\nOPENCLASH_NAME=%s\nOPENCLASH_URL=%s\nOPENCLASH_SHA256=%s\n' \
    "$openclash_version" "$openclash_name" "$openclash_url" "$openclash_digest"
  sha256sum "${fingerprint_files[@]}" | sort
} > "$fingerprint"

env_file="$metadata_dir/env"
printf 'SOURCE_VERSION=%q\nTARGET_PATH=%q\nARCHIVE_TARGET=%q\nARCHIVE_NAME=%q\nARCHIVE_SHA256=%q\n' \
  "$source_version" "$target_path" "$archive_target" "$archive_name" "$archive_sha" > "$env_file"
printf 'RELEASE_BASE=%q\nARCH_PACKAGES=%q\nKERNEL_VERSION=%q\nKERNEL_RELEASE=%q\nKERNEL_VERMAGIC=%q\n' \
  "$release_base" "$arch_packages" "$kernel_version" "$kernel_release" "$kernel_vermagic" >> "$env_file"
printf 'OPENCLASH_VERSION=%q\nOPENCLASH_NAME=%q\nOPENCLASH_URL=%q\nOPENCLASH_SHA256=%q\n' \
  "$openclash_version" "$openclash_name" "$openclash_url" "$openclash_digest" >> "$env_file"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'source_version=%s\n' "$source_version"
    printf 'openclash_version=%s\n' "$openclash_version"
    printf 'metadata_dir=%s\n' "$metadata_dir"
  } >> "$GITHUB_OUTPUT"
fi
