#!/bin/bash
# Captures the App Store Connect review screenshot for the three developer
# tips.
#
#   tool/make_iap_screenshot.sh [udid] [out-dir]
#
# Defaults to the iPhone 17 Pro Max simulator, which renders at 1320x2868 —
# well above the 640x920 minimum App Store Connect accepts in an in-app
# purchase's Review Screenshot field. One image covers all three products:
# they share a screen, and Apple's requirement is that the picture shows where
# the purchase appears.
#
# Unlike tool/make_screenshots.sh this does NOT erase the simulator and does
# NOT derive a second size. There is no seed data to control — the support
# screen shows the same thing on an empty install as on a full one — and this
# asset never joins the listing gallery, so the 6.5-inch derivation that exists
# for Apple's listing cards is meaningless here.
set -euo pipefail
cd "$(dirname "$0")/.."

UDID="${1:-$(xcrun simctl list devices available | awk -F'[()]' '/iPhone 17 Pro Max/{print $2; exit}')}"
OUT="${2:-store/screenshots/iap-review}"
[ -n "$UDID" ] || { echo "no iPhone 17 Pro Max simulator found"; exit 1; }

echo "==> simulator $UDID -> $OUT"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

# The same convention the listing shots use: a review screenshot should not
# advertise 23% battery and a 14:37 clock.
xcrun simctl status_bar "$UDID" override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

mkdir -p "$OUT"
rm -f "$OUT"/*.png

# The device process cannot spawn xcrun, so it asks the host for the shot.
tool/l10n_screenshot_watcher.sh ios "$UDID" "$OUT" "" 300 &
WATCHER=$!
trap 'kill $WATCHER 2>/dev/null || true' EXIT

flutter test integration_test/iap_screenshot_test.dart -d "$UDID"

kill $WATCHER 2>/dev/null || true
trap - EXIT

echo "==> captured:"
for f in "$OUT"/*.png; do
  printf '  %s  %s\n' "$(basename "$f")" \
    "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2}')"
done
