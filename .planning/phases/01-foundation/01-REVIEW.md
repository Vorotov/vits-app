---
phase: 01-foundation
reviewed: 2026-08-14T18:26:56Z
depth: standard
files_reviewed: 20
files_reviewed_list:
  - lib/main.dart
  - lib/app_shell.dart
  - lib/features/stack/stack_screen.dart
  - lib/features/calendar/calendar_screen.dart
  - lib/features/settings/settings_screen.dart
  - lib/core/domain/models.dart
  - lib/core/domain/cycle_math.dart
  - lib/core/domain/repositories.dart
  - lib/core/theme/tokens.dart
  - lib/core/theme/theme.dart
  - lib/core/l10n/l10n.dart
  - lib/core/l10n/locale_controller.dart
  - lib/core/l10n/arb/app_en.arb
  - lib/core/l10n/arb/app_uk.arb
  - lib/core/db/database.dart
  - lib/core/db/drift_repositories.dart
  - lib/core/providers.dart
  - pubspec.yaml
  - build.yaml
  - l10n.yaml
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-08-14T18:26:56Z
**Depth:** standard
**Files Reviewed:** 20
**Status:** issues_found

## Summary

Reviewed all Phase 1 foundation source files: app shell, domain layer (models + cycle math), Drift schema + repositories, Riverpod provider graph, theme/tokens, i18n infrastructure, and build config. `flutter analyze` is clean (0 issues) and `flutter test` passes all 79 tests, including the DST-transition and year-boundary cycle-math exemplars and the uk 4-form plural tests — this is objective evidence, not a substitute for the review below.

No BLOCKER/Critical issues found: no security vulnerabilities, no data-loss risks, no crashes were identified. The domain layer correctly implements UTC-only date math with no `DateTime.now()` calls; soft-delete and insert-or-ignore invariants are honored in the Drift repositories; ordering (`createdAt asc, id asc`) is applied consistently.

Three Warnings were found, all around silent architectural/config drift risk rather than currently-observable bugs: a locked project decision (do-not-hand-pin `intl`) was violated in `pubspec.yaml`; `DriftIntakeRepository.ensureLogsForDay` bypasses the `RegimenRepository` interface by directly instantiating the concrete `DriftRegimenRepository`; and `main.dart` hardcodes a `supportedLocales` list that duplicates (and could silently diverge from) the generated `AppLocalizations.supportedLocales`. Three Info-level items note code clarity/duplication opportunities.

## Warnings

### WR-01: `pubspec.yaml` hand-pins `intl`, violating the locked "do not hand-pin intl" decision

**File:** `pubspec.yaml:45`
**Issue:** `01-CONTEXT.md` and `.planning/research/STACK.md` both explicitly lock the decision "do NOT hand-pin `intl` (let `flutter_localizations` resolve it)" — precisely because `flutter_localizations` (SDK) has historically pinned an *exact* `intl` version, and an app-level constraint that later disagrees with the SDK's pin produces a `pub get` version-solving failure on the next Flutter SDK upgrade (cited as a recurring, confusing failure mode in flutter/flutter#162568, #164688, #169591, #168903). `pubspec.yaml` currently declares:
```yaml
intl: ^0.20.3
```
This works today only because `^0.20.3` happens to be compatible with whatever `flutter_localizations` currently requires — but it reintroduces exactly the fragility the decision was written to avoid, and will silently bite on the next `flutter upgrade` rather than failing now while the reasoning is fresh.
**Fix:**
```yaml
# Before
intl: ^0.20.3

# After — remove the explicit constraint entirely, let flutter_localizations dictate it
intl:
```
Then re-run `flutter pub get` (not a manual edit) whenever the Flutter SDK is bumped, per the locked decision.

### WR-02: `DriftIntakeRepository.ensureLogsForDay` bypasses the `RegimenRepository` interface

**File:** `lib/core/db/drift_repositories.dart:222`
**Issue:** The project's architecture principle (D-22, restated in this file's own doc comment: "UI and state code depend exclusively on these interfaces") is that all consumers depend on the `SupplementRepository`/`RegimenRepository`/`IntakeRepository` interfaces, with Drift implementations wired in only via `core/providers.dart`. `DriftIntakeRepository.ensureLogsForDay` violates this internally:
```dart
final regimens = await DriftRegimenRepository(db).watchAll().first;
```
It directly constructs a concrete `DriftRegimenRepository` rather than depending on the `RegimenRepository` interface (injected via constructor, matching the pattern already used for `db` itself). This couples `IntakeRepository`'s materialization logic to the Drift implementation of regimens, makes it impossible to substitute a different `RegimenRepository` behind `IntakeRepository` (e.g. a caching or future sync-aware decorator) without also changing this file, and constructs a fresh repository object on every call for no benefit.
**Fix:**
```dart
class DriftIntakeRepository implements IntakeRepository {
  DriftIntakeRepository(this.db, this._regimens);

  final BoostqueDb db;
  final domain_repo.RegimenRepository _regimens; // inject via constructor

  Future<void> ensureLogsForDay(DateTime day) async {
    final utcDay = dateOnly(day);
    final now = DateTime.now().toUtc();
    final regimens = await _regimens.watchAll().first;
    // ...unchanged...
  }
}
```
Wire `_regimens` from `regimenRepoProvider` in `core/providers.dart` when constructing `DriftIntakeRepository`.

