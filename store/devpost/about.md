## Inspiration

Half of what people take runs on a cycle: eight weeks on, four weeks off, or a
course that ends on a date. Every tracker I tried treats a supplement as a
checkbox that repeats forever, so the cycle lives in your head and the breaks
get missed. That is a calendar problem, not a list problem.

VitoMy answers one question: what do I take today, and when does this one stop?

## What it does

You add what you take, set the schedule once, and the app keeps the calendar.

Today lists the doses due with the time beside each one. Tap a row to mark it
taken. An unmarked dose is described neutrally, never as a failure.

Cycles draws every schedule as a bar across the months with the breaks hatched,
so overlaps and gaps are visible instead of inferred. Year is the same
information at twelve-month range.

Reminders are local notifications that never name a supplement, in the title or
the body, because a lock screen is public.

Everything stays on the device. No account, no server, no analytics. The app
ships in seven languages, Arabic included, with real right-to-left layout and a
gantt painter mirrored by hand.

## How I built it

One Flutter codebase. Riverpod for state with hand-written providers, Drift over
SQLite for storage, UUID keys and soft deletes on every row so a sync backend can
arrive later without touching a screen. Screens depend on repository interfaces;
Drift is one implementation, wired in a single file. That rule is what made
RevenueCat cheap to add.

RevenueCat powers three consumable tips that unlock nothing, and each part of
that was decided rather than defaulted:

- A tip is consumable, so it repeats, and Apple permits developer tips under
  guideline 3.1.1. Consumables are not restorable, which removes the Restore
  control and the anonymous-reinstall problem with it.
- No entitlement. Attaching a consumable to one makes RevenueCat report it
  unlocked forever after a single purchase.
- No Paywalls SDK, because Paywalls do not support consumables. The tip screen
  is built from the app's own design tokens like every other screen.
- `purchases_flutter` is importable from exactly one file, behind a
  `PurchaseGateway` interface. Tests keep it there, and assert the purchase
  layer cannot reach the database, the domain, or either supplement stream.
  That is what lets the privacy policy say the stack never leaves the device
  and mean it.

1167 tests run on every commit, plus 48 more before a release: a vocabulary
sweep across all seven languages, and every main screen at text scales 1.0, 1.6
and 2.0.

## Challenges I ran into

Apple rejected the build under guideline 2.1(b): the in-app purchases were not
available at review time. Everything in App Store Connect was correct, so the
obvious readings were all wrong.

The app reads `offerings.current`, and a missing offering returns an empty list
that the screen renders as "unavailable", which looks exactly like a network
failure. So I wrote a throwaway diagnostic that asked the same question twice on
a real device: `getOfferings()`, which goes through the dashboard, and
`getProducts(ids)`, which bypasses it and asks StoreKit.

`getProducts` returned all three with real prices. `getOfferings` threw
CONFIGURATION_ERROR: no App Store products registered for your offerings. The
products had never been attached to the offering. One dashboard fix, no code
change, verified on the device before resubmitting.

A quieter one: the platform-config test asserted the app declares no INTERNET
permission, and it kept passing after RevenueCat landed, because
`purchases-android` declares INTERNET in its own library manifest and it merges
in at build time while the test reads the source manifests. That assertion now
claims only what it can see, and the real guarantee moved to a test that names
the one network-capable dependency.

## What I learned

`getProducts` and `getOfferings` disagreeing is the sharpest diagnostic in the
SDK. One asks the store, the other asks your dashboard, and the gap between them
says which side is broken.

## What's next

Android, once the Play closed-testing clock has run. A subscription if there is
ever something worth charging for; the gateway was shaped so one can be added
without reshaping it.

## A note for judges

The rules ask for a free trial or a promo code so judges can unlock the in-app
purchase and test the premium features. VitoMy has neither. The whole app is
free and the three tips unlock nothing, so there is nothing to gate and no code
to hand you. The purchase to test is the tip itself, under Settings > Support
the developer.
