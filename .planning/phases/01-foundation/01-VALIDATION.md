---
phase: 1
slug: foundation
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-14
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter 3.47) + mocktail |
| **Config file** | none — Wave 0 installs (flutter create scaffolds test/) |
| **Quick run command** | `flutter test <changed test file>` |
| **Full suite command** | `flutter analyze && flutter test` |
| **Estimated runtime** | ~30–60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test <task's test file>`
- **After every plan wave:** Run `flutter analyze && flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-T1 | 01-01 | 1 | DATA-01 | T-01-SC | Exact approved dep names asserted; no networking package; no network permission in main manifest | smoke widget + build + grep gates | `flutter analyze && flutter test test/smoke_test.dart` (+ both-platform builds, manifest/pubspec greps) | ❌ created by task | ⬜ pending |
| 01-01-T2 | 01-01 | 1 | DATA-01 | T-01-01 | Font binaries from canonical google/fonts paths; >100KB size sanity; single fonts: entry per family | asset + grep gates | `flutter analyze && flutter test` (+ font file size/pubspec greps) | ❌ created by task | ⬜ pending |
| 01-02-T1 | 01-02 | 2 | DATA-01 | T-01-04 | Constructor range validation (minutesFromMidnight 0..1439, non-negative on/off days) | unit | `flutter test test/domain/models_test.dart` | ❌ created by task | ⬜ pending |
| 01-02-T2 | 01-02 | 2 | DATA-01 (exit criterion D-16) | T-01-05 | UTC-only date math; no wall-clock reads in domain | unit (DST + year boundary) | `flutter test test/domain/cycle_math_test.dart` | ❌ created by task | ⬜ pending |
| 01-03-T1 | 01-03 | 2 | DATA-01 | T-01-06 | Token-only palette (exact hex assertions) | unit | `flutter test test/theme/theme_test.dart` | ❌ created by task | ⬜ pending |
| 01-03-T2 | 01-03 | 2 | DATA-01 | T-01-06 | Theme built exclusively from tokens (no raw hex in theme.dart) | unit + grep gate | `flutter test test/theme/theme_test.dart` | ❌ created by task | ⬜ pending |
| 01-04-T1 | 01-04 | 2 | DATA-01 | T-01-08 | gen-l10n pipeline present (generate:true + synthetic-package:false) | unit (uk plurals 1/2/5/11/21) | `flutter gen-l10n && flutter test test/l10n/plurals_test.dart` | ❌ created by task | ⬜ pending |
| 01-04-T2 | 01-04 | 2 | DATA-01 | T-01-07 | Stored locale sanitized to {en, uk} else system | unit | `flutter test test/l10n/locale_controller_test.dart` | ❌ created by task | ⬜ pending |
| 01-05-T1 | 01-05 | 3 | DATA-02 | T-01-09 | SyncColumns on all 4 tables; (slotId,date) unique; UTC datetime round-trip; no auto-increment | unit (in-memory Drift) | `flutter test test/db/database_test.dart` | ❌ created by task | ⬜ pending |
| 01-05-T2 | 01-05 | 3 | DATA-02 | T-01-10 | Schema v1 snapshot exported; OS-backup defaults untouched (manifest/plist grep gates) | artifact + grep gates | `flutter test` (+ snapshot existence, backup-default greps) | ❌ created by task | ⬜ pending |
| 01-06-T1 | 01-06 | 3 | DATA-01 | T-01-12 | No Drift import in features; no literal Text strings; EdgeInsetsDirectional only | analyze + grep gates | `flutter analyze` (+ grep gates) | n/a (gates) | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | DATA-01 | T-01-13 | supportedLocales whitelist en-first fallback | widget (en + uk labels, switching, overflow) | `flutter test test/widget/app_shell_test.dart` | ❌ created by task | ⬜ pending |
| 01-07-T1 | 01-07 | 4 | DATA-01, DATA-02 | T-01-16 | Soft-delete only (no delete-statement calls); updatedAt bumped on every mutation; deterministic ordering | unit (in-memory Drift) | `flutter test test/db/repositories_test.dart` | ❌ created by task | ⬜ pending |
| 01-07-T2 | 01-07 | 4 | DATA-01, DATA-02 | T-01-14 | insertOrIgnore-only materialization (region-scoped gate); status preservation regression test | unit (idempotence, off-day, same-minute slots) | `flutter test test/db/repositories_test.dart` | ❌ created by task | ⬜ pending |
| 01-07-T3 | 01-07 | 4 | DATA-01 | T-01-15 | Providers typed against interfaces; no stream-combinator hand-rolling | unit (ProviderContainer, empty fresh DB) | `flutter test test/providers_test.dart && flutter analyze && flutter test` | ❌ created by task | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `flutter create` scaffold provides test/ harness and flutter_test dependency
- [ ] mocktail added as dev dependency before first repository test

*Everything else: scaffold task creates the infrastructure as its deliverable.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Shell renders correctly on both platforms with mockup styling | DATA-01 (offline shell) | Visual fidelity can't be pixel-asserted in widget tests | `flutter run` on iOS simulator and Android emulator; compare tab bar/headers against mockup screen 01 footer |
| uk NavigationBar labels don't clip (FittedBox backstop) | UI-SPEC backstop | Visual scale-down behavior | Run app in uk locale, inspect Налаштування label |
| DB file located in OS-backup-included directory | DATA-02 | Filesystem location assertion is platform-runtime specific | Verify DB path prints under app documents dir on both platforms at first run |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
