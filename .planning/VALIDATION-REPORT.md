# Boostque v1 — Independent Re-Verification & Validation

**Date:** 2026-08-16 · **Commit at sign-off:** see `git log -1` · **Verdict: PASS**

This is a second, adversarial pass over the finished v1, run after all five phases were
sealed. Nothing here trusts a prior report: four independent audits re-derived their
conclusions from source, and every gate below was re-run by the orchestrator.

---

## 1. Gates re-run (all green)

| Gate | Result |
|------|--------|
| `flutter analyze` (incl. `integration_test/`) | **0 issues** |
| `flutter test` | **719 passed / 0 failed** |
| `TZ=Europe/Kyiv flutter test` | **719 passed** — DST now proven by execution, not only by design |
| `TZ=Pacific/Auckland flutter test` | **715 passed** (pre-gate baseline) — southern-hemisphere DST, opposite transition direction |
| `data03_loop_test.dart` — iPhone 17 simulator (iOS 26.5), clean install | **pass** |
| `data03_loop_test.dart` — Android emulator API 36, clean install | **pass** |
| `l10n_device_test.dart` — iOS, clean install | **pass** |
| `l10n_device_test.dart` — Android, clean install | **pass** |
| Working tree | clean (one untracked mockup thumbnail, unrelated) |

---

## 2. Audits run (four, independent, adversarial)

| Audit | Artifact | Outcome |
|-------|----------|---------|
| Milestone requirement audit | `MILESTONE-AUDIT.md` | 21 SOLID · 2 WEAK · **0 NOT DELIVERED** — both weak items closed below |
| Cross-phase integration check | `INTEGRATION-CHECK.md` | 5 of 6 flows WORKS; **1 BROKEN** (fixed) |
| Whole-codebase deep review | `FINAL-REVIEW.md` | 1 Critical (same bug, found independently) · 8 Warnings · 6 Info — Critical + all Warnings fixed |
| Security & privacy audit | `SECURITY-AUDIT.md` | Offline claim **PROVEN**; 1 real pre-release item; 1 stale finding corrected |

---

## 3. What the re-verification actually caught

**One genuine blocker, found twice independently.** Editing a regimen's schedule
(start date, on/off weeks, kind, or a shortened course end) did not reconcile doses
already materialized. Today showed live, tappable doses on days the new schedule said
were off, while the planner — computing from the same cycle math by a different path —
correctly showed those days inactive. A user could record "taken" against a dose their
schedule says does not exist. Fixed at the read boundary (`watchDay` re-asks
`isActiveOn` for pending rows) rather than by stamping rows, which would have made
schedule edits irreversible because a soft-deleted log permanently blocks its own
re-materialization. 8 regression tests; 6 confirmed failing against the old code.

**A silent data-loss path in the regimen editor.** Three related defects: an edit typed
while a save was in flight was overwritten by the pre-save snapshot; a second save of
changed data returned the first call's future and reported success without persisting;
and backing out mid-save threw an exception swallowed by a handler meant for write
failures. Fixed as a group, each confirmed red first.

**Dose creation ignored the one-regimen invariant** and materialized doses for every
regimen attached to a supplement — invisible while the invariant held, double-dosing the
moment it didn't. Now routed through one shared accessor used by all three read paths.

**A test that proved nothing.** The only lifecycle test for the app's clock asserted
disposal but could not fail: deleting the disposal hook left it green. Replaced with four
real tests; deleting the hook now fails five.

---

## 4. Gaps the audit named, and how they were closed

| Gap | Status |
|-----|--------|
| DATA-02's "survives reinstall via OS backup" existed only as a doc comment — a one-line manifest edit would break it with the suite green | **CLOSED** — `test/platform_config_test.dart` gates all three Android manifests, iOS sources, and the DB directory choice. Mutation-tested: injecting `android:allowBackup="false"` turns it red. |
| TRACK-04's DST safety proven by construction, never executed off UTC | **CLOSED** — full suite green under `Europe/Kyiv` and `Pacific/Auckland` |
| Cold-start / async `main()` recorded as unmitigated | **CLOSED (record was stale)** — `l10n_device_test.dart` launches through the real `main()`; genuine `am force-stop` + relaunch on Android and a real install+launch on iOS both proven, with wiped-container controls |
| Release builds signed with the debug keystore | **OPEN — pre-release blocker for you.** Asserted in `platform_config_test.dart` so it cannot be forgotten; needs a keystore only you can create. Harmless until distribution. |

---

## 5. Known and accepted (not defects)

- **Instrument Sans has no Cyrillic glyphs**, so Ukrainian renders in the platform font.
  Locked deliberately: the approved mockup renders Cyrillic the same way. Gated so it
  cannot change silently. Manrope is Cyrillic-complete and smaller if you ever want the
  brand font to cover Ukrainian.
- **Bundle id is still the placeholder** `com.boostque.dev`; app name and id are undecided.
- **Physical hardware untested** — simulator and emulator only.
- **Health-adjacent data rides OS backups by design** (so a reinstall restores history).
  Defensible; Android backups are E2E-encrypted with the screen-lock secret, iOS iCloud
  backups are Apple-readable without Advanced Data Protection. Worth disclosing in store
  data-safety forms.
- 6 Info-level review findings and 4 lower-severity security items remain documented and
  deliberately unfixed; none affect correctness or privacy.

---

## 6. Bottom line

All 23 v1 requirements are delivered and independently re-verified against source.
The daily loop — plan, see, mark taken — runs correctly on both platforms, in both
languages, from a real cold start, and stays correct across DST transitions, year
boundaries, schedule edits, pauses, and deletions. The one item standing between this
build and a store submission is the signing key.
