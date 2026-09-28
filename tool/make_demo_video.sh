#!/bin/bash
# Records the Devpost demo walkthrough from the REAL app on a simulator.
#
#   tool/make_demo_video.sh [udid] [out-file]
#
# Defaults to the iPhone 17 Pro Max simulator and writes the raw capture to the
# session scratchpad. `integration_test/demo_video_test.dart` drives the app;
# this script only boots, records and stops.
#
# Recording ERASES the simulator first, exactly as tool/make_screenshots.sh
# does and for the same reason: the demo test writes its seed stack into the
# device's real database, and a rerun over an existing one would show ten
# supplements instead of five.
set -euo pipefail
cd "$(dirname "$0")/.."

UDID="${1:-$(xcrun simctl list devices available | awk -F'[()]' '/iPhone 17 Pro Max/{print $2; exit}')}"
OUT="${2:-build/demo/demo-raw.mov}"
[ -n "$UDID" ] || { echo "no iPhone 17 Pro Max simulator found"; exit 1; }
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

echo "==> simulator $UDID -> $OUT"
xcrun simctl shutdown "$UDID" 2>/dev/null || true
xcrun simctl erase "$UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

# A demo should not advertise 23% battery and a 14:37 clock.
xcrun simctl status_bar "$UDID" override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

xcrun simctl io "$UDID" recordVideo --codec h264 --force "$OUT" &
REC=$!
# The recorder needs a moment before the first frame it writes is real.
sleep 2
trap 'kill -INT $REC 2>/dev/null || true' EXIT

flutter test integration_test/demo_video_test.dart -d "$UDID" || true

sleep 1
kill -INT $REC 2>/dev/null || true
trap - EXIT
wait $REC 2>/dev/null || true
echo "==> wrote $OUT"
