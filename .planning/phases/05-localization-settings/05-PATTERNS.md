# Phase 5: Localization & Settings - Pattern Map

**Mapped:** 2026-08-16
**Files analyzed:** 17 new/modified
**Analogs found:** 14 / 17 (3 have no local analog — see "No Analog Found")

Source: `05-RESEARCH.md` (Architectural Responsibility Map, P-1..P-11, Validation Rules, Code Examples). No CONTEXT.md exists for this phase.

## File Classification

| New/Modified File | New? | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `l10n.yaml` | modify | config | build-time codegen | *(itself — 7 lines, quoted below)* | self |
| `lib/core/l10n/arb/app_en.arb` | modify | config (i18n template) | transform | existing keys + `@` metadata idiom (e.g. `weekLoadLabel`) | exact |
| `lib/core/l10n/arb/app_uk.arb` | modify | config (i18n) | transform | idem, no `@` blocks | exact |
| `lib/core/l10n/locale_controller.dart` | modify | store (Notifier) | event-driven + key-value I/O | *(itself — full text below)* | self |
| `lib/core/providers.dart` (add `sharedPreferencesProvider`) | modify | provider/config | request-response | `dbProvider` (`providers.dart:36-40`) | role-match |
| `lib/main.dart` | modify | app entrypoint | request-response | *(itself)* | self |
| `lib/features/settings/settings_screen.dart` | rewrite | screen | request-response | `stack_screen.dart:38-163` (header + ListView + eyebrow) | exact |
| `lib/features/settings/language_picker.dart` | **new** | component (list of choices) | event-driven | `dose_action_sheet.dart:123-148` (`_SheetAction` row) + `bq_segmented.dart:56-92` (selected semantics) | role-match |
| `lib/features/stack/stack_screen.dart` (P-9 fix) | modify | screen | request-response | *(itself :103-157)* | self |
| `lib/features/calendar/calendar_screen.dart` (P-9 fix) | modify | screen | request-response | *(itself :312-373)* | self |
| `lib/features/calendar/planner_screen.dart` (P-9 fix) | modify | screen | request-response | *(itself :601-614)* | self |
| `lib/features/calendar/calendar_screen.dart` (PF-6 `_capitalizeFirst`) | modify | utility | transform | `intl` `toBeginningOfSentenceCase` | no local analog |
| `test/l10n/new_language_contract_test.dart` | **new** | test (structural gate) | file-I/O + reflection-free glob | `planner_invariants_test.dart:79-133` (glob + non-empty assertion) + `planner_copy_safety_test.dart:14-20` (ARB off disk) | exact |
| `test/l10n/no_hardcoded_strings_test.dart` | **new** | test (source gate) | file-I/O | `planner_invariants_test.dart:82-133` (glob + `stripComments`) | exact |
| `test/l10n/locale_controller_test.dart` | modify | test (unit) | event-driven | *(itself)* | self |
| `test/features/settings_screen_test.dart` | **new** | test (widget) | request-response | `stack_screen_test.dart:35-60` harness + `planner_screen_test.dart:134-155` `plannerApp` | exact |
| `test/features/{stack,regimen_editor,calendar}_screen_test.dart`, `test/widget/app_shell_test.dart` (locale matrix) | modify | test (widget matrix) | request-response | `planner_screen_test.dart:2585-2618` | exact |

---

## Pattern Assignments

### `l10n.yaml` (config, build-time)

Current file, verbatim (7 lines, the whole file):
```yaml
arb-dir: lib/core/l10n/arb
template-arb-file: app_en.arb
output-dir: lib/core/l10n/gen
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false
nullable-getter: false
```
Append only (P-1 Edit 1):
```yaml
preferred-supported-locales:
  - en
untranslated-messages-file: l10n-untranslated.json
```
Planner note (PF-10): gen-l10n runs on `flutter pub get` / `flutter run`, **not** on `flutter test`. Every ARB-touching task must end with `flutter gen-l10n` before its verification step.

---

