#!/bin/bash
# Captures the store listing screenshots end to end, and derives the 6.5-inch
# set from them.
#
#   tool/make_screenshots.sh [udid] [out-dir]           capture, then derive
#   tool/make_screenshots.sh --derive-only [out-dir]    rebuild only the derived
#                                                       set from an existing capture
#
# Defaults to the iPhone 17 Pro Max simulator, which renders at 1320x2868 —
# the 6.9-inch size. App Store Connect's DEFAULT iPhone card, though, is the
# 6.5-inch Display (1284x2778 or 1242x2688), and it rejects 1320x2868 there;
# the 6.9-inch card is only reachable through "View All Sizes in Media
# Manager". So the 6.5-inch set is DERIVED from the 6.9-inch captures — resized
# to 1284 wide (2790 high; 2868 x 1284 / 1320 = 2789.8), then centre-cropped to
# 2778 (6px off top and bottom; the two aspect ratios differ by 0.4%) — rather
# than captured on a second simulator: Apple's own fallback for a missing
# 6.5-inch set is a scaled 6.9-inch image, so the derived set is what Apple
# would produce itself. --derive-only rebuilds just that set and touches no
# simulator.
#
# Capturing ERASES the simulator first. integration_test/store_screenshots_test.dart
# writes its seed stack into the device's real database, and a rerun over an
# existing one would show ten supplements instead of five.
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVE_ONLY=0
if [ "${1:-}" = "--derive-only" ]; then
  DERIVE_ONLY=1
  shift
  OUT="${1:-store/screenshots/ios-6.9}"
  compgen -G "$OUT/*.png" >/dev/null || { echo "no PNGs in $OUT to derive from"; exit 1; }
else
  UDID="${1:-$(xcrun simctl list devices available | awk -F'[()]' '/iPhone 17 Pro Max/{print $2; exit}')}"
  OUT="${2:-store/screenshots/ios-6.9}"
  [ -n "$UDID" ] || { echo "no iPhone 17 Pro Max simulator found"; exit 1; }
fi

if [ "$DERIVE_ONLY" = 0 ]; then
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
fi

# The 6.5-inch set lives beside the 6.9-inch one. The guard matters: the rm
# below must never point at the captures.
if [[ "$OUT" == *ios-6.9* ]]; then
  DERIVED="${OUT/ios-6.9/ios-6.5}"
else
  DERIVED="${OUT%/}-6.5"
fi
[ "$DERIVED" != "$OUT" ] || { echo "derived folder would be the capture folder: $OUT"; exit 1; }

echo "==> deriving the 6.5-inch set -> $DERIVED"
mkdir -p "$DERIVED"
rm -f "$DERIVED"/*.png
for f in "$OUT"/*.png; do
  d="$DERIVED/$(basename "$f")"
  cp "$f" "$d"
  # sips takes HEIGHT then WIDTH — the trap. -z 2790 1284 is 1284 wide by 2790 high.
  sips -z 2790 1284 "$d" >/dev/null
  # Height first again: -c 2778 1284 is a centred crop to 1284x2778.
  sips -c 2778 1284 "$d" >/dev/null
done

report() {
  echo "==> $1 ($2):"
  for f in "$2"/*.png; do
    printf '  %s  %s\n' "$(basename "$f")" \
      "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2}')"
  done
}
report "captured 6.9-inch set" "$OUT"
report "derived 6.5-inch set" "$DERIVED"
