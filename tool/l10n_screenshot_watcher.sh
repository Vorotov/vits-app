#!/bin/bash
# Host-side screenshot watcher for integration_test/l10n_device_test.dart.
#
# The test process runs on the device and cannot spawn xcrun/adb, so it drops
# bq_shot_<name>.request files into the app's documents directory; this loop
# turns each one into a screenshot named <prefix><name>.png and deletes the
# request so the test continues.
#
#   tool/l10n_screenshot_watcher.sh ios     <udid>          <out-dir> [prefix] [seconds]
#   tool/l10n_screenshot_watcher.sh android <emulator-id>   <out-dir> [prefix] [seconds]
#
# iOS reads the simulator's data container straight off disk. Android goes
# through `adb ... run-as app.vitomy`, which works because the
# integration-test build is debuggable.
set -u
PLATFORM="${1:?usage: $0 <ios|android> <device-id> <out-dir> [prefix] [seconds]}"
DEVICE="${2:?device id required}"
OUT="${3:?output directory required}"
PREFIX="${4:-}"
END=$((SECONDS + ${5:-900}))
PKG="app.vitomy"
mkdir -p "$OUT"
command -v adb >/dev/null 2>&1 || PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"

echo "watcher: $PLATFORM/$DEVICE -> $OUT (prefix '$PREFIX')"

if [ "$PLATFORM" = "ios" ]; then
  DEV="$HOME/Library/Developer/CoreSimulator/Devices/$DEVICE/data/Containers/Data/Application"
  while [ $SECONDS -lt $END ]; do
    for f in "$DEV"/*/Documents/bq_shot_*.request; do
      [ -e "$f" ] || continue
      base=$(basename "$f" .request)
      name=${base#bq_shot_}
      xcrun simctl io "$DEVICE" screenshot "$OUT/${PREFIX}${name}.png" >/dev/null 2>&1
      echo "watcher: captured ${PREFIX}${name}.png"
      rm -f "$f"
    done
    sleep 0.1
  done
else
  DIR="app_flutter"
  while [ $SECONDS -lt $END ]; do
    # `ls -1`, never bare `ls`: toybox's ls columnises when it is not a tty,
    # which puts several names on one line and defeats the per-line match.
    files=$(adb -s "$DEVICE" exec-out run-as "$PKG" ls -1 "$DIR" 2>/dev/null | tr -d '\r' | grep '^bq_shot_.*\.request$')
    for f in $files; do
      name=${f#bq_shot_}
      name=${name%.request}
      adb -s "$DEVICE" exec-out screencap -p > "$OUT/${PREFIX}${name}.png"
      echo "watcher: captured ${PREFIX}${name}.png"
      adb -s "$DEVICE" exec-out run-as "$PKG" rm "$DIR/$f" >/dev/null 2>&1
    done
    sleep 0.3
  done
fi
echo "watcher: done"
