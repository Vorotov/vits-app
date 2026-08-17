---
phase: 07-dose-reminders
checked: 2026-08-17
checker: orchestrator (the gsd-ui-checker subagent died to transient API 529 four times
  before its first write; the crux items were re-derived by hand instead)
verdict: PASS with 3 FLAGs, 0 BLOCKs
---

# Phase 7 UI-SPEC — check

## What was verified by derivation, not by trust

### Ukrainian plurals — PASS

Derived independently from CLDR's Ukrainian cardinal rules rather than read off the
contract's own table:

- `one`: v=0 ∧ i%10=1 ∧ i%100≠11
- `few`: v=0 ∧ i%10∈2..4 ∧ i%100∉12..14
- `many`: v=0 ∧ (i%10=0 ∨ i%10∈5..9 ∨ i%100∈11..14)
- `other`: everything else — i.e. only values with a fractional part

| n | Rule | Contract's form | Verdict |
|---|------|-----------------|---------|
| 1 | one | `1 прийом` | correct — nominative singular |
| 2 | few | `2 прийоми` | correct — 2..4 takes nominative plural |
| 5 | many | `5 прийомів` | correct — genitive plural |
| 11 | many | `11 прийомів` | correct — the 11..14 exception |
| 21 | one | `21 прийом` | correct — i%10=1, i%100=21≠11 |
| 22 | few | `22 прийоми` | correct |
| 25 | many | `25 прийомів` | correct |

English `one`/`other` is correct.

### DECIDED-6's unreachability claim — PASS

The claim that `other` is unreachable for an `int` in Ukrainian is **true**: every branch of
Ukrainian's `other` requires v≠0, and `count` is declared `{"type": "int"}`. Mirroring `few`
into `other` is therefore unobservable in production and matches what 5 of the 7 existing
Ukrainian plural keys already do. Accepted as house consistency.

### DECIDED-12's bootstrap shape — PASS on pattern

Checked against the real `lib/main.dart`. The proposed shape — resolve in the `main()` window,
guard with try/catch, report via `FlutterError.reportError`, degrade to the default rather than
rethrow — is exactly the pattern the `SharedPreferences` bootstrap already carries, including
the stated reason (an escaping error between `ensureInitialized()` and `runApp()` means runApp
is never called and the user stares at the launch screen). Consistent with locked history. See
FLAG-3 for what should NOT join it in that window.

---

## FLAG-1 — DECIDED-7's central argument rests on a premise it does not state

The contract declines a priming sheet on the grounds that "a pre-prompt's whole value is
deferral", that deferral needs a later ask, and that the later ask is deferred — so a primer
would deliver an "identical outcome" plus extra surface.

That is true of a primer offering **"Not now"**. It is not true of the other standard shape: a
primer whose only affordance is *continue*, which defers nothing and exists purely to raise the
grant rate by supplying context before an irreversible choice. The contract does not consider
that shape, so "identical outcome" is asserted about a design it did not evaluate.

Not a BLOCK — the sequencing argument (the dialog lands immediately after the user saved a
schedule full of times) is genuinely strong priming, and the phase adding no UI is worth real
money. But the rationale should say which primer shape it rejected and why, rather than
generalising from one.

## FLAG-2 — DECIDED-7 and DECIDED-9 compound, and the contract prices them separately

Each decision is defensible alone. Together they produce one path with no exit:

