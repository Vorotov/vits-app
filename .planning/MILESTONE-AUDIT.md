# Milestone Audit — Boostque v1

**Audited:** 2026-08-16
**Auditor:** adversarial read of `lib/` and `test/` (fresh eyes; SUMMARY / VERIFICATION / UAT documents treated as unverified claims and not consulted as evidence)
**Scope:** all 23 v1 requirements across Phases 1–5
**Method:** for each requirement, locate the implementing code and the proving test, then attempt to falsify — is the implementation a stub that satisfies a grep? does the test assert something trivially true? would it still pass if the feature were deleted or inverted? Cross-requirement conflicts checked separately.

**Constraint honoured:** no `flutter` command was run. The orchestrator's inputs (`analyze` = 0 issues, `test` = 693/693, tree clean) are taken as given; everything below is derived from reading source.

---

## Verdict counts

| Verdict | Count |
|---|---|
| SOLID | 21 |
| WEAK | 2 |
| NOT DELIVERED | 0 |

---

## Per-requirement table

### Stack Management

| ID | Implementing code | Proving test | Verdict | Note |
|---|---|---|---|---|
| **STACK-01** | `lib/features/stack/catalog.dart:60` (15 entries, ARB-resolved names), `:167` `searchCatalog` (case-insensitive substring over active-locale **and** English names); `lib/features/stack/add_supplement_sheet.dart:106` `_addFromCatalog` → `supplementRepoProvider.upsert` → push editor | `test/features/catalog_search_test.dart`; `test/features/stack_screen_test.dart:281` (types `креат`, taps the row, asserts the row persists **and** the card renders after returning) | **SOLID** | Tried to break it: the catalog is not a stub — each entry resolves through a real generated getter, and ARB parity (168/168 keys) means no entry can silently fall back to English. Copy-on-add is deliberate and documented; the `_busy` guard at `:70` is proven by the double-tap test at `stack_screen_test.dart:322` ("adds exactly ONE supplement"). |
| **STACK-02** | `add_supplement_sheet.dart:130` `_saveManual` (trim-required name at `:90`, round-robin palette colour, UUID minted at the save boundary) | `test/features/stack_screen_test.dart:184` (manual add persists, lands on editor, card renders after return; save stays disabled for a blank/whitespace name) | **SOLID** | The disabled-button *is* the validation surface — I checked that `_canSaveManual` uses `.trim()`, so a whitespace-only name cannot pass. Write failure is handled (`:160` re-enables and shows a SnackBar) rather than swallowed. |
| **STACK-03** | `lib/features/stack/stack_screen.dart:220` `_StackCard` (colour bar, wrapping name/dose, status chip, schedule chip); `stack_status.dart:37` `statusOf` (5 states, precedence documented); `schedule_summary_text.dart:33` | `test/features/stack_status_test.dart` (226 lines of pure matrix); `stack_screen_test.dart:400/420/439/458/480` — one case per rendered status incl. the clock-driven planned→active transition | **SOLID** | Each of the five statuses has its own rendered assertion, not one "a chip exists" check. `statusOf` never reads the clock; `today` is injected, so the ЗАПЛАНОВАНО→АКТИВНА test is a real state transition, not a tautology. |
| **STACK-04** | `regimen_editor_screen.dart:967` `_confirmDelete` → `regimen_editor_controller.dart:409` `deleteSupplement` → `drift_repositories.dart:75` `softDeleteCascade` (one transaction: supplement + regimens + slots + pending logs `>= fromDay`) | `test/db/cascade_delete_test.dart:63` and `:116` (the scoping case: a pending log dated **before** `fromDay` keeps `deletedAt` null); `regimen_editor_test.dart:569` (dialog cascades and pops); `stack_screen_test.dart:516` (card tap opens the editor) | **SOLID** | The scoping test is the one that matters and it exists — an implementation that stamped *all* pending rows would fail it. No Drift `delete` statement appears anywhere in `drift_repositories.dart` (verified by reading the whole file), so "soft delete in DB" holds by construction. |

### Regimen Scheduling