### `lib/core/l10n/arb/app_en.arb` + `app_uk.arb` (config, i18n)

**Analog:** the existing key/metadata convention in the same files — template carries a `@key` block with a `description`; the uk file carries values only (A-1 verified 164/164 parity, 164 `@` blocks in en, 0 in uk). New keys per P-2/Code Examples: `languageName` (self-referential endonym, never translated), `languageSystem`, `settingsLanguageTitle`.

**Metadata style to copy** — descriptions in this codebase state *why*, not *what*, and name the constraint (the `weekLoadLabel` description quoted at `planner_copy_safety_test` review: "`max` is a pre-formatted `slotsCount` string — the count is declined by its own plural key and passed in finished, the `cycleSummaryCyclic` idiom"). Match that register.

---

### `lib/core/l10n/locale_controller.dart` (store, event-driven + key-value I/O)

**Analog:** itself. Current file verbatim (lines 13-52):

```dart
class LocaleController extends Notifier<Locale?> {
  static const _prefsKey = 'app_locale';

  /// Language codes the app ships translations for.
  static const supportedLanguageCodes = {'en', 'uk'};   // <- L 17, must go (P-1 Edit 2)

  @override
  Locale? build() {
    _load();
    return null; // null = follow system until the async load settles
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    // Stored value is untrusted local input (threat T-01-07): SharedPreferences
    // can be edited outside the app (rooted device, backup edit). Only
    // supported language codes are accepted; anything else means follow
    // system — never crash locale resolution on bad storage.
    if (code != null && supportedLanguageCodes.contains(code)) {
      state = Locale(code);
    }
  }

  /// Sets the manual override. `null` clears the override (follow system).
  Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
    state = locale;                                     // <- L 45, must move first (PF-3)
  }
}

/// App-lifetime state — intentionally NOT autoDispose. The phase-wide
/// Riverpod dispose policy is documented in the core providers file (D-23).
final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
```

**Copy forward, do not lose:**
1. The T-01-07 untrusted-input comment at lines 28-31 — the sanitization survives the rewrite, so its rationale must too.
2. The "NOT autoDispose / D-23" provider docstring at lines 49-50.
3. `NotifierProvider<LocaleController, Locale?>(LocaleController.new)` — hand-written provider, no `@riverpod` codegen (CLAUDE.md constraint 5).

Target shape is given verbatim in RESEARCH "Code Examples → `LocaleController` after the three edits".

---

### `lib/core/providers.dart` — new `sharedPreferencesProvider` (provider, request-response)

**Analog:** `dbProvider`, `lib/core/providers.dart:32-40`:
```dart
/// The app database. Lazy: constructed only when first watched, so code
/// paths that never touch persistence (the Phase-1 shell, widget tests)
/// never open the on-disk file (D-19). Overridden with an in-memory
/// database in tests.
final dbProvider = Provider<BoostqueDb>((ref) {
  final db = BoostqueDb.open();
  ref.onDispose(db.close);
  return db;
});
```
Copy the **docstring shape**: what it is, the dispose/lifetime stance, and the "overridden in tests" sentence. The new provider throws in its body (`UnimplementedError('overridden in main() and in tests')`) — same "wired in here and nowhere else" spirit as the D-22 note in the file header (`providers.dart:19-21`).

**Placement decision for the planner:** `providers.dart:1-22` is the single recorded home of the D-23 dispose policy. Either put `sharedPreferencesProvider` there (and it inherits that documented policy) or in `core/l10n/`; if the latter, add a one-line pointer back to D-23, matching how `locale_controller.dart:49-50` already does it.

---

### `lib/main.dart` (entrypoint, request-response)

