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

## Release signing (Android)

Release builds are signed with an upload key that is **not** in this
repository. `android/key.properties` points at it and is gitignored, as are
`**/*.jks` and `**/*.keystore`:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/vitomy-upload-keystore.jks
```

Without that file a release build fails with a message saying so. It does not
fall back to the debug keystore — that key ships with the Flutter SDK, so a
release signed with it can be impersonated by anyone.
`test/platform_config_test.dart` asserts all of this.

Google Play holds the app signing key; the file above is only the *upload*
key, and Google can reset it if it is lost. Back it up anyway.

## Store assets

```sh
python3 tool/make_icons.py          # every icon size, both platforms
python3 tool/make_icons.py 3a       # ...in the other approved colourway
tool/make_screenshots.sh            # listing screenshots from a 6.9" simulator
```

Both write generated files. Re-run a script rather than editing a PNG.
Listing copy for both consoles is in `store/listing.md`.

## Where the rules live

`.claude/CLAUDE.md` carries the conventions and architecture. Anything
user-visible goes through the `vitomy-design` skill first.
