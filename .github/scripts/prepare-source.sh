#!/usr/bin/env bash
set -euo pipefail

downloads="$RUNNER_TEMP/firmware-sources"
mkdir -p "$downloads"

case "$SOURCE_REF" in
  v24|v25)
    version=$(gh api "repos/$SOURCE_REPOSITORY/tags" \
      --jq "[.[] | select(.name | startswith(\"$SOURCE_REF\"))][0].name // empty")
    [[ -n "$version" ]]
    curl -fL --retry 3 "https://github.com/$SOURCE_REPOSITORY/archive/refs/tags/$version.zip" -o "$downloads/openwrt.zip"
    unzip -q "$downloads/openwrt.zip" -d "$downloads"
    mkdir -p openwrt
    mv "$downloads/immortalwrt-${version#v}"/* openwrt/
    ;;
  *)
    git clone --depth=1 --branch="$SOURCE_REF" "https://github.com/$SOURCE_REPOSITORY.git" openwrt
    ;;
esac

if [[ "$OPENCLASH" == true ]]; then
  version=$(gh api repos/vernesong/OpenClash/tags --jq '.[0].name // empty')
  [[ -n "$version" ]]
  curl -fL --retry 3 "https://github.com/vernesong/OpenClash/archive/refs/tags/$version.zip" -o "$downloads/openclash.zip"
  unzip -q "$downloads/openclash.zip" -d "$downloads"
  mv "$downloads/OpenClash-${version#v}/luci-app-openclash" openwrt/package/
fi