1. The OS dialog appears bare, with no context of ours (DECIDED-7).
2. A reflexive "Don't Allow" on iOS cannot be re-requested from inside the app, and v1.1 ships
   no re-ask path (DECIDED-7's stated cost, spec §2.6).
3. The app then shows **nothing, anywhere, ever** to indicate reminders are not working —
   even though `areNotificationsEnabled()` / `checkPermissions()` can detect it (DECIDED-9).

So a single mis-tap silently disables the phase's entire feature, permanently, with no feedback
and no recovery. Each document prices its own decision honestly; neither prices the
composition. This is the finding worth escalating to the project owner, and it is escalated.

The reason DECIDED-9 gives for keeping this out of the existing Settings screen — that the
Phase-5 screen-scope invariant forbids a numeral under `features/settings/` — inverts the
priority. That invariant exists to keep a settings screen from growing into a dashboard; using
it to justify not telling the user their reminders are off is the invariant outranking the
truth. A permission-state row needs no numeral at all (the *magnitude* belongs to the tier-B
sentence, which genuinely can wait for the deferred screen).

## FLAG-3 — Do not let the whole notification bootstrap into the pre-`runApp` window

DECIDED-12 correctly requires `getNotificationAppLaunchDetails()` before `runApp`: its answer
seeds frame 1, and a Стек frame that jumps to Сьогодні is the defect it is avoiding. But
07-RESEARCH §7.3 and §8.7 additionally place `tz.initializeTimeZones()` (via `latest_all.dart`,
~1 MB of zone data), the plugin's `initialize()`, and `createNotificationChannel()` in the same
window. Only the launch-details read has a first-frame dependency.

The existing cold-start guarantee cannot catch a regression here: `l10n_device_test.dart`
asserts the shell paints on **frame 1** — a frame count, not a wall-clock budget — so an extra
150 ms of zone-database parsing before the first frame would leave every test green and every
cold start slower.

Required of the plan: only the launch-details read is permitted before `runApp`. Timezone
initialization, plugin init and channel creation happen after the first frame, and nothing
scheduled may run before timezone init completes. If the plan disagrees, it must carry a
measured cold-start number, not an argument.

---

## Dimension verdicts

This phase renders almost nothing in Flutter — the notification text is drawn by the OS — so
copy, l10n and registry safety carry the risk, and the visual dimensions reduce to verifying
the contract's claim that it introduces no widgets, tokens or theme changes.

| Dimension | Verdict | Note |
|---|---|---|
| 1 Copywriting | **PASS** | Plurals independently verified. Two prohibitions (no supplement name in title/body/payload; the service structurally cannot learn a name) are stated as security controls and are grep-checkable. One nit below. |
| 2 Visuals | **PASS** | Claims no new widget/screen; sign-off conditions 25–27 make that mechanically checkable via `git diff --stat` and a token grep. |
| 3 Color | **PASS** | No token use, `AndroidNotificationDetails.color` deliberately unset, gated by a source check. |
| 4 Typography | **PASS** | Not applicable — OS-rendered. Correctly stated rather than padded. |
| 5 Spacing | **PASS** | Not applicable — OS-rendered. |
| 6 Registry Safety | **PASS** | Channel id `doses_v1` not versioned so user customizations survive; payload whitelisted by equality as untrusted, replayable OS-persisted input. |

**Copy nit (not a FLAG):** the constant English title "Time for your doses" reads slightly wrong
against a `count = 1` body ("1 dose"). Ukrainian «Час прийому» has no such mismatch because it
is uninflected for number. Either accept it or pick a number-neutral English title; a constant
title is still the right call.

## Sign-off conditions — mechanical checkability

Reviewed for whether an executor can verify each without judgement. Conditions 24–27 (source
greps, `git diff --stat`, the allowlist entry count) are mechanical. The plural fixtures at
1/2/5/11/21 are mechanical and should be extended to 22 and 25 as the contract itself suggests.

Not mechanically checkable as written, and needing restatement by the planner:

- Any condition of the form "the notification reads correctly on a lock screen" — device
  observation, not a check. Should be moved to the phase's UAT list explicitly.
- FLAG-3's cold-start concern has no condition at all. If the plan keeps work in the pre-`runApp`
  window, it needs a measured budget to be checkable.

## Approval

**PASS with 3 FLAGs, 0 BLOCKs.** FLAG-1 and FLAG-3 are for the planner to absorb. FLAG-2 is a
product decision and is being put to the project owner before planning proceeds.
