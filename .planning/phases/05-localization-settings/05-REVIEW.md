---
phase: 05-localization-settings
reviewed: 2026-08-16T04:18:54Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - l10n.yaml
  - .gitignore
  - lib/main.dart
  - lib/core/providers.dart
  - lib/core/l10n/locale_controller.dart
  - lib/core/l10n/arb/app_en.arb
  - lib/core/l10n/arb/app_uk.arb
  - lib/features/settings/settings_screen.dart
  - lib/features/settings/language_picker.dart
  - lib/features/calendar/calendar_screen.dart
  - lib/features/calendar/planner_screen.dart
  - lib/features/stack/stack_screen.dart
  - lib/features/stack/add_supplement_sheet.dart
  - lib/features/stack/regimen_editor_screen.dart
  - test/features/settings_screen_test.dart
  - test/l10n/new_language_contract_test.dart
  - test/l10n/no_hardcoded_strings_test.dart
  - test/l10n/arb_parity_test.dart
  - test/l10n/locale_resolution_test.dart
  - test/l10n/locale_controller_test.dart
  - test/support/locale_matrix.dart
findings:
  critical: 2
  warning: 6
  info: 7
  total: 15
status: issues_found
fix_applied: 2026-08-16
fix_report: .planning/phases/05-localization-settings/05-REVIEW-FIX.md
fixed:
  critical: 2
  warning: 6
  info: 0
remaining:
  info: 7
---

# Phase 5: Code Review Report

**Reviewed:** 2026-08-16T04:18:54Z
**Depth:** standard
**Files Reviewed:** 13 source files (+8 test files read for gate quality)
**Status:** issues_found

## Summary

Phase 5 ships the locale pipeline (derived synchronous `LocaleController`, async
`main()` bootstrap, settings screen + language picker), the A1 "has an error
beats is loading" fix at three async surfaces, the A2 semantics key, A3 sentence
casing, two text-scale overflow fixes, and five new test gates.

Baseline reproduced independently: `flutter analyze` clean, `flutter test`
676/676 green.

The phase's own headline claim — that the stored language override is
sanitized untrusted input that "can never crash locale resolution" — is
**false**, and provably so: the sanitization validates the *value* but not its
*type*, and a non-`String` value under `app_locale` throws a cast error inside
`LocaleController.build()` at root-widget build time. I confirmed this by
running a throwaway probe against the real controller (probe deleted; no source
files were modified). The second boot-path defect is the same shape at a
different layer: `main()` awaits `SharedPreferences.getInstance()` with no
guard, so any store failure means `runApp` is never reached and the app is a
permanent blank screen.

Beyond the two boot-path defects, the A1 fix is applied unevenly: it is
load-bearing in the calendar and planner, **inert** in the Stack screen (the
value it operates on can never be in a "reloading" state), and **not applied at
all** in the composition inside `stackEntriesProvider`, where the outer loading
arm still discards an error from the second stream. The A3 casing decision was
applied to exactly one of five sites — four `toUpperCase()` calls on
locale-formatted strings survive, two of them documented as "locale-aware
uppercasing", which Dart's `String.toUpperCase()` is not.

The new gates are unusually good by repo standards (glob proofs, derived
expectations, named allowlists). The defects in them are narrower: two of them
pass vacuously in a plausible environment, and two allowlist entries are keyed
on the enclosing constructor rather than on the argument, which is wider than
their rationales claim.

## Critical Issues

### CR-01: A tampered or wrong-typed `app_locale` value crashes the app at launch

**Status:** FIXED in `eb2b837` — `build()` reads `get` (Object?) and type-tests
before the membership check; regression test covers int/bool/double/List.

**File:** `lib/core/l10n/locale_controller.dart:31`
**Issue:** `SharedPreferences.getString` is implemented as
`_preferenceCache[key] as String?` (shared_preferences 2.5.x,
`shared_preferences_legacy.dart:129`). It is an unguarded downcast: any value
stored under `app_locale` that is not a `String` throws a `TypeError` *before*
the `supportedLanguageCodes` check the file's own comment presents as the
sanitization boundary against "SharedPreferences ... edited outside the app
(rooted device, backup edit)" (T-01-07 / T-05-01 / T-05-02).

