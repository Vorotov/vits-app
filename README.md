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

## Apple keys

Two different things that are easy to confuse.

The **RevenueCat SDK key** in `lib/core/purchases/revenuecat_key.dart` is
public by design: it is compiled into every binary the store distributes, and
the vendor documents embedding it. It is committed.

The **App Store Connect and In-App Purchase keys** are real secrets, they live
in `~/keys/` and `~/.appstoreconnect/private_keys/`, and `*.p8` is gitignored
at the repository root. Apple allows a `.p8` to be downloaded exactly once, so
a committed one cannot be rotated quietly.

## Store assets

```sh
python3 tool/make_icons.py          # every icon size, both platforms
python3 tool/make_icons.py 3a       # ...in the other approved colourway
tool/make_screenshots.sh            # listing screenshots from a 6.9" simulator
tool/make_iap_screenshot.sh         # the review screenshot each in-app purchase needs
```

Both write generated files. Re-run a script rather than editing a PNG.
Listing copy for both consoles is in `store/listing.md`.

## Where the rules live

`.claude/CLAUDE.md` carries the conventions and architecture. Anything
user-visible goes through the `vitomy-design` skill first.
