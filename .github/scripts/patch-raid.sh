#!/usr/bin/env bash
set -euo pipefail

init_file=${1:?mdadm init file required}
grep -q 'echo 800000 > /proc/sys/dev/raid/speed_limit_max' "$init_file" && exit 0
sed -i '/\$PROG --assemble --scan --config="\$CONF"/a\\n\t[ -w /proc/sys/dev/raid/speed_limit_min ] && {\n\t\techo 200000 > /proc/sys/dev/raid/speed_limit_min\n\t\techo 800000 > /proc/sys/dev/raid/speed_limit_max\n\t}' "$init_file"