**Analog:** itself, lines 9-33 (quoted in full):
```dart
void main() {
  runApp(const ProviderScope(child: BoostqueApp()));
}

/// Root app widget: theme + l10n + locale resolution (D-10, D-11).
///
/// Locale resolution order: manual override from [localeControllerProvider]
/// (null lets the system locale flow through), then system uk/en matched
/// against [MaterialApp.supportedLocales], else English — `Locale('en')` is
/// listed FIRST so any unsupported system language falls back to it.
class BoostqueApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: bqTheme(),
      locale: ref.watch(localeControllerProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const AppShell(),
    );
  }
}
```
Two edits only, if P-4 Option A is taken: `main()` becomes `async` with `WidgetsFlutterBinding.ensureInitialized()` + a `sharedPreferencesProvider` override; and the docstring's "`Locale('en')` is listed FIRST" claim (lines 17-18) must be **re-worded to point at `preferred-supported-locales` in l10n.yaml** — it currently documents an intent that nothing enforces (PF-1). `MaterialApp.locale: ref.watch(localeControllerProvider)` at line 27 is already correct; do not touch it (P-5).

---

### `lib/features/settings/settings_screen.dart` (screen, request-response)

**Analog:** `lib/features/stack/stack_screen.dart:38-118` — same screen skeleton, same header treatment, same mono eyebrow.

**Screen skeleton + body padding** (`stack_screen.dart:46-61`):
```dart
return Scaffold(
  body: SafeArea(
    child: ListView(
      // 20px horizontal padding is the UI-SPEC mockup-exact override for
      // screen bodies; bottom >= 84px clears the nav bar (UI-SPEC #4).
      padding: const EdgeInsetsDirectional.only(
        start: 20, end: 20, top: BqSpace.lg, bottom: 84,
      ),
      children: [
        Text(l10n.stackTitle, style: Theme.of(context).textTheme.headlineSmall),
```
Settings uses `l10n.tabSettings` for the title (already carried by the stub at `settings_screen.dart:22`) and keeps `EdgeInsetsDirectional` throughout — the whole `lib/` tree is LTR-hardcode-free (A-2 item 4) and must stay that way.

**Mono eyebrow** (`stack_screen.dart:109-117`) — copy verbatim, swap the key:
```dart
Text(
  l10n.supplementsLabel,           // -> l10n.settingsLanguageTitle
  style: BqText.mono(
    size: 10.5,
    color: BqColors.textMuted,
    letterSpacing: 0.63,
  ),
),
const SizedBox(height: 10),
```

**Card container** (`stack_screen.dart:221-227`) — the row list sits inside this:
```dart
Container(
  padding: const EdgeInsetsDirectional.all(14),
  decoration: BoxDecoration(
    color: BqColors.surface,
    border: Border.all(color: BqColors.cardBorder),
    borderRadius: BorderRadius.circular(BqRadii.card),
  ),
```

**Widget-doc convention:** every screen/widget in `lib/features/` opens with a `///` docstring naming the UI-SPEC section and the decision IDs it implements (`stack_screen.dart:1-21`, `dose_action_sheet.dart:1-12`, `bq_segmented.dart:1-11`). The new files must follow — the planner should expect `05-UI-SPEC.md` section refs in them.

**Tokens confirmed present, no new tokens needed:** `BqColors.surface` (`tokens.dart:21`), `surfaceAlt:25`, `accent:46`, `hairline:74`, `cardBorder:81`, `BqRadii.panel:185`.

**Do not use `BqSegmented`** for the picker (P-6) — `bq_segmented.dart:20-23` documents it as a horizontal fixed-row control.

---

### `lib/features/settings/language_picker.dart` (component, event-driven) — NEW

**Analog A — the tappable row:** `lib/features/calendar/dose_action_sheet.dart:120-148` (verbatim):
```dart
/// One sheet action: 14/600 ink, >= 48px tall, no separator rule.
class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.label, required this.result});

  final String label;
  final DoseStatus result;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(result),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: BqColors.ink,
          ),
        ),
      ),
    );
  }
}
```
This is the exact shape P-6/P-11 ask for: `HitTestBehavior.opaque`, `minHeight: 48`, `AlignmentDirectional.centerStart`, no fixed width. Copy it, add the trailing selected check and the `BqColors.hairline` divider between rows.

