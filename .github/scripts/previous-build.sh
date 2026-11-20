#!/usr/bin/env bash
set -euo pipefail
: "${BUILD_NAME:?build name required}"

[[ -f "$RUNNER_TEMP/successful-build" ]] || exit 1
previous_run=$(cat "$RUNNER_TEMP/successful-build")
[[ "$previous_run" =~ ^[0-9]+$ ]] || exit 1

gh api "repos/$GITHUB_REPOSITORY/actions/runs/$previous_run/artifacts" \
  | jq -e --arg prefix "${BUILD_NAME}_" '[.artifacts[] | select(.expired == false) | .name] as $names | ["buildinfo", "package", "firmware"] | all(. as $suffix | ($names | index($prefix + $suffix)) != null)' >/dev/null

printf '输入未变，跳过编译。沿用上次产物：%s/%s/actions/runs/%s\n' \
  "$GITHUB_SERVER_URL" "$GITHUB_REPOSITORY" "$previous_run" >> "$GITHUB_STEP_SUMMARY"
