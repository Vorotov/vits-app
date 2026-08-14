# Feature Research

**Domain:** Consumer mobile supplement/medication tracking (stack planner + adherence tracker)
**Researched:** 2026-08-14
**Confidence:** MEDIUM-HIGH (based on public app-store listings, marketing pages, and comparison articles for Medisafe, MyTherapy, Round Health, Dose Streak, Zareva, DoseNote, BodySitRep, JanusMed, SuppCo, Supplements AI, Vitamin & Supplement Tracker, Cronometer/MyFitnessPal; no direct hands-on trials, no primary user-research data — treat quantitative claims (e.g. abandonment rates) as directional, not verified)

## Context: What Boostque v1 Already Decided

v1 scope (from PROJECT.md / design spec) is: stack management (bundled catalog + manual add/edit/delete), dosing regimens (cyclic on/off + one-time course, multiple time slots, pause/resume), Today view (check off taken/skipped, day progress), Cycles planner (gantt + weekly load chart), Year planner (12-month matrix), uk+en i18n, local-only storage. Explicitly deferred: Advisor/recommendations tab, camera/OCR label scanning, home-screen widgets, dose notifications, cloud sync/accounts, interaction/risk scoring, monetization, onboarding flow.

This research validates that scope against the wider market and flags gaps.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in *any* dose-tracking product (supplement or medication). Missing these makes the product feel broken or unfinished, independent of whether it's a "supplement" or "medication" app — the category has converged on a shared baseline.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Add/edit/delete items to track, with dose amount & unit | Universal baseline across every app reviewed (Medisafe, MyTherapy, Round Health, SuppCo, Supplements AI) | LOW | **Covered by v1** (Stack tab). |
| Flexible scheduling: daily, specific weekdays, every-N-days, multi-time-per-day, cycles/on-off | "Supplement & Vitamin Tracker" explicitly markets on/off cycle support as baseline, not a differentiator, in 2026 listings | MEDIUM-HIGH | **Covered by v1**, and v1's cycle math (weeks-on/weeks-off with repeat count) is more rigorous than most competitors, who mostly do simple daily/weekday rules. |
| Daily "today" view grouped by time, one-tap mark taken | Every app in this category leads with this screen (it's the core loop) | LOW-MEDIUM | **Covered by v1** (Today/Calendar). |
| Mark a dose as **skipped/missed**, not just taken | DoseNote, JanusMed, Round Health, MyTherapy all track a taken/skipped/missed tri-state, not a binary; "late doses show as Missed" is called out explicitly as a differentiator-turned-expectation | LOW | **Gap check for v1:** design doc says "taken/skipped" status exists in IntakeLog (pending/taken/skipped) — confirm the *UI* surfaces skip as a first-class action next to "taken," not just a fallback for unmarked. Recommend also surfacing a distinct "missed" state for doses whose time window has passed unmarked, computed rather than stored, so users see accurate adherence without extra data entry. |
| Day/dose history — see what happened on past days | MyTherapy, DoseNote, Zareva, JanusMed, Round Health all ship a history/log view in their *free* tier | LOW-MEDIUM | **Gap in v1 scope as written.** Today view + Cycles/Year planners show *schedule*, but PROJECT.md doesn't explicitly call out "browse what I actually took on day X in the past." This is close to free — Cycles/Year planners already need to query IntakeLog by date range; a past-date Today view (or a simple date picker over the existing Today screen) likely satisfies this with near-zero net-new UI. Recommend folding in rather than treating as new scope. |
| Pause/resume a regimen without deleting it | Explicit v1 requirement already ("pause/resume") | LOW | **Covered by v1.** |
| Bundled/searchable catalog to add from (vs. typing everything by hand) | SuppCo (160k+ items), Cronometer, MyFitnessPal all lead with database size/quality as core value | LOW-MEDIUM | **Covered by v1** ("add from bundled catalog or manually"). Catalog can start small (common supplements) — size is a differentiator, not table stakes, for a niche stack-planner. |
| Non-medical, "educational only" disclaimer on anything resembling advice | Every interaction-checker and dosing tool reviewed carries this (WebMD, HelloPharmacist, SupliCore, Pure Encapsulations) — legal/liability norm for the category | LOW | **Already a stated constraint** in PROJECT.md copy vocabulary. Confirm it appears not just where the (deferred) Advisor tab would live, but anywhere the app shows concurrent-substance counts or cycle "load" — the mockup's 5-substance concurrent limit is editorial and must never read as a safety threshold. |
| Progress/completion indicator for "today" | Universal (progress ring, checklist, percentage) | LOW | **Covered by v1** ("day progress"). |
| Multi-language / localization for non-US markets | Less universal in this specific category (most competitors are English-only or auto-translated), but table stakes for *this* product given target market | MEDIUM-HIGH | **Covered by v1**, and is a genuine differentiator vs. the competitor set (see below) since almost none of the reviewed apps ship real uk localization with correct ICU plurals. |

### Differentiators (Competitive Advantage)

Features that set a product apart. Valuable, but a v1 without them is still complete and shippable — these are where Boostque could win *after* v1, or where its existing scope already beats competitors without extra work.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Cycles gantt + weekly concurrent-load chart | No competitor reviewed visualizes multi-supplement cycle overlap this way — Medisafe/MyTherapy/Round Health are single-list-of-meds apps with no "what's stacked when" view; this is Boostque's structural bet | HIGH | **Already v1 scope** — this is the product's actual differentiator, not a nice-to-have. Protect it from scope-cutting pressure more than any other v1 item. |
| Year planner (12-month coverage matrix) | Long-horizon supplement protocols (e.g. seasonal, quarterly cycling) have no equivalent in medication-reminder apps, which assume indefinite daily use | HIGH | **Already v1 scope.** Genuinely novel relative to the competitor set researched. |
| Streaks / adherence-consistency visualization | Round Health and Dose Streak both center their entire value prop on this (streak, year-heatmap); shown to be motivating for gamification-receptive users | LOW-MEDIUM | **Not in v1 scope — correctly deferred.** Cheap to add later once IntakeLog has real history (pure derived query, no schema change), but risks feeling punitive/guilt-inducing for a supplement-cycling context where "off" days are *intentional*, not missed doses — needs care so cycle-off days don't count against a streak. Good v1.1 candidate, not urgent. |
| Home-screen widgets (mark-as-taken from widget) | "Supplement & Vitamin Tracker" explicitly markets this; removes a full app-open just to check off | MEDIUM-HIGH (native platform work, per-OS) | **Correctly deferred per PROJECT.md**, and the "dose occurrences materialized as DB rows" decision is exactly right — it's what makes this cheap to bolt on later. Ranked here as high-value-but-not-day-one because it multiplies native platform surface area (iOS WidgetKit + Android App Widgets = real engineering, not incremental). |
| Dose notifications/reminders | The single most universally advertised feature across every medication app reviewed (Medisafe, MyTherapy, Round Health, Zareva, DoseNote all lead marketing with it) | MEDIUM | **Correctly deferred for v1, but flagged as the highest-priority post-v1 addition.** Unlike widgets, this isn't a "nice differentiator" — for medication-style apps it is closer to table stakes; supplement-stack users are more forgiving (see Anti-Features), but expect it soon after launch. Because IntakeLog rows are pre-materialized, this is schedule-a-local-notification-per-row, not a redesign — low technical risk, should be the first thing built after v1 ships. |
| Camera label / barcode scanning to add a supplement | SuppCo, MyFitnessPal (barcode) both offer this to reduce manual-entry friction | HIGH (OCR/vision pipeline or barcode DB licensing) | **Correctly deferred.** High implementation cost for a v1 whose stack sizes are typically small (a handful of supplements) — manual/catalog add is adequate at v1 scale. Reconsider only if user research shows entry friction is a real drop-off point. |
| Interaction / risk scoring between stacked items | SuppCo "stack analysis algorithm," Supplements AI "avoid interferences," multiple standalone interaction-checker tools (WebMD, HelloPharmacist) | HIGH (requires licensed/maintained interaction database, ongoing accuracy liability) | **Correctly deferred**, and should stay deferred longer than notifications/widgets — this is the single highest-liability feature in the category (every competitor wraps it in heavy disclaimers) and directly overlaps with the also-deferred Advisor tab. Do not build a lightweight/naive version as a shortcut; it's a "do it right or don't do it" feature. |
| Cloud sync / multi-device / backup | Table stakes for retention-focused competitors (Medisafe, MyTherapy) but the whole category also has viable local-only apps (Round Health free tier is push-only, no account) | HIGH (backend, auth) | **Correctly deferred**, and the "backend-ready architecture" decision (repository pattern, UUIDs, soft deletes) is the right hedge — validates the local-only choice for v1 without foreclosing sync later. |
| Export dose history (CSV/PDF) to share with a doctor | Zareva (PDF/CSV), BodySitRep (CSV), DoseNote (PDF/CSV, paywalled past 30 days) all offer this | LOW-MEDIUM | **Not in v1 scope.** Lower priority than notifications for a *supplement* (not prescription-medication) app — the "share with my doctor" use case is weaker for OTC supplements than for prescriptions. Reasonable v1.x candidate once a history view exists, but not urgent; don't let it block v1. |
| Refill / running-low tracking | Medisafe, MyTherapy, several refill-specific apps treat this as standard | MEDIUM | **Not in v1 scope and lower priority than it looks.** Research note: refill countdown quality depends entirely on consistent dose logging (drifts if users miss logging), and it's a secondary feature even in mature competitors. Reasonable candidate only after adherence data (skip/miss accuracy) is trustworthy. |
| "Med-friend" / caregiver notifications on missed dose | Medisafe's headline differentiator | HIGH (multi-user, notifications, likely requires accounts/backend) | Out of scope for the foreseeable future — this product's audience (self-directed supplement stackers) doesn't match the caregiver/elder-care use case this feature targets. Not recommended even post-v1 unless the target audience shifts. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems for *this specific product* (a self-directed supplement stack planner, not a prescription-adherence/caregiver tool).

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Aggressive default notification cadence (multiple reminders per dose, escalating alerts) | Feels like it should improve adherence, mirrors clinical alert systems | Documented alert fatigue: repeated/irrelevant alerts drive notification dismissal and app deletion; clinical alert-fatigue research generalizes directly to consumer health apps | When notifications ship (post-v1), default to exactly one reminder per scheduled time slot, snoozable, with an easy per-supplement or global off switch — never stack multiple nags per dose |
| Guilt-oriented streak/adherence messaging on intentional cycle-off days | Gamification is proven motivating (Round Health, Dose Streak) | Boostque's cycles are *by design* — a week "off" is correct behavior, not a lapse; a naive streak counter would punish the exact feature (cycling) that differentiates the product | If/when streaks are added, compute them only over scheduled/"on" days, explicitly excluding cycle-off periods from both numerator and denominator |
| Naive/lightweight interaction warnings built ad hoc (e.g. static keyword matching) as a cheap stand-in for full interaction checking | Feels achievable without licensing a real interaction database | False negatives create real safety risk and liability; every legitimate competitor treats this as a heavy, disclaimer-wrapped, professionally-sourced feature — a cut-rate version is worse than none because it implies false confidence | Keep this fully deferred until it can be built properly (licensed database, pharmacist-reviewed, clear disclaimers) as part of the future Advisor tab; never ship a partial version |
| Social/sharing features (public stacks, following other users' regimens) | Common growth-hacking instinct for consumer health apps | Supplement regimens are sensitive personal-health data; none of the competitors reviewed in this niche ship social features, and it invites both privacy and medical-liability exposure with no evidence of demand in this category | None needed for this product; if community discovery is ever wanted, keep it read-only/editorial (e.g. curated protocol templates), never user-to-user sharing of personal logs |
| Auto-adjusting "smart" reminder times based on inferred behavior/location | Marketed by "Supplements AI" as an AI differentiator | Adds complexity and unpredictability to the one thing users most need to trust (does my reminder fire when I expect); opaque "smart" scheduling erodes trust faster than it builds convenience for a low-frequency-use case like supplements | Simple, user-set, fully predictable reminder times per slot — if convenience features are wanted later, make timing adjustments explicit and user-confirmed, not silent |
| Treating the 5-substance "concurrent" count (or any other editorial mockup number) as a safety/medical threshold | Natural temptation once the number exists in the UI, to imply "more than this is risky" | It is explicitly editorial per the mockup, not derived from any clinical source (Key Decisions: "5-substance concurrent limit is editorial, not medical, shown with disclaimer") — presenting it as a limit invites both bad advice and liability | Keep it framed purely as information ("X substances scheduled at once") with the existing disclaimer, never as a warning/limit UI pattern (no red/risk coloring implying danger) |

## Feature Dependencies

```
Dose occurrences materialized as DB rows (v1, already decided)
    └──enables──> Home-screen widgets (post-v1)
    └──enables──> Dose notifications (post-v1)
    └──enables──> Refill/running-low tracking (post-v1, needs consistent logging too)

History/log view (near-free extension of Today view + existing IntakeLog queries)
    └──enables──> Streaks / adherence visualization (post-v1)
    └──enables──> Export dose history to CSV/PDF (post-v1)

Skip vs. Missed distinction (recommend clarifying in v1 UI, not just data model)
    └──required-by──> Streaks (must exclude/handle missed correctly)
    └──required-by──> Any future adherence-percentage reporting

Bundled catalog (v1)
    └──enhances──> Camera/barcode scanning (post-v1; scanning still needs a catalog to resolve into)

Interaction/risk scoring (deferred, high liability)
    └──conflicts──> "ship early / cheap version" instinct — must not be built incrementally as a shortcut
    └──shares-scope-with──> Advisor tab (also deferred) — likely same future milestone

Cloud sync / accounts (deferred)
    └──enabled-by──> Repository pattern + UUIDs + soft deletes (already in v1 architecture)
    └──required-by──> "Med-friend"/caregiver notifications (not recommended for this product at all)
```

### Dependency Notes

- **Materialized dose rows enable widgets/notifications/refill tracking:** this was the single most load-bearing architectural decision found in PROJECT.md, and it's validated by the research — every competitor with these features needs exactly this kind of precomputed "today's doses" table.
- **History view is nearly free but currently unscoped:** Cycles/Year planners already require date-ranged IntakeLog queries; a simple past-date Today view reuses that machinery. Recommend treating this as a v1 nice-to-confirm rather than a new phase.
- **Skip vs. Missed distinction gates streaks and any adherence percentage:** don't wait until streaks are requested to get this right — decide the semantics (is an unmarked past dose "missed" automatically, or does it stay "pending" forever?) during v1 so the data model doesn't need a migration later.
- **Interaction scoring and Advisor tab share scope and liability profile:** plan them together in a future milestone rather than let interaction-checking sneak in piecemeal via some other feature (e.g. "helpful tips" on the stack screen).
- **Cloud sync is a prerequisite for caregiver features, not the reverse:** since caregiver/"med-friend" features are not recommended for this product's audience, this dependency chain is a reason to *deprioritize* sync further, not a reason to build it sooner.

## MVP Definition

### Launch With (v1) — as already scoped, with one adjustment recommended

- [x] Stack management (bundled catalog + manual, edit, delete) — essential, already scoped
- [x] Cyclic + one-time dosing regimens, multi-slot, pause/resume — essential and the product's core differentiator groundwork
- [x] Today view: mark taken/skipped, day progress — essential, the daily loop
- [x] Cycles planner (gantt + load chart) — essential differentiator, do not cut
- [x] Year planner — essential differentiator, do not cut
- [x] uk + en i18n — essential per stated requirement and a real market differentiator
- [x] Local-only storage — correct for v1, validated against the "sync isn't table stakes for this niche" finding
- [ ] **Recommended addition, low cost:** confirm/verify Today view supports navigating to past dates (history-lite), and that unmarked past doses render distinctly from "pending today" (i.e., some visual "missed" treatment) — this closes the one table-stakes gap the research surfaced inside otherwise-decided v1 scope, at near-zero incremental cost given the Cycles/Year planners already need date-ranged queries.

### Add After Validation (v1.x)

- [ ] Dose notifications — trigger: v1 ships and daily-use retention data shows people forget to open the app; highest-value, lowest-risk addition given materialized dose rows already exist
- [ ] Home-screen widgets — trigger: after notifications, once there's evidence users want faster check-off than opening the app
- [ ] Streaks/adherence visualization — trigger: once history view has enough real data to be meaningful, and only after nailing the on/off-cycle-aware streak logic
- [ ] Export history (CSV/PDF) — trigger: user request for sharing data externally (e.g. with a doctor/nutritionist)
- [ ] Refill/running-low tracking — trigger: after logging behavior is consistent enough that countdown math is trustworthy

### Future Consideration (v2+)

- [ ] Camera/barcode scanning — defer until manual/catalog entry is shown to be a real friction point (typical supplement stacks are small; low urgency)
- [ ] Interaction/risk scoring + Advisor tab — defer until ready to invest in a licensed, professionally-reviewed data source; do not build a lightweight version
- [ ] Cloud sync/accounts — defer until multi-device use is a validated user need; architecture already supports adding it without rework
- [ ] Monetization — defer per existing decision; needs a validated user base first

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Stack management | HIGH | LOW | P1 (v1, done) |
| Cyclic/one-time regimens | HIGH | HIGH | P1 (v1, done) |
| Today view + mark taken/skipped | HIGH | MEDIUM | P1 (v1, done) |
| Cycles planner | HIGH | HIGH | P1 (v1, done — core differentiator) |
| Year planner | MEDIUM-HIGH | HIGH | P1 (v1, done — core differentiator) |
| uk+en i18n | HIGH | MEDIUM-HIGH | P1 (v1, done) |
| Past-date history / missed-state visibility | MEDIUM-HIGH | LOW | P1 (recommend folding into v1) |
| Dose notifications | HIGH | MEDIUM | P2 (first post-v1) |
| Home-screen widgets | MEDIUM | MEDIUM-HIGH | P2 |
| Streaks/adherence viz | MEDIUM | LOW-MEDIUM | P2 |
| Export history | LOW-MEDIUM | LOW-MEDIUM | P3 |
| Refill tracking | LOW-MEDIUM | MEDIUM | P3 |
| Barcode/camera scanning | LOW (at this stack size) | HIGH | P3 |
| Interaction/risk scoring | MEDIUM (high perceived value, high liability) | HIGH | P3, deliberately slow-walked |
| Cloud sync | LOW (for current niche) | HIGH | P3 |
| Caregiver/"med-friend" alerts | LOW (audience mismatch) | HIGH | Not recommended |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible (soon after v1)
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Medisafe / MyTherapy (medication-reminder leaders) | SuppCo / Supplements AI (supplement-stack apps) | Round Health / Dose Streak (adherence-gamification apps) | Boostque's Approach |
|---------|------|------|------|------|
| Scheduling model | Daily/weekday/interval rules; single-med focus | Daily/weekday/interval/cycle rules; stack-of-items focus | Simple daily rules, adherence-first | Richer: explicit weeks-on/weeks-off cycles + one-time courses, multi-slot — most rigorous of the set |
| Multi-item visualization | List-based; no overlap/timeline view | List/timeline (Supplements AI has a daily timeline) | List-based | Gantt (Cycles) + 12-month matrix (Year) — no competitor reviewed has this |
| Interaction checking | Medisafe: premium drug-interaction warnings | SuppCo: "stack analysis algorithm"; Supplements AI: "avoid interferences" | None | Deliberately deferred; will require licensed data if built |
| Reminders/notifications | Core, heavily marketed | Present, "intelligent"/adaptive in some | Core (push-based) | Deferred for v1; planned first post-v1 addition |
| Widgets | Some (varies) | "Supplement & Vitamin Tracker": widget with mark-as-taken | Not emphasized | Deferred for v1; enabled cheaply later by materialized dose rows |
| Streak/gamification | Not core | Not core | Core value prop (Round Health, Dose Streak) | Deferred; needs cycle-aware logic before adding |
| History/export | MyTherapy: history view free; several apps: CSV/PDF export | Limited/unclear from marketing pages | Dose Streak: year heatmap, archived history | Recommend folding a lightweight history view into v1; export deferred |
| Localization | Primarily English-market | Primarily English-market | Primarily English-market | uk+en from day one — clear differentiator vs. this entire competitor set |
| Data model transparency (local-only, no account) | Mostly account-based (sync-first) | Mixed | Round Health: no-account free tier | Local-only v1 with backend-ready architecture — matches the more privacy-conscious end of the market |

## Sources

- [Best Medication Tracker App: 7 Options Compared (2026)](https://www.yougot.ai/blog/health/medication-reminders/medication-tracker-app)
- [7 Medication Reminder Apps: An Honest Comparison](https://pillapp.io/blog/eng/ia7t36t911-7-medication-reminder-apps-an-honest-com)
- [Best Pill Reminder App 2026: 6 Apps Compared](https://www.donedose.com/guides/best-pill-reminder-app)
- [Free Medisafe Alternative: The Best Medication Apps for 2026](https://www.mytherapyapp.com/blog/medisafe-alternatives-free)
- [The 7 best prescription reminder apps and tools (SingleCare)](https://www.singlecare.com/blog/best-medication-reminder-apps/)
- [Best Medication Reminder Apps in 2026: 8 Honest Picks Compared (MedRemind)](https://medremindapp.com/blog/best-medication-reminder-apps-2026)
- [Dose Streak: Med Reminders — App Store](https://apps.apple.com/us/app/dose-streak-med-reminders/id6755611965)
- [Export Apple Health Medications, Dose History to CSV/JSON](https://healthsave.app/guides/export-apple-health-medications/)
- [Zareva — Free Medication Reminder & Wellness Companion](https://zareva.app/)
- [Best Medication Tracking App | Adherence and Side Effects (BodySitRep)](https://www.bodysitrep.com/blog/best-medication-tracking-app)
- [Medication Tracking: Never Miss a Dose Again (JanusMed)](https://janusmed.app/resources/guides/medication-tracking-guide/)
- [Vitamin & Supplement Tracker — App Store](https://apps.apple.com/us/app/vitamin-supplement-tracker/id6754193458)
- [Supplements AI – Stack Tracker — App Store](https://apps.apple.com/us/app/supplements-ai-stack-tracker/id6741800649)
- [Supplement & Vitamin Tracker — App Store](https://apps.apple.com/us/app/supplement-vitamin-tracker/id6759703178)
- [SuppCo: Supplement Scanner — App Store](https://apps.apple.com/us/app/suppco-supplement-scanner/id6504838951)
- [Best Supplement Tracker App | Log Doses & Set Reminders (CareClinic)](https://careclinic.io/supplement-tracker/)
- [Cronometer Alternatives (2026): An Honest Comparison](https://www.hootfitness.com/blog/cronometer-alternatives-find-the-best-fit-for-your-tracking-style)
- [Cronometer Vs MyFitnessPal: Which is the Best Nutrition App?](https://neura.health/insight/cronometer-vs-myfitnesspal-which-is-better)
- [Drug-supplement interaction checker (HelloPharmacist)](https://hellopharmacist.com/drug-supplement-interactions)
- [Drug Interaction Checker (WebMD)](https://www.webmd.com/interaction-checker/default.htm)
- [Supplement Interaction Checker (SupliCore)](https://suplicore.com/interaction-checker)
- [Medication safety alert fatigue may be reduced via interaction design and clinical role tailoring: a systematic review (JAMIA, Oxford Academic)](https://academic.oup.com/jamia/article/26/10/1141/5519579)
- [Prescription Refill Reminder App Comparison: 4 Best Options](https://www.yougot.ai/blog/health/medication-reminders/prescription-refill-reminder-app)
- [13 Best Medication Reminder Apps (2026 Review) — Caring Village](https://caringvillage.com/blog/caregiver-tech/medication-reminder-apps/)
- Internal: `/Users/dima/supplements/.planning/PROJECT.md`, `/Users/dima/supplements/docs/superpowers/specs/2026-08-14-boostque-v1-design.md`

---
*Feature research for: consumer mobile supplement/medication tracker (Boostque)*
*Researched: 2026-08-14*