**Analog B — selected-state semantics:** `lib/core/widgets/bq_segmented.dart:56-70`:
```dart
MergeSemantics(
  child: Semantics(
    selected: i == selectedIndex,
    button: true,
    label: labels[i],
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(i),
      child: Container(
        decoration: BoxDecoration(
          color: i == selectedIndex ? BqColors.surface : Colors.transparent,
```
Use `Semantics(selected: ...)` on each language row — a checkmark alone is not an accessible selected state, and this is the in-repo precedent.

**Analog C — `lookupAppLocalizations` usage:** `lib/features/stack/catalog.dart:158`:
```dart
final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));
```
The picker's `lookupAppLocalizations(locale).languageName` (P-2) is the same call with a locale drawn from `AppLocalizations.supportedLocales`, so it can never hit the generated `throw` (`gen/app_localizations.dart:1108-1123`).

**Riverpod read/write idiom** — `ConsumerWidget` + `ref.watch(...)` for state, `ref.read(...notifier)` for the action; the whole `lib/features/` tree does this (`stack_screen.dart:42-45`). Full target body is in RESEARCH "Code Examples → The picker body".

---

### The P-9 error-surface fix — three call sites

**Site 1 — `lib/features/calendar/planner_screen.dart:595-614`** (verbatim, the doc comment is part of the pattern):
```dart
/// The three async surfaces both segments share (S6c).
///
/// Data with something to draw renders [cards]; data with nothing to draw
/// renders the empty block; an error renders fixed copy plus retry; loading
/// renders nothing at all — no spinner, because a local-DB stream resolves
/// within a frame and a spinner would only flash (Phase-3 precedent).
List<Widget> _surface<T>(
  BuildContext context,
  WidgetRef ref, {
  required AsyncValue<T> model,
  required bool Function(T) isEmpty,
  required List<Widget> Function(T) cards,
}) {
  return switch (model) {
    AsyncError() => const [_PlannerError()],          // <- the defect
    AsyncData(:final value) when isEmpty(value) => const [_EmptyPlanner()],
    AsyncData(:final value) => cards(value),
    _ => const <Widget>[],
  };
}
```
Replace arm 1 with `AsyncValue(hasError: true)`; the replacement plus its explanatory comment is given verbatim in RESEARCH "Code Examples → The error-surface fix (P-9)".

**Site 2 — `lib/features/stack/stack_screen.dart:103-157`**, the `when` whose `loading:` returns an empty list and whose `error:` arm is the copy-and-retry template every other surface mirrors:
```dart
...entries.when(
  data: (list) => ...,
  // Loading: empty list area, NO spinner — the local-DB stream
  // resolves within a frame; a spinner would flash (#2).
  loading: () => const <Widget>[],
  // Error: documented copy + retry only — never exception text
  // (#3, T-02-08).
  error: (_, _) => <Widget>[
    Text(l10n.stackLoadError,
      style: const TextStyle(fontSize: 13, height: 1.4,
          color: BqColors.textSecondary)),
    const SizedBox(height: BqSpace.sm),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        // The same named recovery path the planner's retry uses,
        // so the two screens can never drift into recovering
        // differently (CR-02).
        onPressed: () => retryStack(ref),
        child: Text(l10n.retry,
          style: const TextStyle(fontSize: 13.5,
              fontWeight: FontWeight.w600, color: BqColors.accent)),
      ),
    ),
  ],
),
```
Fix = add `skipLoadingOnReload: true` as the first named argument. **This error arm is also the template for any error surface the Settings screen might need** (it needs none in v1 — the picker reads no async source).

**Site 3 — `lib/features/calendar/calendar_screen.dart:312-373`**, same `when` with a held-list `loading:` (lines 327-343) and the identical `dayLoadError` + `retry` arm at 347-372, whose retry is `ref.invalidate(dayDosesProvider(widget.day))` rather than `retryStack`. Same one-argument fix.

**The named-recovery-path rule** (`lib/core/providers.dart:126-142`): `retryStack` exists because invalidating the *derived* `stackEntriesProvider` cannot work — invalidation propagates to dependents, never dependencies. Any new retry the planner adds must target the stream providers, not a derivation.

