## Inspiration

Half the things people take have a cycle attached: eight weeks on, four weeks
off; a course that ends on a date; something that only runs on weekdays. Every
tracker I tried treats a supplement as a checkbox that repeats forever, so the
cycle lives in your head and the breaks get missed. That is a calendar problem,
not a list problem, and nobody had drawn it.

VitoMy is the answer to one question: *what do I take today, and when does this
one stop?*

## What it does

You add what you take, set the schedule once — on weeks, off weeks, a fixed
course, one or several times a day — and the app keeps the calendar.

- **Today** shows the doses due, with the time beside each one. Tap to mark one
  taken. The progress ring fills as the day goes, and an unmarked dose is
  described neutrally, never as a failure.
- **Cycles** draws every schedule as a bar across the months, with the breaks
  hatched, so overlaps and gaps are visible rather than inferred.
- **Year** is the same information at twelve-month range: which months are
  covered, which ones stack up.
- **Reminders** are local notifications that never name a supplement, in the
  title or the body, because a lock screen is a public surface.

Everything is on the device. No account, no sign-up, no server, no analytics.
The app ships in seven languages — English, Arabic, Spanish, French, Hindi,
Ukrainian, Chinese — with real right-to-left layout for Arabic, including a
hand-mirrored gantt painter.

## How I built it

One Flutter codebase, Dart 3.13. Riverpod for state, with hand-written
providers rather than codegen. Drift over SQLite for storage, with UUID keys,
soft deletes and explicit `createdAt` / `updatedAt` on every row, so a sync
backend can arrive later without touching a screen.

The architecture rule is one line: screens depend on repository *interfaces*;
Drift is one implementation, wired in exactly one file. The same rule is what
made RevenueCat cheap to add.

**RevenueCat** powers three consumable tips that unlock nothing. That was a
deliberate product decision, not a shortcut:

- A tip is a **consumable**, so it is repeatable, and Apple's guideline 3.1.1
  permits developer tips outright. Consumables are not restorable, which
  removes the Restore control and the anonymous-reinstall problem in one go.
- **No entitlement.** Attaching a consumable to an entitlement makes RevenueCat
  report it unlocked forever after a single purchase, which would be a lie in
  an app with nothing to unlock.
- **No Paywalls SDK.** RevenueCat Paywalls do not support consumables, so the
  tip screen is hand-built from the app's own design tokens, like every other
  screen.
- `purchases_flutter` is importable from **exactly one file** in the codebase,
  behind a `PurchaseGateway` interface. Four tests keep it there, and three
  more assert the purchase layer cannot reach the database, the domain, or
  either supplement stream. That is what lets the privacy policy say the stack
  never leaves the device and mean it.

Tests: 1167 on every run, plus 48 more that only run before a release — a
medical-vocabulary sweep across all seven languages, and every main screen
rendered in all seven at text scales 1.0, 1.6 and 2.0.

## Challenges I ran into

**Apple rejected the build for a bug that was not in the build.** Guideline
2.1(b): "the In-App Purchase products were not available for purchase at the
time of reviewing." Everything in App Store Connect was correct — three
approved products, agreements signed, bank and tax forms active — so the
obvious readings were all wrong.

The app reads `offerings.current`, and a missing offering returns an empty list
that the screen renders as "unavailable", which looks exactly like a network
failure. So I built a throwaway diagnostic that asked the same question down
two different paths on a real device: `getOfferings()`, which goes through
RevenueCat's dashboard configuration, and `getProducts(ids)`, which bypasses it
and asks StoreKit directly.

The answer was unambiguous. `getProducts` returned all three with real prices;
`getOfferings` threw `CONFIGURATION_ERROR` — "no App Store products registered
in the RevenueCat dashboard for your offerings." App Store Connect was perfect;
the products had never been attached to the offering. No code change, no new
build, one dashboard fix, verified on the device before resubmitting.

**A green test that had stopped being true.** The platform-config test asserted
the app declares no INTERNET permission. It kept passing after RevenueCat
landed, because `purchases-android` declares INTERNET in its *own* library
manifest and it merges in at build time, while the test reads the source
manifests. The assertion was rewritten to claim only what it can see, and the
real guarantee moved to a test that asserts exactly one network-capable
dependency and names it.

**Adding an SDK changes your legal documents.** The privacy policy said no data
leaves the device. With a purchase provider in the build, that sentence needed
narrowing rather than deleting, and the App Privacy label had to move off "Data
Not Collected". Both shipped in the same release as the binary, because a
policy that is true a week later was false when the build went out.

## What I learned

That `getProducts` and `getOfferings` disagree is not a footnote — it is the
sharpest diagnostic in the RevenueCat SDK. One asks the store, the other asks
your dashboard, and the gap between them tells you exactly which side is
broken. I would put a `getProducts` fallback behind the offering in any app
where an empty tip list is indistinguishable, on screen, from a dead network.

Also: a store rejection is usually a configuration story, not a code story, and
the fastest path through one is an experiment that can only have two answers.

## What's next

Android, once the Play closed-testing clock has run. An auto-renewing
subscription is the recorded alternative if there is ever something worth
gating — the gateway was shaped so one can be added without reshaping it, and
the tips stay either way.

## A note for judges

The rules ask for a free trial or a promo code so judges can unlock the in-app
purchase and test the premium features. VitoMy has none: the whole app is free,
and the three tips unlock nothing by design, so there is nothing to gate and
nothing to hand you a code for. Install it and every feature is already open.
The purchase to test is the tip itself, under Settings → Support the developer.