The throw happens inside `LocaleController.build()`, which is watched by
`BoostqueApp.build` (`main.dart:42`) — i.e. the root widget. The provider enters
a permanent error state, the root build throws, and nothing in the app can
invalidate it. On a real device this is a bricked launch that survives restarts,
not a cosmetic fallback.

Verified by direct probe against the real controller:

```
PROBE RESULT bool thrown=ProviderException: Tried to use a provider that is in error state.
type 'bool' is not a subtype of type 'String?' in type cast
#0 SharedPreferences.getString (package:shared_preferences/src/shared_preferences_legacy.dart:129:58)
#1 LocaleController.build (package:boostque/core/l10n/locale_controller.dart:31:55)
```

Both `{'app_locale': 7}` and `{'app_locale': true}` reproduce it. The existing
tests only cover wrong *values* (`'de'`, `'zz'`), never a wrong *type*, so the
suite is green on a contract it does not test.

**Fix:** read the raw value and type-test it, so the untrusted input is
sanitized on type as well as membership:

```dart
@override
Locale? build() {
  // `get` returns Object? — `getString` is an unguarded `as String?` downcast,
  // and a non-String value under this key would throw here at root-build time.
  final stored = ref.watch(sharedPreferencesProvider).get(_prefsKey);
  final code = stored is String ? stored : null;
  return (code != null && supportedLanguageCodes.contains(code))
      ? Locale(code)
      : null;
}
```

Add the missing case to `test/l10n/locale_controller_test.dart` alongside the
`'de'`/`'zz'` cases: `makeContainer({'app_locale': 7})` must return `null`, not
throw.

### CR-02: An unguarded `SharedPreferences.getInstance()` in `main()` can leave the app permanently blank

**Status:** FIXED in `18d85c9` — `sharedPreferencesProvider` is nullable, `main()`
catches and reports, the controller reads through `?.` and no-ops the write;
new gate `test/l10n/cold_start_degradation_test.dart` drives the real `main()`
against a broken store.

**File:** `lib/main.dart:16`
**Issue:** `final prefs = await SharedPreferences.getInstance();` sits between
`ensureInitialized()` and `runApp()` with no `try`/`catch`. If it throws —
plugin registration failure, a corrupted prefs XML/plist, an OEM storage
permission failure — `main()` completes with an error, `runApp` is never called,
no Flutter UI is ever attached, and the user sees the launch screen or a black
window forever. It is deterministic, so restarting does not help; there is no
error surface and no telemetry.

The disproportionality is the point: the *only* thing this store carries is one
cosmetic language override (per the stack doc, "exactly one use in this app").
An app whose entire local-first database is healthy is prevented from starting
because a preference could not be read.

**Fix:** degrade to "follow system" instead of not starting. Make the provider
nullable so a missing store is representable:

```dart
// providers.dart
final sharedPreferencesProvider = Provider<SharedPreferences?>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider is overridden in main() and in tests',
  ),
);

// main.dart
WidgetsFlutterBinding.ensureInitialized();
SharedPreferences? prefs;
try {
  prefs = await SharedPreferences.getInstance();
} catch (error, stack) {
  // The store carries one cosmetic key; losing it must not cost the launch.
  FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
}
runApp(ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: const BoostqueApp(),
));

// locale_controller.dart build()
final stored = ref.watch(sharedPreferencesProvider)?.get(_prefsKey);
```

`setLocale` then no-ops on a null store, which is already the documented
DECIDED-8 behaviour for a failed write.

## Warnings

### WR-01: `stackEntriesProvider` still drops an error when the other stream is loading

**Status:** FIXED in `049f87b` — the composition is now an explicit precedence
(error, then value, then loading) across BOTH sources; regression test in both
locales errors the regimen stream during the supplement stream's first load.

**File:** `lib/core/providers.dart:181-191`
**Issue:** The A1 rule ("has an error beats is loading") is applied *inside*
each `when`, but not *between* them. The outer `supplements.when(...)` evaluates
first, and its `loading:` arm returns `const AsyncLoading()` — discarding
whatever state `regimens` is in. So while `supplementsStreamProvider` is in a
genuine first load (no previous value, so `skipLoadingOnReload` cannot help) and
`regimensStreamProvider` has already failed, every downstream surface (Stack
directly, planner via `whenData` → `_surface`) renders the blank loading
surface and the designed error surface is unreachable. Riverpod 3's error
back-off means the failing stream can sit there for the whole ~38.2s window.
This is the exact defect class 04-REVIEW CR-02 and Amendment A1 exist to close,
one layer above where the fix was applied.

