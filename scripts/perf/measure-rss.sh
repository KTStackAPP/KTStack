#!/usr/bin/env bash
# Đo peak RSS (MB) của một tiến trình theo tên, lấy mẫu mỗi 0.5s trong DURATION giây.
# Dùng cho baseline/regression bộ nhớ cửa sổ Database mà không cần Instruments GUI.
# Usage: measure-rss.sh <process-name> [duration-seconds]
#   measure-rss.sh KTStack 20
set -euo pipefail

NAME="${1:?process name required}"
DURATION="${2:-20}"

peak_kb=0
end=$(( $(date +%s) + DURATION ))
while [ "$(date +%s)" -lt "$end" ]; do
  # Cộng RSS mọi tiến trình khớp tên (app + helper con nếu có cùng tên); lấy max theo thời gian.
  kb=$(ps -axo comm,rss | awk -v n="$NAME" '$1 ~ n { s += $2 } END { print s+0 }')
  if [ "$kb" -gt "$peak_kb" ]; then peak_kb=$kb; fi
  sleep 0.5
done

if [ "$peak_kb" -eq 0 ]; then
  echo "no process matched \"$NAME\"" >&2
  exit 1
fi

awk -v kb="$peak_kb" 'BEGIN { printf "peak RSS %s: %.1f MB\n", ARGV[1], kb/1024 }' "$NAME"
