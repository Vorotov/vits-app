#!/bin/bash
# Host-side screenshot watcher for integration_test/data03_loop_test.dart.
# The test process runs on the device and cannot spawn xcrun, so it drops
# request files into its documents directory; this loop turns each one into a
# simctl screenshot and deletes the request so the test can continue.
UDID="${1:-FA55ED0D-2F18-4153-BCA5-8AE96B1E637E}"
OUT="${2:-$(cd "$(dirname "$0")/.." && pwd)/build/data03-screenshots}"
mkdir -p "$OUT"
DEV="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Containers/Data/Application"
END=$((SECONDS + ${3:-900}))
echo "watcher: watching $DEV for bq_shot_*.request"
while [ $SECONDS -lt $END ]; do
  for f in "$DEV"/*/Documents/bq_shot_*.request; do
    [ -e "$f" ] || continue
    base=$(basename "$f" .request)
    name=${base#bq_shot_}
    xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1
    echo "watcher: captured $name.png"
    if [ "$name" = "p3-ios-05-marked" ]; then
      # Out-of-process proof: dump the live on-device SQLite file from the host
      # while the app still holds the marks the test just wrote.
      db="$(dirname "$f")/boostque.sqlite"
      cp "$db" "$OUT/p3-ios-db-snapshot.sqlite" 2>/dev/null
      sqlite3 "$OUT/p3-ios-db-snapshot.sqlite" \
        "select s.name, r.kind, r.start_date, r.on_days, r.off_days from supplements s join regimens r on r.supplement_id = s.id;" \
        "select l.date, sl.minutes_from_midnight, l.status from intake_logs l join regimen_slots sl on sl.id = l.slot_id order by l.date, sl.minutes_from_midnight;" \
        > "$OUT/p3-ios-db-dump.txt" 2>&1
      echo "watcher: dumped device DB"
    fi
    rm -f "$f"
  done
  sleep 0.1
done
echo "watcher: done"