| ID | Implementing code | Proving test | Verdict | Note |
|---|---|---|---|---|
| **REGI-01** | `regimen_editor_controller.dart:278/281` `setOnDays`/`setOffDays`; `regimen_editor_screen.dart:323` slider `min 7 / max 112 / divisions 15` → exact 7-day step, `:333` `min 0 / max 84 / divisions 12` → exact 7-day step; `cycle_math.dart:26` `isActiveOn` cyclic branch `(day-start) % (on+off) < on` | `test/domain/cycle_math_test.dart:38` (the 56/28 exemplar at days 0/55/56/83/84 — boundary-exact, not "is active somewhere"); `regimen_editor_test.dart:393` | **SOLID** | I checked the slider arithmetic: `(112-7)/15 = 7` and `84/12 = 7` — the "7-day steps" claim is arithmetically enforced, not a comment. `isActiveOn` has no second copy of the modulo anywhere in the codebase (the planner routes through it via `activeRuns`, verified at `planner_invariants_test.dart:250`). |
| **REGI-02** | `cycle_math.dart:35` course branch — `end != null && !d.isAfter(dateOnly(end))`; `regimen_editor_screen.dart:362` end-date picker with `firstDate: draft.startDate`; `regimen_editor_controller.dart:265` clamps a stale end up to a new start | `cycle_math_test.dart:93` (asserts BOTH `2026-09-30` active and `2026-10-01` inactive — inclusivity is proven at the boundary, not asserted mid-range); `regimen_editor_test.dart:358` | **SOLID** | Inverting the implementation to exclusive end would fail line 95. The null-end case is separately pinned (`cycle_math_test.dart:99`, `planner_view_model_test.dart:845` "contributes nothing ANYWHERE"). |
| **REGI-03** | `regimen_editor_controller.dart:144-150` `maxSlots 6 / minSlots 1`, `:285` `addSlot` (refuses at cap, walks unused defaults), `:301` `removeSlot` (refuses at floor), `:308` `setSlotTime` re-sorts | `test/features/regimen_editor_controller_test.dart:208` group "slot operations (REGI-03/V-1: clamped by construction)" | **SOLID** | The clamp is enforced in the controller, not just by disabling a button — so a programmatic path cannot exceed it either. Slots carry their own time **and** dose label end-to-end (`DoseSlot.doseLabel` reaches `dose_row.dart:318`). |
| **REGI-04** | `regimen_editor_controller.dart:324` `togglePause` (draft-only, persisted on save); `cycle_math.dart:27` `if (r.paused) return false`; `drift_repositories.dart:346` — `watchDay`'s pause filter excludes **only** paused-and-pending | `test/db/pause_filter_test.dart:66/123/168` (paused hides pending, keeps recorded history, resuming restores with zero writes); `providers_calendar_test.dart:155` "log-row writes (PF-9, E-4, REGI-04)"; `regimen_editor_test.dart:485` (four simultaneous pause signals incl. ПАУЗА badge) | **SOLID** | Two independent enforcement points (the domain predicate *and* the SQL filter), each separately tested. The "zero writes on resume" property is a genuine behavioural assertion — an implementation that soft-deleted logs on pause would fail it. |

### Daily Tracking