**Fix:** check both sources for an error before composing:

```dart
final stackEntriesProvider = Provider<AsyncValue<List<StackEntry>>>((ref) {
  final supplements = ref.watch(supplementsStreamProvider);
  final regimens = ref.watch(regimensStreamProvider);
  // A1 at the COMPOSITION too: an error in either source outranks a loading
  // state in the other, whichever one is evaluated first.
  if (supplements.hasError) {
    return AsyncError(supplements.error!, supplements.stackTrace!);
  }
  if (regimens.hasError) {
    return AsyncError(regimens.error!, regimens.stackTrace!);
  }
  if (supplements.isLoading || regimens.isLoading) return const AsyncLoading();
  return AsyncData(
    combineStackEntries(supplements.requireValue, regimens.requireValue),
  );
});
```

Add a test that errors `regimensStreamProvider` while `supplementsStreamProvider`
has not yet emitted, and asserts the Stack error copy renders.

### WR-02: The A1 flag added to the Stack screen is inert, and its comment says otherwise

**Status:** FIXED in `6f38a5a` — the preferred option was taken: the screen now
uses the planner's `switch` on `hasError`, and the comment states what actually
protects the surface (both layers hold independently).

**File:** `lib/features/stack/stack_screen.dart:103-111`
**Issue:** `entries` comes from `stackEntriesProvider`, a plain
`Provider<AsyncValue<...>>` whose four return paths each construct a *fresh*
`AsyncData` / `const AsyncLoading()` / `AsyncError` with no previous state
attached. `skipLoadingOnReload` is only consulted when `isReloading` is true, and
`isReloading => _hasState && isLoading && this is AsyncLoading`
(`riverpod-3.4.2/lib/src/core/async_value.dart:97`) — a freshly constructed
`const AsyncLoading()` has no state and is never loading-with-previous. So the
argument can never change the outcome here: the Stack's error surface is
reachable solely because of the `skipLoadingOnReload` arguments inside
`providers.dart:181-191`.