---

### `test/l10n/new_language_contract_test.dart` (test, structural gate) — NEW

**Analog A — glob + prove-the-glob:** `test/features/planner_invariants_test.dart:79-133`:
```dart
/// Every planner source file, resolved by GLOB rather than by a hardcoded
/// list: a ninth planner file added by a later phase is covered the day it
/// lands, with no one having to remember this test exists.
List<File> plannerSources() {
  final dir = Directory('lib/features/calendar');
  final files = dir.listSync().whereType<File>()
      .where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith('planner_') && name.endsWith('.dart');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}
...
test('the glob actually resolves the planner files — a gate over an empty '
    'file set is worse than no gate', () {
  expect(sources, isNotEmpty);
  expect(sources.length, greaterThanOrEqualTo(8), reason: '...');
```
The "prove the glob resolved something" test is mandatory house style — V-3's ARB glob gets the same treatment.

**Analog B — loading localizations with no widget pump:** `test/l10n/planner_copy_safety_test.dart:11-20` + `plurals_test.dart:18-20`:
```dart
/// Loaded through the delegate with no widget pump (01-RESEARCH Pattern 6).
setUpAll(() async {
  l10n = await AppLocalizations.delegate.load(const Locale('uk'));
});
```
Note the contrast the planner must preserve: `lookupAppLocalizations(locale)` (synchronous, used by the picker and by V-3 assertion 4) vs `AppLocalizations.delegate.load` (async, used where an `AppLocalizations` for assertions is needed).

**Analog C — reading ARB off disk:** `planner_copy_safety_test.dart:14-20` imports `dart:convert` + `dart:io` and parses the template ARB, then derives its key set from prefixes rather than a hand-list (lines 75-112). Same posture for V-3.

Full assertion list is in RESEARCH P-1 ("How to test the claim rather than assert it").

---

### `test/l10n/no_hardcoded_strings_test.dart` (test, source gate) — NEW

**Analog:** `planner_invariants_test.dart:96-107`, the comment-stripper that keeps commentary from being read as code:
```dart
/// [source] with every comment line removed.
///
/// Line comments only, because this codebase writes no block comments — a fact
/// this function asserts on its own behalf below, so the day one appears the
/// gate says so instead of silently reading commentary as code.
String stripComments(String source) => source
    .split('\n')
    .where((line) {
      final t = line.trimLeft();
      return !t.startsWith('//');
    })
    .join('\n');
```
Plus the case-sensitivity helper idiom (`planner_invariants_test.dart:67-77` and its twin at `planner_copy_safety_test.dart:63-73`) — when V-2 needs a match rule, mirror the existing one rather than inventing a third.

**Allowlist discipline** (V-2, and the `forbiddenVocabulary` precedent at `planner_copy_safety_test.dart:34-61`): the allowlist is an explicit `const` list at the top of the file with a one-line rationale per entry, not a loosened regex. `negationOnlyVocabulary`/`negationBearingKeys` (lines 55-61) is the precedent for "allowed only in these named places".

Scope must exclude `lib/core/l10n/gen/`.

---

### `test/features/settings_screen_test.dart` (test, widget) — NEW

**Analog A — parameterizable app harness:** `test/features/planner_screen_test.dart:134-155`:
```dart
Widget plannerApp(
  ProviderContainer container, {
  String locale = 'uk',
  TextScaler? textScaler,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: bqTheme(),
      builder: (context, child) => textScaler == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const PlannerScreen(),
    ),
  );
}
```
This is the harness signature the A-3 gap tests must converge on. `stack_screen_test.dart`, `regimen_editor_test.dart` and `app_shell_test.dart` currently hardcode `const Locale('uk')` (see `app_shell_test.dart:41-51` `ukApp()`); the modification is to give each a `String locale = 'uk'` parameter, exactly as above.