| ID | Implementing code | Proving test | Verdict | Note |
|---|---|---|---|---|
| **TRACK-01** | `day_view_model.dart:29` `blockStartsMinutes [0,720,1080,1320]`, `:68` `groupIntoBlocks` (omits empty blocks, header uses the earliest **real** slot time); `day_block_section.dart:75`; `day_progress_ring.dart`; `calendar_screen.dart:228` (ring hidden at total 0) | `test/features/day_view_model_test.dart` (492 lines of pure matrix); `calendar_screen_test.dart:189` (renders through the real DB with no manual materialization call), `:674` (only non-empty blocks, chronological), `:713` (earliest real slot time, not the mockup anchor), `:333` ring group | **SOLID** | The `:713` case is exactly the kind of thing a lazy implementation gets wrong (printing a hardcoded 08:00 above a 09:30 morning) and it is asserted. Ring is a `CustomPainter` with a real `shouldRepaint` test at `:362`. |
| **TRACK-02** | `dose_row.dart:86` `_apply` — the app's **single** `setStatus` call site, with a re-entry guard; `:109` `_onTap` (taken ↔ pending); `dose_action_sheet.dart` returns a status and never writes | `calendar_screen_test.dart:213` — taps, then asserts on the **raw `IntakeLog` table row** transitioning pending→taken→pending; `:255` double-tap-with-no-pump ends deterministically at taken; `:1423` a failed write leaves the row at its previous status; `:1786` long-press during an in-flight tap | **SOLID** | This is the strongest test in the suite: it asserts against the database row, not against a widget. It cannot pass if the write were dropped. Undo is covered from three directions (second tap, sheet action, semantics custom action at `dose_row.dart:251`). |
| **TRACK-03** | `day_view_model.dart:110` `isMissed` (pure, view-only — the library imports no persistence, so no write is reachable from it); `dose_row.dart:194` missed keeps the live pending visual + neutral `не позначено` chip; `week_strip.dart:57` bounded 53-page Monday-first pager | `calendar_screen_test.dart:2401` — browses a past day, then asserts **every row in the whole `intake_logs` table is still `pending`**; `:2442` no warn/destructive colour anywhere on a past day and the dose is still tappable; `:2070` pager is bounded at 53 with today's week last | **SOLID** | The DB-row assertion is what makes "computed in the view" non-vacuous. The neutrality mandate is enforced structurally too: `isOverdue` is gated on `viewingToday`, and `blockTagOf`'s only warn branch is inside the same gate. |
| **TRACK-04** | `cycle_math.dart:16` `dateOnly` (uses y/m/d fields, never local midnight); `drift_repositories.dart:276` `ensureLogsForDay` — `isActiveOn` is the only gate, `insertOrIgnore` on unique `(slotId, date)`; `today_controller.dart:32` `nextLocalMidnight` via the local date constructor | `test/db/materialization_boundaries_test.dart` — full `ensureLogsForDay` → `watchDay` chain across 2026-10-25 (fall back), 2026-03-29 (spring forward) and the 2026/2027 boundary, with **exact** counts (never "> 0"), double-materialization idempotency, and a status-preservation case at `:172` | **SOLID** *(with a documented limitation, below)* | Counts are exact and the whole production chain is exercised, so this is not a presence check. **Limitation I could not close by reading:** no test forces `TZ=Europe/Kyiv`, so the DST cases would produce identical results under a UTC runner. DST safety therefore rests on construction (all date-only values are `DateTime.utc`, `Duration.inDays` exact) plus the `nextLocalMidnight` exact-equality case — which *is* meaningful — rather than on a transition actually being crossed. See "Suspected vacuous or weak tests" #1. |

### Planner Views

