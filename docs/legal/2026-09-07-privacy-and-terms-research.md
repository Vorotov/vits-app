# Privacy Policy and Terms of Use: research for the supplement app

Date: 2026-09-07. Sources read in full: Scallergy privacy policy (2026-08-28),
Pawmi privacy policy (2026-06-09) and terms (2026-06-10), BetterMe privacy
policy (2026-09-02) and terms with two annexes (2026-06-27). This document
collects what is worth taking from them, what to refuse, and what our own
app makes true or false, so the two documents can be drafted next.

Nothing here is legal advice. It is a clause bank plus the reasoning behind
each pick.

## 1. The brief

- The app plans and tracks supplement, vitamin and similar intake. It is a
  well-being product. The documents must contain no health vocabulary at all:
  no "health", "healthcare", "medical", "doctor", "physician", "diagnose",
  "treat", "condition", "disease", "symptom". The ARB gate in
  `test/l10n/planner_copy_safety_test.dart` and the release sweep in
  `test_release/copy_safety_all_locales_test.dart` already enforce a related
  rule for app copy; the legal documents need the same discipline but live
  outside the ARB files, so nothing automated covers them yet (see §8).
- Third-party services are coming: Google and Apple platform services,
  analytics, crash reporting. The documents should have a place for them.
- Subscription: none today. Decision pending (see §9).
- No app name, no contact email, no legal entity. Placeholders throughout:
  `[APP_NAME]`, `[CONTACT_EMAIL]`, `[WEBSITE_URL]`. The operator wording
  follows Pawmi, which was written for the same situation.

## 2. What the app actually does today

The documents must describe this build, not an imagined one. Verified in the
repo on 2026-09-07:

| Fact | Where it is asserted |
|---|---|
| No account, no sign-in, no server. Everything the user enters stays in an SQLite file on the device. | `lib/core/db/database.dart`, `drift_flutter` opens the DB in the app-documents directory |
| No network access. The release Android manifest declares no INTERNET permission; only `RECEIVE_BOOT_COMPLETED`. | `android/app/src/main/AndroidManifest.xml`, pinned by `test/platform_config_test.dart` |
| No analytics SDK, no crash reporter, no advertising SDK, no tracking identifier read. | `pubspec.yaml` dependencies: drift, riverpod, shared_preferences, flutter_local_notifications, timezone, flutter_timezone, path_provider, uuid, intl |
| Reminders are local notifications scheduled on the device. They never contain the name of what the user takes. | `test/notifications/notification_privacy_test.dart` |
| Notification permission is asked from exactly one place in the app. No tracking (ATT) prompt exists. | `lib/features/` gate in the notification tests |
| The app's data is included in the OS backup (iCloud / Google backup) because no manifest variant opts out. | `test/platform_config_test.dart` asserts no opt-out |
| Two small preferences are stored outside the database: the language override and the onboarding / hint flags. | `lib/core/l10n/locale_controller.dart`, `lib/features/onboarding/` |
| No data export feature. No in-app "delete everything" button; uninstalling the app deletes its data. | absence, checked by grep |
| Sync-ready schema (UUIDs, timestamps, soft deletes) exists but no sync ships. | `lib/core/db/database.dart` header |

Two consequences that shape the whole privacy policy:

1. Until an analytics SDK ships, we receive nothing. Under GDPR we are not a
   controller of data we never obtain. Pawmi's and BetterMe's "we act as the
   data controller" sentence would be false for this build. The honest v1
   privacy policy is mostly a statement of what stays on the phone.
2. Both stores require a hosted privacy policy URL regardless
   (App Store Connect and Google Play Console both refuse a listing without
   one), so a `[WEBSITE_URL]/privacy` page is needed even though the app
   itself never fetches it. Apple's privacy "nutrition label" can honestly be
   "Data Not Collected" for this build, and Google Play's Data safety form
   can say no data is collected or shared. Both labels flip the day
   analytics ships, so the policy and the labels must change in the same
   release.

Even with zero SDKs, two things are true and worth saying:

- Apple and Google collect crash and usage statistics from the OS if the user
  opted in on the device, and may show us aggregates in App Store Connect and
  Play Console. That happens under Apple's and Google's terms, not ours.
- The device backup contains our data under Apple's / Google's terms.

## 3. Source by source

### 3.1 Scallergy privacy policy

The best model for tone. Nine short sections, plain sentences, and a summary
in the second paragraph: "we collect only what the app needs to work, we
never sell data, and you can delete everything at any time."

Take:

- The opening "short version" paragraph.
- Section titles as plain questions and statements: "What we collect", "Where
  it lives", "What we don't do", "Deleting your data", "Children", "Changes &
  contact".
- Naming each vendor with its hosting country in one line
  ("PostHog (hosted in the United States)", "Supabase (hosted in the United
  States)"). When analytics ships, copy this exactness: name the vendor, the
  region, and the list of events.
- The event-level analytics disclosure: "app opens, scan outcomes ..., your
  device model and operating-system version, and — on Android, on first
  launch — which link the install came from (Google Play install referrer).
  Events are tied to a random account identifier, never to your name or
  email". For us: "tied to a random installation identifier" since there is
  no account.
