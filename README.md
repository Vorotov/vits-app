# VitoMy

A planner and tracker for the supplements and vitamins you choose to take.
Flutter, iOS and Android, one codebase. Everything stays on the device: no
account, no server, no network client.

Bundle id `app.vitomy`. Seven languages ship (en, ar, es, fr, hi, uk, zh).

## Running it

```sh
flutter pub get
dart run build_runner build   # Drift only; Riverpod providers are hand-written
flutter run
```

## Tests

```sh
flutter test                  # the everyday suite
flutter test test_release/    # release-only gates; run before a store build
```

`flutter test` with no arguments reads `test/` only, so `test_release/` is a
deliberate second command, not an oversight. See `test_release/README.md`.

## Where the rules live

`.claude/CLAUDE.md` carries the conventions and architecture. Anything
user-visible goes through the `vitomy-design` skill first.