| ID | Implementing code | Proving test | Verdict | Note |
|---|---|---|---|---|
| **PLAN-01** | `planner_view_model.dart:51` `activeRuns` (day-scan through `isActiveOn`, never a restated formula), `:103` `ganttSegments` (fractions, `planned` = run starts strictly after today), `:235` `buildCyclesModel`; `planner_gantt.dart:502` `_GanttRowPainter` (solid vs 4px-on/4px-off hatch), `:230` `gantt-today-marker` | `test/domain/planner_window_test.dart` (window span 120–123, never the mockup's 122); `planner_view_model_test.dart` (882 lines); `planner_screen_test.dart:1192/1228/1256/1302` (standalone month names, real day-count column widths, interior gridlines, exactly three legend entries) | **SOLID** | Tried to break the "hatched = planned" claim: the legend swatch and the segment both call the same `_paintPlanned` helper (`planner_gantt.dart:359`), so the legend cannot describe a hatch the chart doesn't draw. The `:1228` test ("a 31-day month is wider than a 30-day one") would fail an equal-quarters implementation. |
| **PLAN-02** | `planner_view_model.dart:333` `weekBuckets` (full Monday weeks, deliberately not the mockup's `i*7`), `:371` `weekLoads` (once per bucket, not once per active day), `:437` `verdictOf`; `planner_load_chart.dart:283` tap → `selectedWeekProvider`; `planner_week_detail.dart` (load, verdict chip, pips, active-supplement name chips) | `planner_screen_test.dart:1414` (18 or 19 columns), `:1440` (all three bands draw), `:1470` (zero-load week still selectable), `:1491` (whole column is the tap target), `:1576` (exactly one dashed reference line), `:1680/1718/1753` (detail at loads 0/4/over-limit re-renders in place) | **SOLID** | The "once per bucket" semantic is the falsifiable claim and `planner_view_model_test.dart` pins it. Selection is stored as a **date**, not an index (`planner_providers.dart:89`), which I checked defuses the month-rollover retargeting bug. |
| **PLAN-03** | `planner_view_model.dart:468` `monthCellFor` (real `daysInMonth`, `full` at ≥0.85, `planned` only when *all* coverage is future), `:550` `buildYearModel`; `planner_year_grid.dart:208` tap → `selectedMonthProvider`, `:360` lighter alpha for planned; `planner_month_detail.dart` | `planner_view_model_test.dart:736/787` (peak index and the tie-break toward the nearest month); `planner_screen_test.dart:1919` (twelve cards), `:1951` (two days of coverage still paint a visible bar), `:2006` (exactly one card selected, tapping moves it), `:2141/2178` (detail lists only covered supplements; empty-month sentence) | **SOLID** | `daysInMonth` derives from `DateTime.utc(y, m+1, 0).day` — no month-length table exists anywhere in the codebase, so leap years cannot drift. Verified by grep. |
| **PLAN-04** | `planner_screen.dart:627` `_BodyScroll` renders `plannerDisclaimer` **unconditionally**, under every state including empty and error, on both segments; `:353` `yearFootnote` frames the limit editorially; `planner_view_model.dart:406` `editorialLimit` defined once with an explicit "not a medical threshold" contract | `test/l10n/planner_copy_safety_test.dart:222` (ARB-level forbidden-vocabulary gate — no "норма/норматив", no "medical standard"), `:260` (the positive half must be present); `planner_invariants_test.dart:455` — rendered sweep in **both** locales, above and below the fold, on **both** segments, asserting the disclaimer is present and no excluded mockup content (interaction claims, the pharmacological clause, an add control) is reachable | **SOLID** | This is the requirement most likely to be satisfied in prose only, and it is the one with the strongest gate: a copy-level vocabulary check *plus* a rendered-tree check in two languages. The disclaimer is structurally unconditional — I read `_BodyScroll` and there is no branch that can omit it. |

### Localization

| ID | Implementing code | Proving test | Verdict | Note |
|---|---|---|---|---|
| **L10N-01** | `lib/core/l10n/arb/app_en.arb` + `app_uk.arb` (168/168 message keys each, verified by parsing both files); 10 ICU plural keys, every uk one declaring `one/few/many/other` | `test/l10n/plurals_test.dart` — rendered output at **1/2/5/11/21** for every plural key, including the 11–14 exception and the `i%10=1` re-entry at 21; `test/l10n/arb_parity_test.dart` derives the *required* categories from `Intl.plural` rather than transcribing them; bilingual render matrices in `app_shell_test.dart:195`, `stack_screen_test.dart:716`, `calendar_screen_test.dart:3049`, `regimen_editor_test.dart:673` | **SOLID** | Tried hardest here. The plural tests assert exact rendered strings, so an implementation with only `one/other` fails at n=5 and n=11. `arb_parity_test.dart` explicitly refuses to hand-list plural keys — it parses the template for ICU constructs — so key eleven is gated the day it lands. Ukrainian correctness is checked at the *word* level (`речовина/речовини/речовин`), and `plurals_test.dart:116` proves the sentences stay grammatical at values other than the shipped 5 — which is the exact defect class ("no test failed because every test passed 5") that a weaker suite would have. |
| **L10N-02** | `l10n.yaml` `preferred-supported-locales: [en]`; `main.dart:59` `MaterialApp` with `AppLocalizations.supportedLocales` and generated delegates; **no** `localeResolutionCallback` anywhere | `test/l10n/locale_resolution_test.dart` — drives the real resolver via `platformDispatcher.localesTestValue` and asserts on **rendered copy**, covering: unshipped language → English, a multi-entry preference list (`de, uk-UA, en-US` → Ukrainian), `uk_UA` → Ukrainian, `en_GB` → English; `new_language_contract_test.dart:176` gates the *declaration* separately from the *effect* | **SOLID** | The multi-entry case is the one a hand-rolled callback would fail, and it exists. The two-part fallback test is deliberately non-redundant: part (b) catches the case where `en` sorts first by accident — the author documented exactly why not to delete it, and the reasoning is correct. |
| **L10N-03** | `locale_controller.dart:40` (synchronous seed from `SharedPreferences`, `get` not `getString` to survive a non-String value, allowlist derived from `supportedLocales`), `:72` `setLocale` (state first, disk after); `language_picker.dart:52` options = `[null, ...supportedLocales]` | `test/features/settings_screen_test.dart:197` (tap → the whole app re-reads within **one** `pump()`, including the nav bar outside the screen), `:245` (survives a full tree teardown + fresh scope, asserted **before** any extra pump — the no-flash property), `:283` (System default removes the key), `:426–470` (exactly one row checked, in every stored state) | **SOLID** | "Applies instantly" is asserted with a single `pump()`, not `pumpAndSettle` — that is a real one-frame claim. "Persists across restarts" tears the tree down and rebuilds over the same store. Untrusted-storage sanitization is tested with a synthetic locale (`new_language_contract_test.dart:333`). |
| **L10N-04** | `calendar_screen.dart:143/149`, `week_strip.dart:253/281/299`, `planner_screen.dart:197/210/407`, `planner_year_grid.dart:133`, `planner_month_detail.dart:123` — every one uses `DateFormat(..., locale)` with the locale read from the widget tree; `casing.dart:32` `bqUpperCase`; `schedule_summary_text.dart:59` `DateFormat.yMd(locale)` | `test/l10n/no_hardcoded_strings_test.dart` (four gates: user-facing position, *every* translatable literal must fall into a named allowlist category, no locale-dependent read cached in `initState`/`late final`, no `.toString()` inside `Text()`); `new_language_contract_test.dart` (the one-new-ARB-file contract); `test/l10n/month_names_test.dart` (standalone `LLLL` vs `MMMM` — nominative vs genitive in Ukrainian) | **SOLID** *(one conscious deviation, below)* | The zero-hardcoded-strings gate is genuinely strong: it has a glob proof that runs **first** (so it can't pass over an empty file set), it forbids widening a pattern in favour of adding a named allowlist entry, and it asserts every allowlist entry still matches something (a dead entry fails). I tried to find a hole — see "weak tests" #2 and #3. **Conscious deviation:** time-of-day is hardcoded to 24-hour at all four call sites (`dose_action_sheet.dart:48`, `day_block_section.dart:73`, `regimen_editor_screen.dart:611/711`). The requirement text names "dates, month names and numbers", so this is not a violation, but an en-US user will see `20:00`, never `8:00 PM`. |

### Data & Platform

| ID | Implementing code | Proving test | Verdict | Note |
|---|---|---|---|---|
| **DATA-01** | `drift_repositories.dart` (local file/memory I/O only); `android/app/src/main/AndroidManifest.xml` declares **no** `INTERNET` permission; `pubspec.yaml` has no HTTP client; no login/account code path exists anywhere in `lib/` | `test/providers_test.dart:54` (empty-DB behaviour); structurally verified by grep — zero `HttpClient`/`Socket`/`dio`/`http` references in `lib/` | **SOLID** | Verified by absence: I grepped `lib/` and `test/` for every network primitive and found none, and read the whole Android manifest. **However**, this property is guarded by nothing mechanical — see "weak tests" #4. |
| **DATA-02** | `lib/core/db/database.dart:26` `SyncColumns` mixin (TEXT UUID PK, `createdAt`, `updatedAt`, nullable `deletedAt`) on all four tables, `:98` unique `(slotId, date)`, `:118` `driftDatabase(name: 'boostque')` → app-documents dir; `AndroidManifest.xml` has no `android:allowBackup="false"`; no `NSURLIsExcludedFromBackupKey` in `ios/` | `test/db/database_test.dart:46` — introspects **every** table for all four SyncColumns and asserts the primary key is exactly `{id}`; `:75` unique-key idempotency; `:91` UTC round-trip with `isUtc == true`; `cascade_delete_test.dart` proves no hard delete | **WEAK** | The sync-ready half is SOLID and properly introspected (it loops over `db.allTables`, so a fifth table is gated the day it lands). **The backup half is unguarded.** `database.dart:110–117` states the rule in a doc comment — "The app must NEVER opt this file or itself out of OS backups: no `android:allowBackup=\"false\"` … and no `NSURLIsExcludedFromBackupKey`" — and **nothing enforces it**. I grepped `test/` for `allowBackup`, `dataExtractionRules`, `fullBackupContent` and `NSURLIsExcluded`: zero hits. A one-line manifest edit would silently break "data survives reinstall" with all 693 tests green. Every other invariant in this codebase of comparable importance has a machine gate; this one does not. |
| **DATA-03** | `android/app/build.gradle.kts:23` `targetSdk = 36`, `:19` `applicationId = "com.boostque.dev"`; `ios/Runner/Info.plist` present; the full loop is wired end-to-end (Stack → editor → Today → mark) and exercised in widget tests over a real in-memory Drift DB | No test can prove this — "builds and runs on a simulator/device" is inherently a human/CI observation | **WEAK** | Only the mechanically checkable half is verified by reading: `targetSdk = 36` is correct, the bundle id is still the placeholder `com.boostque.dev` (which CLAUDE.md flags as needing a decision before store release), and the loop is complete in code. **The "builds and runs on both platforms" claim is unverifiable by reading and I did not verify it.** It rests entirely on a human UAT observation I was instructed not to treat as evidence. Marking SOLID would be unjustified; marking NOT DELIVERED would be unfounded. |

---

## Suspected vacuous or weak tests

Five findings, ordered by how much they weaken a requirement claim. None is a false-green today; each is a place where the suite proves less than its title suggests.

### 1. The DST test names promise more than the assertions deliver — no test forces a DST timezone

`test/db/materialization_boundaries_test.dart` is titled "DST and year-boundary materialization exactness" and `test/features/today_provider_test.dart:61` asserts `nextLocalMidnight` "lands 23-25 hours away — never a fixed 24h assumption (PF-2)".

I grepped the whole `test/` tree for `TZ`, `timeZone`, `Europe/Kyiv` and `setEnvironment`: **zero hits**. The suite runs in the host machine's timezone, which in CI is almost certainly UTC.

Consequence, precisely:
- The `materialization_boundaries_test.dart` cases pass `DateTime.utc(...)` values and therefore **would produce byte-identical results under a UTC runner** — they prove the modulo arithmetic and the insert-or-ignore idempotency (both real and valuable), but they do **not** prove a DST transition was crossed.
- The 23–25-hour assertion at `today_provider_test.dart:61` is **the closest thing to a vacuous assertion in the suite**: under UTC every gap is exactly 24h, which trivially satisfies both `<= 25h` and `>= 23h`. Inverting `nextLocalMidnight` to `from.add(Duration(hours: 24))` would still pass this specific case.

What rescues it: `today_provider_test.dart:43` asserts **exact equality** with `DateTime(y, m, d+1)`, and a `+24h` implementation fails that under any DST timezone (and is trivially different in shape). Plus the whole design routes date-only values through `DateTime.utc`, so DST cannot reach the arithmetic by construction. The test file header is honest about asserting "only timezone-independent invariants".

**Assessment:** not a false green, but the DST claim is proven by *construction* rather than by *execution*. A single `TZ=Europe/Kyiv` run of the existing suite would close it cheaply.

### 2. `no_hardcoded_strings_test.dart` has two file-scoped and constructor-scoped allowlist entries that are wider than they need to be

The gate is strong overall — glob proof first, dead-entry detection, "never widen a pattern" discipline. Two entries are broader than the rationale they carry:

- `_isCasingLanguageSubtag` (`:356`) allowlists **every literal in `lib/core/l10n/casing.dart`**, not just `'tr'`/`'az'`. Any translatable string added to that file would pass unflagged. The file is 41 lines and contains nothing else today, so the exposure is small — but it is a file-scoped exemption in a gate whose stated discipline is per-category.
- `_isStableDomainId` (`:345`) allowlists any literal whose enclosing call is `CatalogEntry`, `_LegendEntry`, `Regimen` or `driftDatabase`. A user-visible string placed inside a `CatalogEntry(...)` constructor — exactly where catalog copy would go — is exempt by construction.

**Assessment:** real holes, currently unexploited (I read both files and there is nothing translatable in either position). Worth tightening to value-level matchers.

### 3. The Cyrillic-leak sweep does not cover the planner — the largest and newest screen set

`expectNoCyrillicWhileEn` (`test/support/locale_matrix.dart:69`) is applied in `app_shell_test`, `stack_screen_test`, `calendar_screen_test`, `regimen_editor_test` and (in a local form) `settings_screen_test`. It is **not** applied anywhere in `test/features/planner_screen_test.dart`, which covers the gantt, the load chart, the week detail, the year grid, the month detail, the legend, both chips and the footnote.

The planner does have en coverage (`:1324` legend in English, `:952` error copy in both, `:2665` a text-scale matrix in both that sweeps the entire scroll body) — but nothing asserts that no Ukrainian string reaches an English planner tree.

I tried to find a leak this would have caught and could not: the source gate at `no_hardcoded_strings_test.dart:562` flags interpolated Cyrillic (it strips `$…` then looks for two letters, so `Text('Цього тижня $x')` trips), and the one leak class the source gate *cannot* see — a hardcoded `lookupAppLocalizations(const Locale('uk'))` — does not exist: grep found exactly one `Locale(...)` literal in `lib/`, the documented English search index at `catalog.dart:158`.

**Assessment:** a genuine coverage gap on the phase's largest UI surface, closed today only by a second, indirect gate. One `expectNoCyrillicWhileEn(tester)` call in the existing en text-scale sweep would close it.

### 4. DATA-01 and DATA-02's backup clause are asserted only in prose

Neither "no network dependency" nor "included in OS-level backups by default" has any mechanical gate. Both are true today (verified by reading the manifest, the plist, `pubspec.yaml` and every file in `lib/`), and both would break silently.

This stands out precisely *because* the rest of the codebase is so consistently gated: there is a source gate against hardcoded strings, against materializing paths in the planner, against raw colour literals, against locale-dependent reads in `initState`, against restating the cycle formula, and against forbidden planner vocabulary. Two of the three DATA requirements have none.

### 5. The Year peak chip has an unexercised degenerate rendering

`planner_view_model.dart:586` computes `peakLoad` as a fold with seed `0`. When every month has load 0 — reachable with a stack whose only regimen is paused, or is a course with a null end date — `tiedIndices` becomes all twelve months, so `peakTied` is `true` and `peakIndex` is January.

`_YearBody`'s empty check (`planner_screen.dart:361`) is `model.entries.isEmpty`, and `entries` is the *regimen-bearing* subset — a single paused supplement is non-empty. So the chip renders `peakMonthsTie('січень')` alongside `substancesCount(0)`: "the densest months, including January · 0 substances".

The model-level all-zero case **is** tested (`planner_view_model_test.dart:845` and `:859` assert `load == 0` everywhere), but no test asserts what that renders. The peak-chip rendering tests (`planner_screen_test.dart:2205/2227/2248`) all use non-zero loads.

**Assessment:** cosmetic, not incorrect — but it is the one place where a documented model invariant ("peak") is applied to data for which it has no meaning, and it is unobserved.

---

## Cross-requirement conflicts

I checked every pair of requirements that touch shared state (regimens, intake logs, the today clock, the locale). Four interactions are worth recording; **none is a live defect**.

### A. STACK-04's "history is never touched" is true in the DB and false in the UI

`drift_repositories.dart:72` documents that `softDeleteCascade` leaves taken/skipped rows and past pending rows with `deletedAt` null — "history is never touched" — and `cascade_delete_test.dart:116` proves it.

But `watchDay` (`:338`) filters on `db.regimens.deletedAt.isNull() & db.supplements.deletedAt.isNull()`. After a cascade delete, **all** of that supplement's doses vanish from every day view, including the taken ones the cascade deliberately preserved.

This is almost certainly the right product behaviour (a deleted supplement should disappear everywhere) and it does not violate STACK-04, whose text is "deleting removes its regimen and future doses". But the preservation the cascade pays for is currently unreachable — it is future-proofing for HIST-01/EXPT-01, not present behaviour. Recording it so the comment isn't read as a UI promise.

### B. TRACK-01/04 read *all* regimens; STACK-03 and PLAN-01/03 read only the *first*

`ensureLogsForDay` (`drift_repositories.dart:283`) iterates **every** regimen from `watchAll()` and materializes a dose for each active one. `combineStackEntries` (`repositories.dart:113`) collapses to one regimen per supplement (`regimens.reversed` → first-by-`createdAt` wins), and `findForSupplement` (`:155`) returns `regimens.first`.

If a supplement ever carried two regimens, Today would show doses from both while the Stack card and both planner views described only one. The one-regimen-per-supplement invariant (PF-8) is what prevents this, and it is genuinely well defended: `save()` is single-flight (`regimen_editor_controller.dart:342`), re-checks `findForSupplement` at save time, and refuses a blind-seeded overwrite (`:352`). It is tested three ways — `regimen_editor_controller_test.dart:342/366/377` and `regimen_editor_test.dart:472`.

**Assessment:** a latent divergence guarded by an invariant, not a defect. Noted because the two code paths disagree about what "the" regimen means, and nothing asserts the invariant at the *read* boundary.

### C. `weeksCount(onDays ~/ 7)` truncates a non-multiple-of-7 day count

`schedule_summary_text.dart:50` and `regimen_editor_screen.dart:386` both render `onDays ~/ 7`. A regimen with `onDays = 10` displays as "1 тиждень" — under-reporting by three days on both the Stack card and the planner gantt hint.

The editor cannot produce such a value (sliders step by exactly 7), and `_clampDays` (`regimen_editor_controller.dart:234`) snaps a persisted value onto the week grid when *seeding the draft* — but the **display** path reads the raw persisted `r.onDays`, not the snapped draft value. A future sync backend, a migration, or a test fixture could produce a mismatch between what the card says and what `isActiveOn` actually does.

**Assessment:** unreachable through the shipped UI; a real seam for the v2 sync work. Worth a lint or an assert.

### D. L10N-04 vs. the mockup's 24-hour lock (already noted under L10N-04)

The four `alwaysUse24HourFormat: true` call sites are a deliberate UI-SPEC decision that trades one axis of locale-awareness for mockup fidelity. It does not conflict with L10N-04 as written ("dates, month names and numbers"), and it is consistently applied — but it is the one place where "locale-formatted throughout" is not literally true.

### Checked and found clean

- **REGI-04 pause vs. TRACK-03 missed:** pausing hides *past* pending doses too, so a previously-"missed" dose disappears rather than being re-graded. Documented as intentional (PF-1) and tested (`pause_filter_test.dart`), and resuming restores it with zero writes.
- **TRACK-03 browsing vs. TRACK-04 materialization:** browsing a past day calls `ensureLogsForDay` with the *current* regimen, so editing a cycle changes what past days show. Bounded to the viewed day plus the current week (`week_strip.dart:162` `_WeekWarmer`), with the strip's dot reading through a deliberately non-materializing provider (`providers.dart:139`) — a design that was clearly arrived at by fixing exactly this class of problem.
- **STACK-01 copy-on-add vs. L10N-03 instant switch:** a catalog supplement keeps the name it was added under when the language changes. Documented at `catalog.dart:12` and `add_supplement_sheet.dart:16`, and correct — it is user data, not chrome. The bilingual matrices seed locale-neutral names so the leak sweep isn't confused by it (`locale_matrix.dart:65`).
- **PLAN-02 vs. PLAN-03 limit asymmetry:** the week chip warns at `>=` the limit and the year chip at `>` it. This looks like a bug and is not — it is transcribed deliberately with a stated rationale at `planner_view_model.dart:400` and asserted in both directions (`planner_screen_test.dart:1630` and `:2248`).
- **Debt markers:** zero `TODO`/`FIXME`/`XXX`/`HACK`/`PLACEHOLDER` in `lib/` or `test/`.

---

## Overall verdict

**The milestone claim holds. 21 of 23 requirements are SOLID; 2 are WEAK; none is NOT DELIVERED.**

I went in assuming the prior reports were wrong and tried to break each requirement in four ways — stub implementations, vacuous assertions, unhandled real-world cases, and inverted-feature survival. What I found instead is a codebase where the invariants are enforced in more than one place and the tests assert against the source of truth rather than the rendering of it:

- TRACK-02's undo test reads the **raw `intake_logs` row**, not a widget — it cannot pass with the write dropped.
- TRACK-03's missed test asserts **every row in the whole table** is still pending after browsing a past day.
- PLAN-04 is gated twice: once at the ARB vocabulary level, once as a rendered sweep in both locales, above and below the fold, on both segments.
- L10N-01's plural tests assert exact rendered Ukrainian at 1/2/5/11/21, and `plurals_test.dart:116` explicitly attacks the "every test passed 5" blind spot.
- The three source gates (`no_hardcoded_strings_test`, `new_language_contract_test`, `planner_invariants_test`) each open with a **glob proof that runs first**, because a gate over an empty file set passes vacuously — the authors anticipated the exact failure mode this audit was hunting for.

The two WEAK verdicts are honest limits rather than defects:

- **DATA-02** — the sync-ready half is introspected across every table and is SOLID; the *backup* half is a doc comment with no gate. In a codebase this consistently gated, that asymmetry stands out. **Recommended:** a manifest/plist assertion test (~15 lines) asserting the absence of `allowBackup="false"`, `fullBackupContent`, `dataExtractionRules` opt-outs and `NSURLIsExcludedFromBackupKey`.
- **DATA-03** — `targetSdk = 36` and the completeness of the loop are verified by reading; "builds and runs on iOS and Android" is not verifiable by reading and I did not verify it. It remains a human observation. (Separately: the bundle id is still the placeholder `com.boostque.dev`, which CLAUDE.md itself flags as a pre-release decision.)

Highest-value follow-ups, in order: (1) gate DATA-02's backup clause; (2) run the existing suite once under `TZ=Europe/Kyiv` to convert TRACK-04's DST proof from constructional to executed; (3) add `expectNoCyrillicWhileEn` to the planner's existing English sweep; (4) tighten the two over-broad allowlist entries in `no_hardcoded_strings_test.dart`.

---

*Audited by adversarial reading only. No `flutter` command was executed. `.planning/` documents were deliberately not used as evidence.*
