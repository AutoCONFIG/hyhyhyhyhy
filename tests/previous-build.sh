#!/usr/bin/env bash
set -euo pipefail

script=$(realpath "$(dirname "$0")/../.github/scripts/previous-build.sh")
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export RUNNER_TEMP="$fixture"
export GITHUB_REPOSITORY=owner/firmware GITHUB_SERVER_URL=https://github.com
export GITHUB_STEP_SUMMARY="$fixture/summary"
export ARTIFACT_RESPONSE="$fixture/artifacts.json"
export API_FAILURE=false
export JQ="${JQ:-jq}"

gh() {
  [[ "$API_FAILURE" != true ]] || return 1
  "$JQ" -r "$4" "$ARTIFACT_RESPONSE"
}
export -f gh

printf '%s\n' '{"artifacts":[{"name":"immortalwrt_buildinfo","expired":false},{"name":"immortalwrt_package","expired":false},{"name":"immortalwrt_firmware","expired":false}]}' > "$fixture/complete.json"
printf '12345\n' > "$RUNNER_TEMP/successful-build"
cp "$fixture/complete.json" "$ARTIFACT_RESPONSE"
bash "$script"
grep -qF 'https://github.com/owner/firmware/actions/runs/12345' "$GITHUB_STEP_SUMMARY"

rejects_previous_build() {
  if bash "$script" >/dev/null 2>&1; then
    echo "FAIL: reused unavailable build ($1)"
    exit 1
  fi
}

for artifact in immortalwrt_buildinfo immortalwrt_package immortalwrt_firmware; do
  "$JQ" --arg name "$artifact" '.artifacts |= map(select(.name != $name))' "$fixture/complete.json" > "$ARTIFACT_RESPONSE"
  rejects_previous_build "missing $artifact"
  "$JQ" --arg name "$artifact" '(.artifacts[] | select(.name == $name)).expired = true' "$fixture/complete.json" > "$ARTIFACT_RESPONSE"
  rejects_previous_build "expired $artifact"
done

cp "$fixture/complete.json" "$ARTIFACT_RESPONSE"
export API_FAILURE=true
rejects_previous_build 'API failure'
export API_FAILURE=false
printf 'invalid-run\n' > "$RUNNER_TEMP/successful-build"
rejects_previous_build 'invalid run ID'
rm "$RUNNER_TEMP/successful-build"
rejects_previous_build 'missing success record'

echo 'PASS: usable artifacts, missing and expired artifacts, API failure, invalid and missing success record'