- The Meta SDK paragraph is a template for any attribution SDK: what it
  receives (advertising identifier, install, app open), whose policy governs
  it, and how to turn it off on each OS ("on Android ... Privacy → Ads; on
  iOS, app tracking is off unless you allow it, and can be managed in
  Settings → Privacy & Security → Tracking").
- "What we don't do": "No ads. No selling or renting data. No data brokers."
- The children line: "not directed at children under 13 and we do not
  knowingly collect their data."

Refuse:

- "This is health-related information" (allergen lists). Scallergy admits
  its core data is health data. We must not describe what the user takes
  that way, and our intake log is not a scan of someone's allergens.
- The closing "Scallergy is an assistive tool, not medical advice ... always
  check the physical label." The idea (the app is a tool, the label is the
  authority) is right; the words are not. See §6 for the rewrite.

### 3.2 Pawmi privacy policy

The closest structural match: an independent team, GDPR + UK GDPR + US state
laws named explicitly, a legal-basis list instead of BetterMe's table, and a
retention list with real numbers.

Take:

- The operator definition: "developed and operated by an independent remote
  team of individuals working from different countries (the 'Pawmi team',
  'we', 'us')". For a solo developer: "developed and operated by an
  independent developer ('we', 'us')". Decide which (§9).
- The scope list (App, Website, support channels = "the Services").
- "Scope and legal framework": GDPR / UK GDPR; "US state consumer-privacy
  laws where applicable (for example, California's CCPA/CPRA, and comparable
  laws in other states)"; "Other local privacy laws that apply where our
  users are located."
- The three-way split of data: "Information you provide", "Information we
  collect automatically", "Information from third parties". For this build
  the first bucket stays on the device, the second is empty until analytics,
  the third is "App stores: aggregated crash and usage statistics if you
  opted in on your device".
- Legal bases phrased per purpose: contract ("To provide and operate"),
  legitimate interests ("To improve the App and keep it secure ... Monitor
  performance and crashes; analyse how features are used to decide what to
  build next"), consent ("non-essential analytics in regions that require
  consent", "Any processing that qualifies as 'tracking' under Apple's App
  Tracking Transparency"), legal obligation.
- "You can withdraw consent at any time in your device settings or inside
  the App (where available). This does not affect processing already
  carried out."
- Retention with numbers: "Analytics and logs – usually up to 3 months, in
  aggregated form where possible." "Security and administrative audit logs –
  up to 12 months." Adopt the shape, set our own numbers when the vendor is
  chosen.
- "Your rights" split into EU/EEA + UK, California and other US states,
  Other regions. The US paragraph "We do not sell your personal information
  for money. To the extent our use of advertising identifiers ... is
  considered a 'sale', 'sharing', or 'targeted advertising' under your
  state's law, you can opt out through ..." is ready for the day an
  attribution SDK ships; until then, the plain "We do not sell or share
  personal information" is enough.
- "Mobile permissions" as its own section: for us, one permission,
  notifications, "to send reminders at the times you set. You can enable or
  disable it at any time in your device settings."
- Children: "not intended for children under 16 in the EU/EEA or UK, or
  under 13 in other regions". Decide 16/13 vs 18 (§9).
- "Third-party links and services ... are governed by their own privacy
  policies, not this one".
- "Changes to this Policy": update the date; in-app notice; website notice;
  "If required by law, we will ask for your consent to significant
  changes."
- "Security": HTTPS/TLS, access controls, "No system can be 100% secure".
  For a local-only app, the security paragraph becomes: data sits in the
  app's private storage, protected by the OS (device passcode, app sandbox,
  encrypted backups where the OS provides them).

Refuse:

- Every "health" (pet health records, health attributes). Pawmi is about
  dogs and can say it; we cannot.
- "Automated processing and personalisation" and the "AI features" section.
  We have deterministic cycle math, no profiling. Do not import profiling
  language that then needs a GDPR Article 22 disclaimer.
- Location, motion, camera, photos, social feed, family roles, Strava,
  AdMob. None applies.

### 3.3 Pawmi terms of service

A complete, readable consumer ToS at 27 sections. The parts that carry over
are the skeleton and the app-store clause.

Take, close to verbatim:

- §1 acceptance: "By downloading, accessing, creating an account, or
  otherwise using any part of the Services, you agree to be bound by these
  Terms. If you do not agree, you must not use the Services." Drop "creating
  an account".
- §1 incorporation: "Our Privacy Policy ... forms part of these Terms and is
  incorporated by reference."
- §2 eligibility: "you have the legal capacity to accept these Terms" and
  "If you let a child or any other person use [the app] through your device
  ..., you are responsible for their use".
- §4 acceptable use, the generic list: violate law; interfere with, disrupt
  or overload; "reverse engineer, decompile or attempt to extract the source
  code of the App, except where such restriction is prohibited by law"; "use
  [the app] to develop or train a competing product or service, or to scrape
  or harvest data".
- §10 permissions: "You can manage these permissions in your device
  settings. Some features ... may not work ... without the relevant
  permission."