The eight-line comment above it asserts the opposite ("without this the designed
error surface below is unreachable ... and the body renders blank"). That is
false confidence in the most literal sense: a future contributor who removes the
provider-level flags will read this comment as proof the screen is still
protected, and the retry-window test will go red pointing at the wrong file.
(By contrast, the same flag in `calendar_screen.dart:319` *is* load-bearing —
`widget.doses` is a `StreamProvider` value that genuinely carries previous
state — and the planner's `AsyncValue(hasError: true)` pattern in
`planner_screen.dart:618` is correct as written.)

**Fix:** either drop the argument and rewrite the comment to point at the real
protection, or (preferred, and consistent with the planner) make the screen
robust on its own terms so both layers hold independently:

```dart
...switch (entries) {
  AsyncValue(hasError: true) => <Widget>[/* error copy + retry */],
  AsyncData(:final value) => /* list or empty state */,
  _ => const <Widget>[],
},
```

### WR-03: A3 was applied to one casing site; four locale-independent `toUpperCase()` calls survive, two documented as "locale-aware"

**Status:** FIXED in `6b5a0dd` — new `lib/core/l10n/casing.dart` holds
`bqUpperCase(value, locale)` (default Unicode mapping + the documented tr/az
dotted-i exception); all four sites call it and both false comments are
corrected. `test/l10n/casing_test.dart` pins both branches.

**Files:** `lib/features/calendar/week_strip.dart:278`,
`lib/features/calendar/planner_gantt.dart:155`,
`lib/features/calendar/planner_year_grid.dart:163`,
`lib/features/calendar/planner_month_detail.dart:118-120`
**Issue:** Amendment A3 replaced `_capitalizeFirst` in `calendar_screen.dart`
with `toBeginningOfSentenceCase(value, locale)` precisely because Dart's default
Unicode casing is wrong for tr/az (`i` → `I` instead of `İ`), and the settings
screen's header comment claims the phase "side-steps locale-independent casing
entirely (PF-6)". Four sites still call `String.toUpperCase()` directly on
intl-formatted month and weekday output — the same input, the same defect, the
same "fourth ARB file" failure mode A3 names.

Worse, two of them carry the comment *"Locale-aware uppercasing of intl output"*
(`planner_gantt.dart:153-155`, `planner_month_detail.dart:116-118`). Dart has no
locale-aware `toUpperCase`; `intl` ships no `toLocaleUpperCase`. Only the
*formatting* is locale-aware — the casing is not, and the comment will stop a
reviewer from looking twice.

**Fix:** give uppercasing ONE definition, the way A3 gave sentence casing one,
and correct the two comments:

```dart
// lib/core/l10n/casing.dart
/// Uppercases intl output with the one locale exception Dart's default
/// Unicode mapping gets wrong (the Turkish/Azeri dotted i), mirroring what
/// intl's toBeginningOfSentenceCase does for sentence case (A3 / PF-6).
String bqUpperCase(String value, String locale) {
  if (locale.startsWith('tr') || locale.startsWith('az')) {
    return value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }
  return value.toUpperCase();
}
```

and replace all four call sites with `bqUpperCase(format.format(...), locale)`.
All four sites already have the active `locale` string in scope.

### WR-04: The language-change write is a discarded future — a failed write is *not* silent, it is an unhandled async error

**Status:** FIXED in `7bb0464` — the controller try/catches both failure shapes
(a throw AND a `false` return) and reports them to `FlutterError`; the call site
says `unawaited(...)`. Two regression tests over a write-refusing store.

**File:** `lib/features/settings/language_picker.dart:70-71`
(with `lib/core/l10n/locale_controller.dart:46-59`)
**Issue:** `onTap: () => ref.read(localeControllerProvider.notifier).setLocale(locale)`
discards the returned `Future<void>`. `setLocale` awaits
`prefs.setString`/`prefs.remove`, either of which can throw (`PlatformException`
on a full or read-only store, a channel failure). Because nothing awaits or
catches it, the failure becomes an unhandled error in the root zone —
reported through `PlatformDispatcher.onError`/`FlutterError`, printed, and in
any test that happens to be pumping, an outright test failure. DECIDED-8 says
the failed write is *deliberately silent*; the implementation does not deliver
that, it delivers an uncaught async error. `setString`'s `bool` return (which
is `false` on a rejected write) is also dropped.

Note that the fix cannot live at the call site: the phase's own gate
(`settings_screen_test.dart:743-754`) forbids the substrings `Error`, `catch (`
and `onError` anywhere under `lib/features/settings/`. Put it in the controller,
which the gate does not cover.

**Fix:**

```dart
Future<void> setLocale(Locale? locale) async {
  state = locale;
  final prefs = ref.read(sharedPreferencesProvider);
  try {
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  } catch (error, stack) {
    // DECIDED-8: a failed write costs the NEXT launch only and is deliberately
    // not surfaced — but it must be SWALLOWED here, not left to the zone.
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  }
}
```

and mark the call site explicitly fire-and-forget with `unawaited(...)`
(`dart:async`) so the intent is readable rather than accidental.

### WR-05: Locale identity is collapsed to `languageCode` in three places, so a country-qualified ARB breaks the picker's core invariant

**Status:** FIXED in `fbdfcf0` — the first option was taken (full locale
identity, not the ARB-regex tightening): `supportedLanguageCodes` became a
tag→`Locale` map (`supportedLocaleTags`), `build()` returns the generated
instance, `setLocale` persists `toLanguageTag()`, the picker compares whole
locales. Existing `uk`/`en` values are byte-identical, so no migration.

**Files:** `lib/core/l10n/locale_controller.dart:23-25,40-41,57`,
`lib/features/settings/language_picker.dart:67`
**Issue:** The shipped-language set is `{locale.languageCode}`, the persisted
value is `locale.languageCode`, and the picker's selection test is
`locale?.languageCode == current?.languageCode`. The phase's own ARB file
pattern explicitly admits region-qualified files
(`app_<code>.arb` where code is `[a-z]{2,3}(?:_[A-Za-z]+)?`, both
`new_language_contract_test.dart:52` and `arb_parity_test.dart:38`), and
criterion 4 promises "adding a new language requires only one new ARB file".