**Analog B — SharedPreferences setup:** every widget test that reaches `LocaleController` already does (`stack_screen_test.dart:44-47`, `app_shell_test.dart:22-26`):
```dart
setUp(() {
  // LocaleController loads its persisted override from SharedPreferences;
  // an empty store means "follow system" (English in the test environment).
  SharedPreferences.setMockInitialValues({});
});
```
**If P-4 Option A ships**, this alone stops being sufficient — the container must also override `sharedPreferencesProvider`. Every one of these setUps is a call site the planner must enumerate.

**Analog C — in-memory Drift container:** `stack_screen_test.dart:52-60` / `app_shell_test.dart:28-39`:
```dart
dbProvider.overrideWith((ref) {
  final db = BoostqueDb.forTesting(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
}),
```
The Settings screen touches no DB, but the app-shell-level bilingual tests do.

**Analog D — teardown that flushes Drift's timers:** `app_shell_test.dart:53-59`:
```dart
Future<void> flushTearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
}
```

---

### The bilingual render matrix (test modifications)

**Analog:** `test/features/planner_screen_test.dart:2577-2618` — the only locale matrix in the tree:
```dart
/// The consequence of a red case, named in device terms rather than as a
/// restatement of the assertion.
const overflowReason =
    'a layout exception at an accessibility text scale is a clipped label '
    'or a dropped bar in RELEASE — not debug stripes. This is the CR-01 / '
    'WR-04 defect class Phase 3 shipped twice; the fix is a computed '
    'extent or a flexible child, never a relaxed assertion';

for (final locale in const ['uk', 'en']) {
  final cyclesLabel = locale == 'uk' ? 'Цикли' : 'Cycles';
  final yearLabel = locale == 'uk' ? 'Рік' : 'Year';

  for (final scale in const <double>[1.0, 1.6, 2.0]) {
    testWidgets('$locale: ... at textScaler $scale (UI-SPEC #20)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedPressure(container);
      await openPlanner(tester, container,
          locale: locale, textScaler: TextScaler.linear(scale));
      ...
      expect(tester.takeException(), isNull, reason: overflowReason);
      await tearDownTree(tester, container);
    });
```
Copy the whole shape including the named `overflowReason` constant — assertions in this codebase carry a device-consequence `reason:`, never a restatement. The Cyrillic-leak assertion V-4 adds on top is in RESEARCH "Code Examples → The bilingual render matrix".

**Assertion-style rule to carry into every new test:** test names in this repo state the *behavioural claim* and cite the ID (`'unsupported stored value is sanitized to null/system (T-01-07)'`, `locale_controller_test.dart:53`). Match it.

---

### `test/l10n/locale_controller_test.dart` (test, unit) — modify

**Analog:** itself. Four existing tests (`:16-62`) pin the current async-load contract:
```dart
SharedPreferences.setMockInitialValues({'app_locale': 'uk'});
final container = makeContainer();
container.read(localeControllerProvider); // trigger build + async load
await pumpEventQueue();
expect(container.read(localeControllerProvider), const Locale('uk'));
```
Under P-4 Option A the `await pumpEventQueue()` becomes unnecessary in three of the four, and the container needs a `sharedPreferencesProvider` override — the RESEARCH's "the existing four tests adapt in a few lines" claim resolves to exactly these lines. `makeContainer()` at `:10-14` (with `addTearDown(container.dispose)`) is the container idiom for pure-unit tests, distinct from the DB-overriding one in widget tests.

---

## Shared Patterns

### Direction-neutral padding (applies to every new widget)
**Source:** `stack_screen.dart:51-56`, `dose_action_sheet.dart:54-59`, `settings_screen.dart:16-20`
```dart
padding: const EdgeInsetsDirectional.only(start: 20, end: 20, top: BqSpace.lg, bottom: 84),
alignment: AlignmentDirectional.centerStart,
```
A-2 item 4 verified: zero `EdgeInsets.only(left:/right:)`, zero `fromLTRB`, zero `Alignment.centerLeft`, zero `TextAlign.left`, zero `BorderRadius.only` in `lib/`. New Settings code must not be the first.