- §11 subscriptions, if and when: "Purchases and recurring subscriptions are
  made through the Apple App Store or Google Play ... All billing, payment
  processing, refunds and trials are handled by the relevant app store under
  its own terms. We do not store your full payment-card details."
  "Subscriptions renew automatically at the end of each billing period unless
  you cancel at least 24 hours before renewal in your app-store account
  settings." "Where you are entitled to a statutory cancellation or
  withdrawal right (for example, the EU 14-day right of withdrawal for
  digital purchases), that right and any waiver of it are handled in
  accordance with applicable law and the relevant app store's policies."
- §14 intellectual property and the licence grant: "a limited, personal,
  non-exclusive, non-transferable, revocable licence to install and use the
  App on devices you own or control ... solely for your personal,
  non-commercial use."
- §15 third-party services list, trimmed to Google and Apple (distribution,
  push delivery), crash-reporting and analytics providers.
- §16 Apple App Store and Google Play additional terms. Apple requires this
  content for any app distributed through the App Store (the "Licensed
  Application End User License Agreement" minimums): the terms are between
  the user and us, not Apple; Apple has no maintenance or support
  obligation; warranty and product-liability claims are ours; the export
  compliance representation ("not located in a country subject to a relevant
  embargo"); "Apple and its subsidiaries are third-party beneficiaries of
  these Terms and may enforce them against you". Keep the whole section.
- §18 data rights and deletion, adjusted: no account, so "You can stop using
  [the app] at any time; deleting the App from your device deletes the data
  it stores there."
- §19 modifications: "Your continued use of the Services after the updated
  Terms take effect constitutes acceptance."
- §20 term and termination, including the survival list.
- §21 disclaimers: "provided 'as is' and 'as available', without warranties
  of any kind ... We do not warrant that the Services will be error-free,
  secure, uninterrupted or always available; that any data ... will be
  accurate, complete or up to date".
- §22 limitation of liability, both paragraphs, including the carve-out
  "Nothing in these Terms excludes or limits any liability that cannot be
  excluded or limited under applicable law (for example, liability for death
  or personal injury caused by negligence, or for fraud), and nothing limits
  the mandatory statutory rights of consumers."
- §23 indemnity.
- §24 "Informal resolution first. Before bringing any formal claim, please
  contact us ... Most concerns can be settled this way."
- §25, the no-entity clause, our exact situation: "[The app] is currently
  developed and operated by a distributed team of individual creators and is
  not yet incorporated as a separate legal entity. If our structure changes –
  for example, if we form a company or transfer the Services to another owner
  – these Terms may be assigned to the new entity. We will notify you where
  required and, where required, give you the option to stop using the
  Services." Plus the assignment sentence.
- §26 miscellaneous: entire agreement, severability, no waiver, force
  majeure, notices.

Refuse or fix:

- §24 is incomplete in the published Pawmi text: "Governing law and dispute
  resolution" contains only the informal-resolution paragraph and never
  names a governing law or a forum. Do not copy that gap. Pick a law (§9).
- §8 "Health, safety and responsibility for pets" and §9 "AI and automated
  features": the structure ("a tool for tracking and planning", "estimates
  ... for information only", "you remain responsible for exercising your
  own judgement") is right; the vocabulary ("veterinary, medical,
  behavioural", "health conditions") is not.
- §5 to §7 (social, family, walkers), §12 to §13 (referrals, ads): no
  counterpart.
- "Applies to the Pawmi App version 2.10.0 and later": useful only when a
  breaking change to the terms lands. Skip for v1.

### 3.4 BetterMe privacy policy

Written for a company with a store, coaches, wearables and a dozen ad
networks. Most of it is irrelevant, but four pieces are the most complete
examples available of things we will need.

Take:

- The English-prevails clause (both documents): "Any translation from the
  English version is provided for your convenience and transparency purposes
  only. In the event of any difference in meaning or interpretation between
  the English language version ... and any translation, the English language
  version will prevail." We ship seven UI languages; the legal texts should
  ship in English with this line, and only be translated when a translation
  can be maintained.
- Vendor paragraphs as a template, one per vendor, with the vendor's own
  policy linked. The most reusable ones for a Flutter app:
  Crashlytics ("To monitor infrastructure and the App's performance, we use
  Crashlytics, which is a monitoring service provided by Google"), Firebase
  Performance Monitoring, Sentry ("automatically captures all unhandled
  exceptions and relevant diagnostic data such as device information, app
  version"), Amplitude ("collects various technical information, in
  particular, time zone, type of device ... helps us to decide what features
  we should focus on"), AppsFlyer (attribution: "how users find us"),
  Firebase Remote Config ("A/B testing and configuration service ... allows
  us to show different onboarding screens to different users"), APNs and
  Firebase Cloud Messaging (only if remote push ever ships; local
  notifications need neither).
- The purpose table columns: purpose, description with an example, data
  categories, lawful basis. Pawmi's list form is easier to read; BetterMe's
  example column ("if we discover that users more often engage in workouts
  designated for legs, we may develop ...") is the useful idea. Give each
  purpose one concrete example from our app: "if most users add a
  supplement from the catalog rather than by typing, we invest in the
  catalog."
- The CCPA section: the named-states list (California, Colorado,
  Connecticut, Delaware, Indiana, Iowa, Kentucky, Maryland, Minnesota,
  Montana, Nebraska, New Hampshire, New Jersey, Oregon, Rhode Island,
  Tennessee, Texas, Utah, Virginia), the "Your Privacy Choices" link
  convention, the opt-out preference signal sentence ("We will also strive
  to recognize and process your opt-out preference signal"), the appeal
  process ("if your privacy request is denied, you have the right to appeal
  ... clearly indicating 'USA PRIVACY APPEAL REQUEST'"), the "Shine the
  Light" paragraph, verification ("confirming that the request comes from
  the email associated with your account"; for us: "the email you write
  from") and the authorized-agent paragraph. All of this only matters once
  we hold personal data; keep it in the bank.
- Device-level ad opt-out instructions for iOS and Android, and the NAI /
  DAA opt-out links. Only if an attribution or ads SDK ships.
- Data portability: "The data will be made available to you in the .json
  file or another file format." A concrete promise we could keep with an
  export feature.
- "By continuing to access or use the Service after those changes become
  effective, you agree to be bound by the revised Privacy Policy."

Refuse:

- Everything about "Special wellness data", Apple Health / Health Connect,
  cycle tracking, diabetes meal plans, heart rate, BMI. We will never read
  or write Apple Health or Health Connect; say so in one sentence (§6),
  because it is the single most common question about an intake tracker.
- The 18+ "you promise us" paragraph phrased as a promise is fine; the
  requirement to "cancel any subscriptions ... and delete the App" if you
  disagree is heavy for us.
- Meta Custom Audience, Snapchat, Pinterest, X, Quora, TikTok CAPI,
  eSputnik, Zoom, Calendly, Intercom, Stream Chat, Zendesk, ZeroBounce,
  Shopify. None.
- "our fitness and wellness services", "healthier lifestyle" in the
  legitimate-interest explanations. "Well-being" is allowed by the brief;
  "healthier" is not.

### 3.5 BetterMe terms and annexes

A 19-section ToS with mandatory arbitration, plus a terms of sale and a
dietary-supplements terms of sale for their US store.

Take:

- The auto-renewal notice at the very top, if a subscription ships: "To
  avoid being charged, you must affirmatively cancel your subscription
  before the end of the trial or then-current subscription period ... If you
  purchased your subscription through an app store ..., you must cancel at
  least 24 hours before the end". And "Deleting the app does not cancel your
  subscriptions and trials." Both Apple and Google expect the second
  sentence somewhere.
- Notice periods for term changes: "no less than 14 days from the date of
  notification unless applicable laws mandate a longer notice period, in
  which case the notice period will be no less than 30 days." Concrete and
  defensible.
- §7.4 auto-renew: "The renewal rate will be no more than the rate for the
  immediately prior subscription period, excluding any promotional
  (introductory) and discount pricing, unless we notify you of a rate change
  prior to your auto-renewal."
- §7.9 / 7.13: "Subscriptions purchased via an App Store are subject to such
  App Store's refund policies. This means we cannot grant refunds. You will
  have to contact App Store support."
- §7.12 the EU/UK/Swiss 14-day withdrawal paragraph and the model withdrawal
  form. Only needed if we ever sell outside the app stores (a web checkout).
  Through the stores, Pawmi's one-sentence version is enough.
- §4.7 "You are solely responsible for obtaining the equipment and
  telecommunication services necessary to access the Service".
- §4.10 "The Company has no obligation to provide you with customer support
  of any kind. However, the Company may provide you with customer support
  from time to time".
- §12.4 the prohibited-conduct list is longer than Pawmi's; the extra items
  worth keeping: "make the Service available over a network ... permitting
  access or use by multiple devices or users at the same time", "upload or
  distribute ... files that contain viruses", "use any automated system,
  including ... scraper".
- §13.5 the EEA/UK/Swiss digital-content conformity paragraph (the user
  must install updates we supply; the right to have a defect corrected).
  This is the EU Digital Content Directive language and applies to any app
  sold or offered to EU consumers, paid or with data as consideration.
- §14.2 liability cap: "limited to the amounts you have paid to the Company
  for access to and use of the Service." For a free app that is zero; say so
  or use a fixed nominal sum.
- §14.6 Australia and §17.5 Quebec consumer carve-outs: keep as one generic
  sentence ("Some jurisdictions do not allow ... so the above may not apply
  to you") unless we actively market there.
- §18.5 electronic communications and the "by clicking 'I AGREE' you are
  submitting a legally binding electronic signature" sentence.

Refuse:

- The whole §8 arbitration agreement (LCIA / JAMS, batch arbitration, class
  waiver, 30-day opt-out). It exists to protect a company with US revenue at
  scale, it costs money to invoke, and it is unenforceable against EU
  consumers anyway. Pawmi's "informal resolution first" plus a governing law
  is the right size.
- §2 "Important disclaimers": every paragraph is HEALTHCARE SERVICES,
  PHYSICIAN, MEDICAL ADVICE, INJURY OR DEATH in capitals. This is the
  opposite of the brief. See §6.
- §9 the perpetual, revenue-deriving user-content licence. We have no user
  content that leaves the device. If sync ever ships, Pawmi's narrower
  "only as reasonably necessary to operate ... the Services" licence is the
  one to use.
- Annex A (physical goods) and Annex B (dietary supplements sold by them):
  we sell nothing. Annex B's "have not been evaluated by the United States
  Food and Drug Administration. The Products are not intended to diagnose,
  treat, cure or prevent disease" is the FDA/DSHEA disclaimer that sellers
  of supplements must print; a tracker that sells nothing has no reason to
  carry it, and it is health vocabulary.
- §14.3 the California Civil Code §1542 waiver. Belongs with the release
  language we are not using.

## 4. Structure for our two documents

### 4.1 Privacy policy (target: Scallergy length, Pawmi coverage)

1. Who we are and what this covers. Operator wording from Pawmi §1 /
   ToS §25. "[APP_NAME] is a planner and tracker for the supplements and
   vitamins you choose to take." Scope: the app, `[WEBSITE_URL]`, support
   email.
2. The short version (Scallergy). Draft: "Everything you enter stays on your
   device. We do not have an account system, a server, or access to your
   data. The app does not use the internet. Reminders never name what you
   take. Delete the app and its data is gone."
3. What stays on your device. Supplements and their doses, schedules and
   cycles, the intake log, the language choice, the onboarding flags. Where:
   the app's private storage, in an SQLite database. Included in the device
   backup under Apple's / Google's terms.
4. What we receive. Today: nothing from the app. Aggregated crash and usage
   statistics from Apple and Google if the user opted in on the device.
   Support email content if the user writes to us. (Slot for analytics and
   crash reporting: vendor, region, event list, identifier type, retention,
   opt-out; write it in "may" form only if the user decides so in §9.)
5. Legal bases (Pawmi list form), written for the day we hold anything.
6. Sharing. "We do not sell, rent or share personal data. No advertising
   SDK. No data brokers." Legal requests. Corporate transaction clause
   (Pawmi "Corporate transactions").
7. International transfers. Only relevant once a vendor exists; one
   sentence with SCCs / adequacy (Pawmi).
8. Retention. Local data: until the user deletes it or the app. Support
   email: as long as needed to resolve it. Analytics slot.
9. Your rights, by region (Pawmi shape, BetterMe US list). For local-only
   data: the user holds it, so access / correction / deletion happen in the
   app or by deleting it; we cannot act on data we never received.
10. Permissions: notifications only.
11. Children: age per §9.
12. Third-party links and services.
13. Security: OS sandbox, device passcode, encrypted backups where the OS
    provides them; "No system can be 100% secure".
14. Changes.
15. Contact: `[CONTACT_EMAIL]`.
16. English prevails (BetterMe).

### 4.2 Terms of use (target: Pawmi trimmed, ~18 sections)

1. Introduction and acceptance. 2. Eligibility. 3. What the app is and is
not (the §6 paragraph). 4. Acceptable use. 5. Permissions. 6. Intellectual
property and licence. 7. Third-party services. 8. Apple App Store and Google
Play additional terms (whole Pawmi §16). 9. Privacy. 10. Your data and
deletion. 11. Modifications to the app and to the terms (BetterMe 14/30-day
notice). 12. Term and termination. 13. Disclaimers. 14. Limitation of
liability. 15. Indemnity. 16. Governing law and dispute resolution (informal
first + a named law). 17. Changes in team structure and assignment (Pawmi
§25). 18. Miscellaneous. 19. Contact. Subscription section inserted between
7 and 8 only if §9 says so.

## 5. Placeholders and the no-entity stance

| Placeholder | Where | Pawmi precedent |
|---|---|---|
| `[APP_NAME]` | every "the App" definition, IP section, store clause | "Pawmi" |
| `[OPERATOR]` | "developed and operated by ..." | "an independent remote team of individuals working from different countries (the 'Pawmi team', 'we', 'us')" |
| `[CONTACT_EMAIL]` | contact, rights requests, notices, informal resolution | one address for everything; BetterMe splits support / legal / privacy, unnecessary at our size |
| `[WEBSITE_URL]` | scope, notices, English-prevails link | pawmi.app |
| `[GOVERNING_LAW]` | ToS governing law | absent in Pawmi (a gap), England and Wales in BetterMe |
| `[MIN_AGE]` | eligibility, children | 16 EU/UK, 13 elsewhere (Pawmi); 18 (BetterMe) |
| `[LAST_UPDATED]` | both headers | date |

The no-entity clause (Pawmi ToS §25) does the legal work: it names the
operator as an unincorporated team, promises assignment to a future entity,
and promises notice. It should appear in the ToS and be echoed in the
privacy policy's "who we are" paragraph. The one thing it cannot do is name
a data controller's address, which GDPR Article 13 asks for. Pawmi answers
with an email only. Follow that, and add a postal address when an entity
exists.

## 6. The health-vocabulary problem, solved sentence by sentence

Every source states "not medical advice" in medical words. The brief bans
those words. The following says the same thing without them. Each line is a
candidate; the third one is the point where liability protection and the
vocabulary rule pull against each other, and it needs the user's decision.

Candidate "what the app is and is not" section for the ToS (and a shorter
echo in the privacy policy):

> [APP_NAME] is a planning and tracking tool. It records what you decide to
> take, when you decide to take it, and whether you marked it as taken.
>
> The app does not give advice of any kind. It does not suggest what to
> take, how much, how often, or whether to take anything at all. The
> catalog exists to save typing; a name appearing in it is not a
> recommendation. Schedules, cycles and the calendar are computed from the
> entries you make and are only as accurate as those entries.
>
> Decisions about what you take are yours. Read the label and the
> information that comes with any product, and talk to a qualified
> professional when you are unsure.
>
> The app never reads or writes Apple Health or Health Connect, and
> reminders never include the name of what you take.

Notes on each choice:

- "planning and tracking tool" mirrors Pawmi §8 ("a tool for tracking and
  planning walks") and Scallergy ("an assistive tool").
- "does not give advice of any kind" replaces "not medical advice". It is
  broader, which is better: it also covers nutrition, fitness and legal
  advice without naming them.
- "a qualified professional" is the only remaining pointer to outside
  expertise. It avoids doctor / physician / pharmacist. Decide whether to
  keep it (§9 Q4). Dropping it makes the app the only voice in the text,
  which reads as more confident and less protective.
- The Apple Health / Health Connect sentence uses two product names that
  contain the word "Health". They are proper nouns for the things we do not
  touch. The alternative, "the operating system's activity and wellness data
  stores", is vaguer and still needs a reader to guess. Recommend keeping
  the product names. If the release copy sweep is ever extended to these
  documents (§8), allowlist these two names.
- Words to search for and remove before publishing, in every draft:
  health, healthy, healthier, healthcare, medical, medicine, medication,
  doctor, physician, pharmacist, pharmaceutical, clinical, diagnose,
  treat, cure, prevent, disease, illness, condition, symptom, dose limit,
  overdose, interaction, safe, safety, risk to you, injury. Also the ARB
  list in `limitVocabulary` (limit, exceed, threshold, maximum, too many)
  and `forbiddenVocabulary` (overdose, fat-soluble, medical standard).
  Note that "risk" survives in the liability sections in its legal sense
  ("at your own risk", "risk of loss"); that is different from a claim
  about a risk to the reader's body, and the sweep should tell them apart.

What the sources say and what to write instead:

| Source line | Rewrite |
|---|---|
| "Pawmi ... does not provide veterinary, medical, behavioural or safety advice." | "[APP_NAME] does not give advice of any kind." |
| "Always consult a qualified veterinarian about your pet's health" | "talk to a qualified professional when you are unsure" (or drop) |
| BetterMe 2.1.3 "CONSULT WITH YOUR PHYSICIAN ... TO DETERMINE WHETHER THE SERVICE WOULD BE SAFE" | nothing; the app does not act on the body, only on a calendar |
| BetterMe 2.2.1 "READ ALL INFORMATION PROVIDED BY THE MANUFACTURERS ... ON THE ACTUAL PRODUCT PACKAGING AND LABELS" | "Read the label and the information that comes with any product." |
| Scallergy "Product data may be incomplete — always check the physical label." | "The catalog exists to save typing; a name appearing in it is not a recommendation." |
| Annex B "not intended to diagnose, treat, cure or prevent disease" | omit; we sell nothing, and the FDA wording is for sellers |
| Pawmi "Routes, distances ... are approximations only" | "Schedules, cycles and the calendar are computed from the entries you make and are only as accurate as those entries." |

## 7. Ready-to-use clause bank, by section

Verbatim or near-verbatim text from the sources, chosen for our two
documents. Source in brackets. Replace product names with `[APP_NAME]`.

Acceptance
: "By downloading, accessing, or otherwise using any part of the Services,
  you agree to be bound by these Terms. If you do not agree, you must not
  use the Services." [Pawmi ToS §1, "creating an account" removed]
: "Our Privacy Policy ... forms part of these Terms and is incorporated by
  reference." [Pawmi ToS §1]
: "You further acknowledge and agree that by clicking on a button labeled
  'CONTINUE', 'I AGREE' or similar ... you are submitting a legally binding
  electronic signature" [BetterMe ToS §18.5, trimmed]

Eligibility
: "you have the legal capacity to accept these Terms" [Pawmi ToS §2]
: "If you let a child or any other person use [APP_NAME] through your
  device, you are responsible for their use and for ensuring they meet these
  eligibility requirements." [Pawmi ToS §2, "or account" removed]

Acceptable use
: "use the Services in any way that violates applicable law or regulation";
  "interfere with, disrupt, overload, or attempt to gain unauthorised access
  to the Services"; "reverse engineer, decompile or attempt to extract the
  source code of the App, except where such restriction is prohibited by
  law"; "use [APP_NAME] to develop or train a competing product or service,
  or to scrape or harvest data from the Services" [Pawmi ToS §4]
: "make the Service available over a network or other environment permitting
  access or use by multiple devices or users at the same time" [BetterMe ToS
  §12.4]

Permissions
: "You can enable or disable these permissions at any time in your device
  settings. Some features may not work without them." [Pawmi PP,
  "Permissions"]

Licence and IP
: "All rights, title and interest in and to the Services (including
  software, designs, logos, the '[APP_NAME]' name and branding, text,
  graphics, interfaces and underlying technology) are owned by [OPERATOR] or
  our licensors." [Pawmi ToS §14]
: "we grant you a limited, personal, non-exclusive, non-transferable,
  revocable licence to install and use the App on devices you own or
  control ... solely for your personal, non-commercial use." [Pawmi ToS §14]
: "You may not copy, modify, distribute, sell, lease, or create derivative
  works based on the Services or any part of them, and you may not remove or
  alter any proprietary notices. All third-party trademarks shown in the
  Services are the property of their respective owners." [Pawmi ToS §14]

Third-party services
: "Your use of connected third-party services may be governed by those
  services' own terms and privacy policies ... We do not control and are not
  responsible for third-party services. Our Privacy Policy describes the
  data involved." [Pawmi ToS §15]

App stores
: the whole of Pawmi ToS §16, six bullets, unchanged.

Subscriptions (dormant, see §9)
: Pawmi ToS §11 bullets 2 to 5; BetterMe top notice "Deleting the app does
  not cancel your subscriptions and trials"; BetterMe §7.9 "Subscriptions
  purchased via an App Store are subject to such App Store's refund
  policies. This means we cannot grant refunds."

Modifications
: "We may modify, update, suspend or discontinue any part of the Services,
  and we may update these Terms. When we make material changes to these
  Terms, we will update the 'Last updated' date and, where appropriate, show
  an in-app notice ... Your continued use of the Services after the updated
  Terms take effect constitutes acceptance. If you do not agree, you must
  stop using the Services and may delete the App." [Pawmi ToS §19]
: "Such updates will be effective no less than 14 days from the date of
  notification unless applicable laws mandate a longer notice period, in
  which case the notice period will be no less than 30 days." [BetterMe ToS
  §1.7]

Termination
: "You may stop using [APP_NAME] at any time. We may suspend or terminate
  your access, with or without notice, if you materially or repeatedly
  breach these Terms, if we are required to do so by law or a competent
  authority, or if we decide to discontinue the Services." [Pawmi ToS §20]
: "Sections that by their nature should survive termination ... will
  survive." [Pawmi ToS §20]

Disclaimers
: "The Services are provided 'as is' and 'as available', without warranties
  of any kind, whether express or implied, including implied warranties of
  merchantability, fitness for a particular purpose, non-infringement,
  accuracy or reliability." [Pawmi ToS §21]
: "We do not warrant that the Services will be error-free, secure,
  uninterrupted or always available; that any data ... or any automated
  recommendation, goal, insight or route will be accurate, complete or up
  to date; or that the Services will meet your expectations." [Pawmi ToS
  §21; replace the list with "any schedule, cycle, calendar or reminder"]
: "You are solely responsible for obtaining the equipment and
  telecommunication services necessary to access the Service" [BetterMe ToS
  §4.7]
: "The Company has no obligation to provide you with customer support of
  any kind. However, the Company may provide you with customer support from
  time to time, at the Company's sole discretion." [BetterMe ToS §4.10]

Limitation of liability
: both paragraphs of Pawmi ToS §22 unchanged.
: "the aggregate liability ... is limited to the amounts you have paid ...
  for access to and use of the Service" [BetterMe ToS §14.2; add "or, if
  you have paid nothing, [a nominal sum]"]

Indemnity
: Pawmi ToS §23 unchanged.

Disputes
: "Informal resolution first. Before bringing any formal claim, please
  contact us at the address in Section [N] so we can try to resolve the
  issue. Most concerns can be settled this way." [Pawmi ToS §24]
: "Nothing in these Terms shall deprive you of the protection afforded to
  consumers by the mandatory rules of law of the country in which you live."
  [BetterMe ToS §17.4]

Team structure
: Pawmi ToS §25, both paragraphs, unchanged.

Miscellaneous
: Pawmi ToS §26, five bullets, unchanged.

Privacy: framework
: "We design [APP_NAME] to comply with: EU and UK data-protection law (GDPR
  / UK GDPR). US state consumer-privacy laws where applicable (for example,
  California's CCPA/CPRA, and comparable laws in other states). Other local
  privacy laws that apply where our users are located." [Pawmi PP]

Privacy: what we don't do
: "No ads. No selling or renting data. No data brokers." [Scallergy]
: "We do not sell your personal information for money." [Pawmi PP, US
  section]

Privacy: analytics (slot)
: "The app sends usage events to [VENDOR] (hosted in [REGION]) so we can
  understand what works and fix what doesn't: [event list], your device
  model and operating-system version ... Events are tied to a random
  [installation] identifier, never to your name or email ... We use this
  data only to improve the app; it is not shared or sold." [Scallergy]
: "Analytics and logs – usually up to [N] months, in aggregated form where
  possible." [Pawmi PP, retention]

Privacy: consent and withdrawal
: "You can withdraw consent at any time in your device settings or inside
  the App (where available). This does not affect processing already
  carried out." [Pawmi PP]

Privacy: sharing
: "Corporate transactions – in connection with a merger, acquisition,
  financing, or sale of all or part of our app or related assets. Where
  possible, we will notify you and ensure the recipient respects this
  Policy." [Pawmi PP]
: "Legal and law-enforcement requests – when required by law, court order or
  competent authority, or to protect our rights, users or others." [Pawmi
  PP]

Privacy: transfers
: "When we transfer personal data internationally, we use legal safeguards
  such as adequacy decisions or Standard Contractual Clauses." [Pawmi PP]

Privacy: rights
: the EU/EEA + UK bullet list (access, rectify, erase, restrict,
  portability, object, withdraw) and the California list (know, delete or
  correct, opt out of sale/sharing/targeted advertising, limit sensitive
  data) [Pawmi PP]; the appeal paragraph and the authorized-agent paragraph
  [BetterMe PP §4]; "you have the right to lodge a complaint with a
  competent data protection supervisory authority" [BetterMe PP §4].

Privacy: children
: "[APP_NAME] is not directed at children under [MIN_AGE] and we do not
  knowingly collect their data." [Scallergy]
: "If you are a parent or guardian and believe your child has provided us
  with personal data, please contact us" [Pawmi PP]

Privacy: security
: "No system can be 100% secure, but we work to minimise risks and follow
  industry best practices." [Pawmi PP]

Privacy: changes
: "When we make material changes, we will notify you by: updating the 'Last
  updated' date; showing an in-app notice ...; and/or posting a notice on
  our website. If required by law, we will ask for your consent to
  significant changes." [Pawmi PP]

Both documents
: the English-prevails clause [BetterMe, both documents].

## 8. Things the sources do not cover but our app needs

- A statement that the app has no internet access. None of the sources can
  say it; it is our strongest privacy claim and `test/platform_config_test.dart`
  keeps it true. Write it and keep the test.
- Reminders never name what you take. Enforced by
  `test/notifications/notification_privacy_test.dart`. Say it.
- Backup disclosure. The data rides in the OS backup. A user who assumes
  "on my device only" should know it also sits in their iCloud / Google
  backup, under Apple's / Google's terms.
- A vocabulary sweep over the legal texts. The ARB gates and the
  `test_release/` sweep cover app copy only. Once the documents exist in the
  repo (proposed: `docs/legal/privacy.md`, `docs/legal/terms.md`), a test
  in `test_release/` can glob them and apply the same stems plus the English
  list in §6, with an allowlist for the two product names and the legal
  sense of "risk". This is the same shape as `copy_safety_all_locales_test.dart`.
- In-app placement. Both stores need the URL in the listing. Inside the
  app, Settings should link to both documents. The app has no `url_launcher`
  and no INTERNET permission; opening an `https://` URL through the OS
  intent needs neither on Android, and nothing on iOS, but the package has
  to be added and `test/platform_config_test.dart` re-run to confirm the
  manifest stays bare.
- Store category. Apple's guideline 5.1.3 and Google Play's health-apps
  declaration attach extra obligations to apps in their health categories.
  Category choice (Lifestyle / Productivity vs Health & Fitness) should be
  made with these documents, not after. Verify the current Play policy text
  before choosing; it changed in 2024 and lists the app types it covers.

## 9. Open decisions

Decided 2026-09-07: (1) and (2) left out of the published text, to be added
in the release that ships the SDK or the paywall; (3) governing law omitted
for now, marked by an HTML comment in `terms.md`, to be added with the
entity; (4) kept as "ask someone qualified when you are unsure", with the
label and "any advice you have been given" carrying the deference; (5) 18
everywhere; (6) "an independent team"; (7) English only. The drafts are
`docs/legal/privacy.md` and `docs/legal/terms.md`; the gate is
`test_release/legal_copy_safety_test.dart`. The original questions follow
for the record.

1. Subscription section: leave it out entirely (the app has none), or
   include Pawmi §11 in "may offer" form now. Recommendation: leave it out.
   A subscription section in a free app invites store review questions and
   a paragraph about a thing that does not exist. Keep the text in this
   file's §7 bank and add it in the release that ships the paywall.
2. Analytics section: same choice. Recommendation: leave it out of the
   published policy and keep the slot drafted in the repo, because the App
   Store label and the Play Data safety form must match the binary, and a
   policy that says "we may send events to an analytics provider" while the
   label says "Data Not Collected" contradicts itself.
3. Governing law: Pawmi names none. Options: Ukraine (where the team is),
   England and Wales (BetterMe's choice, common for international consumer
   apps), or the user's country of residence for consumers plus a default
   for everyone else. Needs the user's call; it is the one blank a lawyer
   would notice first.
4. "talk to a qualified professional when you are unsure": keep or drop. It
   is the only pointer to outside expertise left after the vocabulary rule.
5. Minimum age: 16 EU/UK and 13 elsewhere (Pawmi), or 18 everywhere
   (BetterMe). Recommendation: 18, one number, no regional table, and it
   matches how supplements are sold.
6. Operator wording: "an independent developer" or "an independent team".
7. Whether to translate the two documents into the seven UI languages, or
   ship English only with the English-prevails clause. Recommendation:
   English only until a translation can be kept in step with each change.