### WR-03: `main.dart` hardcodes `supportedLocales`, duplicating the generated source of truth

**File:** `lib/main.dart:28`
**Issue:**
```dart
supportedLocales: const [Locale('en'), Locale('uk')],
```
`AppLocalizations.supportedLocales` (generated by `gen-l10n`, already re-exported through `core/l10n/l10n.dart` which `main.dart` imports) is the canonical, ARB-file-derived list — and is already used correctly in `test/widget/app_shell_test.dart`. `main.dart` instead hardcodes its own copy. If a third ARB locale is added later, this list must be remembered and updated by hand in a second place; forgetting it produces a silent bug (the app's `AppLocalizations` delegate can localize the new language, but `MaterialApp.supportedLocales` won't offer it, so locale resolution silently falls back to English for that language) with no compiler or analyzer signal.
**Fix:**
```dart
supportedLocales: AppLocalizations.supportedLocales,
```

## Info

### IN-01: `combineStackEntries`'s reversed-iteration dedup trick is non-obvious and undocumented

**File:** `lib/core/domain/repositories.dart:101-103`
**Issue:**
```dart
final bySupplement = <String, Regimen>{
  for (final r in regimens.reversed) r.supplementId: r,
};
```
When more than one active `Regimen` exists for the same `supplementId` (not prevented anywhere in the schema or repository layer), this map-literal-with-reversed-iteration trick makes the *earliest-created* regimen win (later entries in the reversed iteration overwrite earlier ones, and the reversed order means the true-first regimen is written last). This happens to be consistent with `DriftRegimenRepository.findForSupplement`, which returns `regimens.first` from the same ascending-order list — but nothing states this intentionally, and a future refactor that "simplifies" this to `for (final r in regimens)` (the more natural-looking form) would silently flip the tiebreak to *latest*-wins with no test catching the regression (no test in `repositories_test.dart` or `providers_test.dart` exercises multiple regimens per supplement).
**Fix:** Make the intent explicit, e.g.:
```dart
final bySupplement = <String, Regimen>{};
for (final r in regimens) {
  bySupplement.putIfAbsent(r.supplementId, () => r); // first (earliest-created) regimen wins, matches findForSupplement
}
```
Consider also adding a test case with two regimens sharing a `supplementId` to lock in the intended tiebreak.

### IN-02: `LocaleController.build()` fires `_load()` without awaiting, leaving a narrow init race

**File:** `lib/core/l10n/locale_controller.dart:20-23`
**Issue:**
```dart
@override
Locale? build() {
  _load();
  return null; // null = follow system until the async load settles
}
```
`_load()` is fire-and-forget. If `setLocale()` were ever invoked before the pending `_load()` future resolves (e.g. from a very early settings interaction, or a future refactor that calls `setLocale` during app bootstrap), `_load()`'s `state = Locale(code)` assignment could run *after* and overwrite the user's just-set `state`, silently reverting their choice back to whatever was previously persisted. Currently unreachable in practice (settings UI doesn't exist yet in Phase 1), but worth hardening before Phase 5 wires up the language picker.
**Fix:** Guard against a stale write, e.g. track a monotonic load generation, or simply have `setLocale` short-circuit if a load is in flight and prefer the most recent write:
```dart
Future<void> setLocale(Locale? locale) async {
  final prefs = await SharedPreferences.getInstance();
  if (locale == null) {
    await prefs.remove(_prefsKey);
  } else {
    await prefs.setString(_prefsKey, locale.languageCode);
  }
  state = locale; // last writer wins regardless of in-flight _load()
}
```
(already true today for the write itself — the risk is specifically `_load()` resolving *after* a manual `setLocale`, which the current code doesn't guard against.)

### IN-03: Three near-identical stub-screen widgets duplicate the same 20-line boilerplate

**File:** `lib/features/stack/stack_screen.dart:8-29`, `lib/features/calendar/calendar_screen.dart:8-29`, `lib/features/settings/settings_screen.dart:8-29`
**Issue:** `StackScreen`, `CalendarScreen`, and `SettingsScreen` are byte-for-byte identical except for the localized string they read (`tabStack`/`tabCalendar`/`tabSettings`). This is likely intentional groundwork for Phase 2/3/5 to diverge, but as committed it's copy-pasted boilerplate.
**Fix:** Optional — a small shared `_StubHeading(String text)` widget in a private helper file would remove the duplication without affecting later phases, e.g.:
```dart
class StubHeading extends StatelessWidget {
  const StubHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: BqSpace.lg, end: BqSpace.lg, top: BqSpace.lg,
            ),
            child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
      );
}
```
Low priority — each screen will diverge substantially once its feature is built, so this duplication is short-lived.

---

_Reviewed: 2026-08-14T18:26:56Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
