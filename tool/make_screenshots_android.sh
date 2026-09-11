#!/bin/bash
# Captures the Google Play phone screenshots from the REAL app on an Android
# emulator, the way tool/make_screenshots.sh does for iOS.
#
#   tool/make_screenshots_android.sh [emulator-id] [out-dir]
#
# Play's phone screenshots must be 16:9 or 9:16 with each side between 320 and
# 3840 px, and no side more than twice the other — which rules out every modern
# phone profile (a Pixel 7 is 1080x2400, 2.22:1). So the capture runs on the
# `play_shots` AVD, a 1080x1920 @ 420 dpi profile (exactly 9:16, and above the
# 1080 px minimum Play wants for promotion eligibility). Boot it first:
#
#   emulator -avd play_shots -wipe-data -no-snapshot -no-boot-anim -no-audio -gpu swiftshader_indirect
#
# The script clears the app's data before seeding (`pm clear`), so a rerun on a
# booted emulator is fine; -wipe-data is only needed for a fresh system state.
#
# Creating the AVD is a one-time step per machine. `avdmanager` needs Java,
# which is not on PATH here; Android Studio's bundled JBR at
# /Applications/Android Studio.app/Contents/jbr/Contents/Home works as
# JAVA_HOME if it is present. The shortcut that worked: copy an existing AVD's
# config.ini and its sibling .ini under ~/.android/avd/ to play_shots, then set
#
#   AvdId=play_shots
#   avd.ini.displayname=play_shots
#   hw.device.name=pixel_2
#   hw.lcd.width=1080
#   hw.lcd.height=1920
#   hw.lcd.density=420
#   skin.name=1080x1920
#   skin.path=_no_skin
#
# and boot it with
#
#   emulator -avd play_shots -wipe-data -no-snapshot -no-boot-anim -no-audio -gpu swiftshader_indirect
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"

DEV="${1:-$(adb devices | awk '/emulator-[0-9]+\tdevice$/{print $1; exit}')}"
OUT="${2:-store/screenshots/android-phone}"
[ -n "$DEV" ] || { echo "no booted emulator found"; exit 1; }

SIZE=$(adb -s "$DEV" shell wm size | tr -d '\r' | awk '{print $NF}')
[ "$SIZE" = "1080x1920" ] || { echo "emulator $DEV is $SIZE, not 1080x1920 — boot the play_shots AVD"; exit 1; }

# The Android counterpart of the iOS 09:41 status bar: SystemUI demo mode.
# wifi and mobile share the `level` key, so they are separate commands; mobile
# is hidden outright (an emulator's "3G" and empty triangle are not a phone).
adb -s "$DEV" shell settings put global sysui_demo_allowed 1
for c in "enter" "clock -e hhmm 0941" "battery -e level 100 -e plugged false" \
         "network -e wifi show -e level 4 -e fully true" \
         "network -e mobile hide" "network -e airplane hide" \
         "notifications -e visible false"; do
  adb -s "$DEV" shell am broadcast -a com.android.systemui.demo -e command $c >/dev/null
done

# Same reason the iOS script erases its simulator: the test seeds the real
# database, and a second run over the first would show ten supplements.
adb -s "$DEV" shell pm clear app.vitomy >/dev/null 2>&1 || true

mkdir -p "$OUT"
rm -f "$OUT"/*.png

# The device process cannot spawn adb, so it asks the host for each shot.
tool/l10n_screenshot_watcher.sh android "$DEV" "$OUT" "" 900 &
WATCHER=$!
trap 'kill $WATCHER 2>/dev/null || true' EXIT

flutter test integration_test/store_screenshots_test.dart -d "$DEV"

kill $WATCHER 2>/dev/null || true
trap - EXIT
adb -s "$DEV" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null || true

# `screencap -p` writes RGBA; Play accepts only 24-bit PNG (no alpha). Flatten
# in place. PIL is already a dependency of tool/make_icons.py.
python3 - "$OUT" <<'PY'
import pathlib, sys
from PIL import Image
for p in sorted(pathlib.Path(sys.argv[1]).glob('*.png')):
    im = Image.open(p)
    if im.mode != 'RGB':
        im.convert('RGB').save(p, 'PNG', optimize=True)
PY
echo "==> captured:"
for f in "$OUT"/*.png; do
  printf '  %s  %s\n' "$(basename "$f")" \
    "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2}')"
done