Drop in `app_pt.arb` and `app_pt_BR.arb` and three things break at once:
`supportedLanguageCodes` collapses both to `'pt'`; selecting Brazilian
Portuguese persists `'pt'` and restores as `Locale('pt')` on the next launch
(the user's choice is silently downgraded); and the picker checks **two** rows
simultaneously, which makes `inMutuallyExclusiveGroup` a lie to assistive tech
and breaks the "exactly one row is checked at all times" invariant the class
doc asserts.

Mitigation that exists today: `new_language_contract_test.dart:158-169` compares
`LocaleController.supportedLanguageCodes` against the raw ARB codes, so this
fails loudly rather than silently. That makes it a design defect rather than a
latent crash — but the documented contract is still wrong as written.

**Fix:** key on the full locale rather than on the language subtag —
`Set<Locale>` derived from `supportedLocales`, persist `locale.toLanguageTag()`,
and compare `locale == current` in the picker. Or, if regional variants are
genuinely out of scope for v1, say so in the class doc and tighten the ARB
regexes in both gates to `[a-z]{2,3}` so the unsupported case cannot land
unnoticed.

### WR-06: The A1 flag silently disables the `IgnorePointer` hold on a same-day reload

**Status:** FIXED in `5554d17` — the behaviour was restored rather than the
comment rewritten: the body matches `hasError`, then data-and-settled, then
held-and-inert for EVERY loading shape. Regression test taps a held row during
a regimen-triggered reload and asserts the log stays pending.

**File:** `lib/features/calendar/calendar_screen.dart:310-350`
**Issue:** The comment states "the hold itself is unchanged: a genuine day
switch with no error still takes the loading arm" — true for a day switch (a new
family key is a new provider with no previous state). But `dayDosesProvider`
also rebuilds whenever `regimensStreamProvider` emits (`providers.dart:109`),
and *that* rebuild produces `AsyncLoading` **with** the previous value →
`isReloading` → with `skipLoadingOnReload: true` the `data:` arm now runs with
the stale list instead of the `loading:` arm.

Before this change that window rendered the held rows wrapped in an
`IgnorePointer` (the WR-01 guard from Phase 4); now it renders them live and
tappable. A tap in that window targets a `logId` from a regimen that may have
just been deleted or paused — the very thing the guard was added for, on a
narrower path. The behaviour may be acceptable, but it is undocumented and the
comment claims it does not happen.

**Fix:** keep the error precedence without losing the guard — match on the
property instead of relying on arm ordering, the way the planner does:

```dart
...switch (widget.doses) {
  AsyncValue(hasError: true) => <Widget>[/* error copy + retry */],
  AsyncData(:final value) when !widget.doses.isLoading => /* fresh: data arm */,
  _ => /* held rows, IgnorePointer-wrapped, as before */,
},
```

or leave the current shape and replace the comment with what actually happens.

## Info

**None of the Info findings below were fixed** — they were deliberately left out
of the fix scope (`05-REVIEW-FIX.md`) and remain open as documented. IN-03's
narrowing advice was partially honoured in spirit by the two allowlist entries
added during the fixes, both of which are scoped to a file or a constructor
rather than opened wide.

### IN-01: The sanitization allowlist is a public **mutable** `Set`

**File:** `lib/core/l10n/locale_controller.dart:23-25`
**Issue:** `static final Set<String> supportedLanguageCodes = {...}` is the
documented security boundary for untrusted stored input, yet it is a plain
mutable set exposed on a public API. Any code (or a future test helper) can
`LocaleController.supportedLanguageCodes.add('de')` and defeat the check
process-wide.
**Fix:** `static final Set<String> supportedLanguageCodes = Set.unmodifiable({...});`
— the existing equality assertions in both gate tests keep passing.

### IN-02: The PF-4 and numeral gates only run over `features/`

**File:** `test/l10n/no_hardcoded_strings_test.dart:581,603,631`
**Issue:** Gates 3 (`initState`/`late final` caching a formatter or `l10n`) and
4 (`.toString()` inside `Text(`) each open with
`if (!path.contains('features/')) return;`, so everything under `lib/core/`
— including the shared widgets in `core/theme` and `core/widgets` — is exempt
from the stale-language and unformatted-numeral checks. The file header claims
the scope is "`lib/` only", which reads as *all* of `lib/`.
**Fix:** drop the two early returns (or narrow them to
`core/l10n/gen`, already excluded from the glob) and state the real scope in the
header.