### Localized-string access
**Source:** `lib/core/l10n/l10n.dart` (whole file, 14 lines)
```dart
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```
Always `final l10n = context.l10n;` at the top of `build` — never in `initState`, never cached in a field (PF-4; grep confirms zero violations today).

### Token-only styling
**Source:** `lib/core/theme/tokens.dart` + `BqText.mono()` (`theme.dart:128-146`)
**Apply to:** `settings_screen.dart`, `language_picker.dart`. No hex literals. Confirmed available: `BqColors.surface:21`, `surfaceAlt:25`, `accent:46`, `hairline:74`, `cardBorder:81`, `BqRadii.panel:185`, `BqRadii.card`, `BqSpace.*`.

### Widget/file docstrings citing UI-SPEC + decision IDs
**Source:** `stack_screen.dart:1-21`, `dose_action_sheet.dart:1-12`, `bq_segmented.dart:1-11`, `providers.dart:1-22`
Every file opens with a `///` (or `library;`-terminated) doc naming the screen contract, the plan number, the decision/threat IDs, and — critically — the *rejected alternative* where one exists (`bq_segmented.dart:2-5` explains why `SegmentedButton` was not used). New Phase-5 files must state why `BqSegmented` was rejected for the picker and why `languageName` is self-referential.

### Async error surface (copy + retry, never exception text)
**Source:** `stack_screen.dart:128-156` (`stackLoadError` + `retryStack`), `calendar_screen.dart:344-372` (`dayLoadError` + `invalidate`)
**Apply to:** all three P-9 edits; the threat IDs (T-02-08 / T-03-16) name the same rule — raw exception text never enters the tree.

### Test-container idioms
**Source:** unit → `locale_controller_test.dart:10-14`; widget+DB → `stack_screen_test.dart:52-60`; teardown → `app_shell_test.dart:53-59`

---

## No Analog Found

| Element | Role | Data Flow | Reason / what the planner should use instead |
|---|---|---|---|
| `preferred-supported-locales` + `untranslated-messages-file` in `l10n.yaml` | config | build-time | The file has never had an option beyond the seven current lines. Use RESEARCH P-1 Edit 1 verbatim; the `l10n-untranslated.json` artifact is new to the repo and needs a `.gitignore` decision the planner must make explicitly. |
| Synthetic third-locale fixture (writing `app_pl.arb` to a temp arb dir and shelling out to `flutter gen-l10n`) | test | file-I/O + subprocess | **No test in the repo shells out to any process.** RESEARCH itself recommends the fast, in-process variant (V-3's five assertions) and marks the shell-out as optional; with no local precedent, recommend the planner drop it rather than invent a subprocess-test convention in the final v1 phase. |
| `toBeginningOfSentenceCase(value, locale)` replacing `_capitalizeFirst` (`calendar_screen.dart:232-236`) | utility | transform | No existing site calls this `intl` API — `intl` is used only via `DateFormat` (17 sites) today. One-line swap, no analog needed; RESEARCH marks it "recommended, not required" (PF-6). |
| Settings screen **visual composition** | screen | — | P-6: the approved HTML mockup has no Settings screen at all (its third tab is `Радник`). The layout analogs above (Stack header, card container, sheet row) are the closest the codebase offers; everything above them is newly authored and must be `[ASSUMED]` until UAT, via `05-UI-SPEC.md`. |
| Font-asset swap (P-10) | config/bundle | — | `pubspec.yaml`'s `fonts:` block exists but has never been changed; and this is a costed **user decision**, not a pattern-copy task. Route to `checkpoint:human-verify`. |

---

## Metadata

**Analog search scope:** `lib/core/`, `lib/features/`, `lib/main.dart`, `lib/app_shell.dart`, `test/l10n/`, `test/features/`, `test/widget/`, `l10n.yaml`
**Files read this session:** 16 (11 source, 5 test) + `l10n.yaml`
**Pattern extraction date:** 2026-08-16
