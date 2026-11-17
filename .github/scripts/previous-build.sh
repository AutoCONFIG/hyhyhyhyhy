#!/usr/bin/env bash
set -euo pipefail

[[ -f "$RUNNER_TEMP/successful-build" ]] || exit 1
previous_run=$(cat "$RUNNER_TEMP/successful-build")
[[ "$previous_run" =~ ^[0-9]+$ ]] || exit 1

gh api "repos/$GITHUB_REPOSITORY/actions/runs/$previous_run/artifacts" \
  --jq '[.artifacts[] | select(.expired == false) | .name] | contains(["immortalwrt_buildinfo", "immortalwrt_package", "immortalwrt_firmware"])' \
  | grep -qx true

printf '输入未变，跳过编译。沿用上次产物：%s/%s/actions/runs/%s\n' \
  "$GITHUB_SERVER_URL" "$GITHUB_REPOSITORY" "$previous_run" >> "$GITHUB_STEP_SUMMARY"