### IN-03: Two allowlist entries are keyed on the enclosing call, not on the argument

**File:** `test/l10n/no_hardcoded_strings_test.dart:341-350,398-419`
**Issue:** `_isStableDomainId` allows *any* translatable literal appearing
anywhere in a `CatalogEntry(...)`, `_LegendEntry(...)`, `Regimen(...)` or
`driftDatabase(...)` argument list — including a user-visible display name
placed next to the opaque id it was meant to bless. `_isLocaleTag` likewise
allows any literal inside `Locale(...)` anywhere in `lib/`, so a new
`Locale('uk')` hardcoded into a screen passes both gates even though "no
hardcoded language code" is exactly what criterion 4 forbids. The single site
the rationale describes is `lib/features/stack/catalog.dart:158`
(`lookupAppLocalizations(const Locale('en'))`), which is also a latent throw if
`app_en.arb` is ever renamed.
**Fix:** narrow both to the argument, not the call — e.g. require
`l.precedingNamedArg == 'id'` (or a positional-index check) for domain ids, and
scope the `Locale` entry to the one file that needs it
(`l.path.endsWith('catalog.dart')`).

### IN-04: The untranslated-messages gate passes vacuously when the report is missing

**File:** `test/l10n/new_language_contract_test.dart:267-272`
**Issue:** Two silent early returns (`if (!report.existsSync()) return;` and
`if (raw.isEmpty) return;`) mean the gate asserts nothing whenever
`l10n-untranslated.json` is absent — and the same phase gitignored that file, so
it is absent on every fresh clone. It happens to be regenerated because
`pubspec.yaml` sets `generate: true`, but the gate has no way to tell "clean" from
"never generated": any runner that skips gen-l10n turns this into a green no-op.
**Fix:** assert the report exists after generation (`expect(report.existsSync(),
isTrue, reason: 'flutter gen-l10n did not run — this gate cannot see a missing
translation')`) and treat only a `{}` payload as clean.

### IN-05: ARB parity does not check placeholders or catch untranslated copy-paste

**File:** `test/l10n/arb_parity_test.dart:145-173`
**Issue:** Parity is asserted on the key *set* and on plural categories only. A
non-template ARB whose value drops a placeholder, or whose value is byte-identical
to the English template (a copy-paste that never got translated), passes every
gate in the file. `stackSummary`, `weekLoadLabel` and the new
`addSupplementCatalogSemantics` all carry multiple placeholders, so a dropped one
is a silently missing number on screen.
**Fix:** extract `{name}` tokens from each value and assert set equality against
the template's value, and report (not necessarily fail) any non-template message
identical to the template that is not a pure-placeholder string.

### IN-06: The Cyrillic-leak sweep never looks at Semantics labels

**File:** `test/support/locale_matrix.dart:69-79`
**Issue:** `expectNoCyrillicWhileEn` iterates `tester.widgetList<Text>` only. A
literal that escapes the ARB into a `Semantics(label: ...)` — precisely the
surface Amendment A2 changed in `add_supplement_sheet.dart:356` — renders to
assistive tech in the wrong language and is invisible to this sweep, whose
rationale claims it catches "the failure mode grep cannot see".
**Fix:** also walk the semantics tree
(`tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode`) or at minimum
sweep `tester.widgetList<Semantics>(...).map((s) => s.properties.label)`.

### IN-07: Locale resolution is proven against a synthetic app, not against `BoostqueApp`

**File:** `test/l10n/locale_resolution_test.dart:48-54`
**Issue:** `resolvingApp()` builds its own `MaterialApp` mirroring the root
widget's configuration. Its header argues the app deliberately has no
`localeResolutionCallback` and that "the absence deserves a test" — but the test
cannot see the real root, so a callback added to `BoostqueApp` tomorrow leaves
every case in this file green. The one file where resolution is asserted through
the actual root (`settings_screen_test.dart`) always pins `locale:` explicitly.
**Fix:** pump `BoostqueApp` inside a `ProviderScope` with the prefs and db
overrides (the `appScope` helper already exists in `settings_screen_test.dart`)
and set `platformDispatcher.localesTestValue`, so the assertions run against the
widget that actually ships.

---

_Reviewed: 2026-08-16T04:18:54Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
