#!/bin/bash
# Captures the store listing screenshots end to end.
#
#   tool/make_screenshots.sh [udid] [out-dir]
#
# Defaults to the iPhone 17 Pro Max simulator, which renders at 1320x2868 —
# the 6.9" size App Store Connect requires. Everything else is derived from it.
#
# It ERASES the simulator first. integration_test/store_screenshots_test.dart
# writes its seed stack into the device's real database, and a rerun over an
# existing one would show ten supplements instead of five.
set -euo pipefail
cd "$(dirname "$0")/.."

UDID="${1:-$(xcrun simctl list devices available | awk -F'[()]' '/iPhone 17 Pro Max/{print $2; exit}')}"
OUT="${2:-store/screenshots/ios-6.9}"
[ -n "$UDID" ] || { echo "no iPhone 17 Pro Max simulator found"; exit 1; }

echo "==> simulator $UDID -> $OUT"
xcrun simctl shutdown "$UDID" 2>/dev/null || true
xcrun simctl erase "$UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

# A listing screenshot should not advertise 23% battery and a 14:37 clock.
# 9:41 is Apple's own convention in every keynote and marketing shot.
xcrun simctl status_bar "$UDID" override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

mkdir -p "$OUT"
rm -f "$OUT"/*.png

# The device process cannot spawn xcrun, so it asks the host for each shot.
tool/l10n_screenshot_watcher.sh ios "$UDID" "$OUT" "" 600 &
WATCHER=$!
trap 'kill $WATCHER 2>/dev/null || true' EXIT

flutter test integration_test/store_screenshots_test.dart -d "$UDID"

kill $WATCHER 2>/dev/null || true
trap - EXIT
echo "==> captured:"
for f in "$OUT"/*.png; do
  printf '  %s  %s\n' "$(basename "$f")" \
    "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2}')"
done
