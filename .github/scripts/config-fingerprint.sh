#!/usr/bin/env bash
set -euo pipefail

root=${GITHUB_WORKSPACE:-$PWD}
files=("$root/.github/scripts/config-fingerprint.sh" "$root/.github/scripts/build-fingerprint.sh" "$root/.github/scripts/previous-build.sh")
[[ -n "${CONFIG_FILE:-}" ]] && files+=("$root/$CONFIG_FILE")
for path in "$@"; do
  files+=("$root/$path")
done

{
  printf '%s\n' "BUILD_NAME=${BUILD_NAME:-}" "SOURCE_REPOSITORY=${SOURCE_REPOSITORY:-}" \
    "SOURCE_REF=${SOURCE_REF:-}" "OPENCLASH=${OPENCLASH:-}" "BASE_CONFIG=${BASE_CONFIG:-}" \
    "TARGET=${TARGET:-}" "PROFILE=${PROFILE:-}"
  for path in "${files[@]}"; do
    [[ -f "$path" ]] || { printf 'missing=%s\n' "$path"; exit 1; }
    printf '%s ' "${path#"$root/"}"
    sha256sum < "$path"
  done
} | sha256sum | cut -d ' ' -f 1
