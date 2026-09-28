# Devpost submission — RevenueCat Shipaton 2026

Everything the form asks for, in the order it asks. `about.md` holds the long
write-up for the **About the project** field; paste it as Markdown.

## General info

**Project name**

```
VitoMy
```

**Elevator pitch** (200 max)

```
A supplement planner that keeps the calendar for you: set each schedule once, on and off weeks included, and see what to take today. No account, no server, everything stays on your device.
```
188 characters.

## About the project

`store/devpost/about.md`, pasted verbatim. Sections: Inspiration, What it does,
How I built it, Challenges I ran into, What I learned, What's next, and a note
for judges about the promo-code clause (there is nothing to unlock, so there is
no code to give).

## Built with

Tags, lowercase, comma-separated as Devpost wants them:

```
flutter, dart, riverpod, drift, sqlite, revenuecat, purchases-flutter, storekit,
swift, ios, xcode, app-store-connect, astro, caddy, cloudflare, python
```
16 of the 25 allowed.

## Project media

**Image gallery** — eleven images, in this order. Devpost's own checkboxes ask
for an unframed screenshot and a 1024x1024 icon, and the raw files are what
answer them honestly: the six composed cards carry the pitch, the five raw
captures carry no frame, no bezel and no mock-up of any kind.

| # | File | Shows |
|---|---|---|
| 1 | `store/devpost/gallery/01-stack.png` | My stack, composed 3:2 card (this is the thumbnail) |
| 2 | `store/devpost/gallery/02-today.png` | Today, marking a dose |
| 3 | `store/devpost/gallery/03-cycles.png` | The gantt, with a break hatched |
| 4 | `store/devpost/gallery/04-year.png` | The year grid |
| 5 | `store/devpost/gallery/05-schedule.png` | The cycle editor |
| 6 | `store/devpost/gallery/06-support.png` | The three tips |
| 7-11 | `store/screenshots/ios-6.9/0*.png` | The same five screens raw, 1320x2868, no device frame |

The icon goes up as its own image: `store/icon/3b/appstore-icon-1024.png`,
1024x1024, no alpha channel, uncropped.

## The checkbox block

| Question | Answer |
|---|---|
| 1024x1024 uncropped icon attached | Yes, the file above |
| Screenshot WITHOUT device frames attached | Yes, images 7-11 |
| First version released between 1 August and 30 September 2026 | Yes, 1.0 went live in September |
| Employee of RevenueCat or a Shipaton sponsor | No, leave unticked |
| What type of app | iOS (iPhone and/or iPad) only. Android is not published yet |

**Video demo link** — YouTube or Vimeo, required. Built from
`build/demo/demo.mp4`, 46 seconds, 1920x1080, silent; see
`tool/make_demo_video.sh`. Upload it unlisted and paste the URL.

The cut is title card, Stack, the cycle editor, the dose times that become
reminders, Today with a dose marked on camera, Cycles, Year, end card. The tip
screen is deliberately NOT in it: a simulator cannot reach the live App Store,
so filming it means filming a stub, and the offering is better shown by gallery
card `06-support.png` or by a clip taken on a real device.

## Try it out links

```
https://apps.apple.com/app/id6811004977
https://vitomy.app
```

## The one dependency the form cannot see

The rules require a working app, publicly available, whose purchase runs through
the RevenueCat SDK. Version 1.0 is public and has no purchase in it; the tips
ship in 1.1.0, which Apple rejected on 25 September under 2.1(b) and which has
to be resubmitted, approved AND released before the judges look. Automatic
release, not manual.

## The optional award fields

### RevenueCat Design Award

Judged on innovative ideas and aesthetics, separately from business viability.
This is the category the app was built for.

```
The Cycles view is the piece to judge. A supplement course is a bar with a hole
in it, and several at once is a small gantt: on weeks solid, breaks hatched,
overlaps readable at a glance. Nothing off the shelf draws that, so it is a
hand-written painter, and it mirrors itself under Arabic, hatch and all.

Everything else follows one rule. The whole app comes from a single mockup,
transcribed into one token file, and a test pins each token to the mockup line
it came from. Colour cannot drift screen by screen.

There is no elevation anywhere, in any state. Grouping is hairlines and space.

Three of the seven shipped languages have no upper and lower case, so no layout
leans on a small-caps label to carry meaning.

Every main screen is tested in all seven languages at text scales 1.0, 1.6 and
2.0, Arabic under real right-to-left.

Copy is design here too. A dose you did not mark is called "not marked", never
"skipped", because the app does not know what happened. No streaks, no red
days.
```

### RevenueCat Peace Prize

Judged on impact and feasibility. A long shot against projects aimed at bigger
problems, but the field costs nothing to fill.

```
A record of what you take cannot leak here, because it is never collected. No
account, no server, no analytics, and the only network call the app makes is
the one that offers a tip. Four tests enforce that, which makes the privacy
policy a description instead of a promise.

Phones get shared and lock screens are public, so a reminder gives the time and
the number of doses due, never the supplement.

Seven languages at launch: English, Arabic, Spanish, French, Hindi, Ukrainian,
Chinese, with real right-to-left layout for Arabic. Every screen also works at
200% text size.
```

### Influencer Award

One category only. The five are Productivity (Christopher Lawley), Nutrition &
Healthy Eating (Abbey's Kitchen), Yoga & Fitness (Simone Sharice), Career
Coaching (Leadership Heather) and Gaming (Mr Lewis Blogs Gaming).

Pick **Yoga & Fitness, Simone Sharice**, whose brief is a wellness app that
answers "what should I do today?" without information overload. The other four
are a snippets manager, a meal planner, a manager-training app and a gaming
backlog.

```
Simone's brief is "what should I do today?" without the overload. That is the
Today screen: the doses due now, the time beside each, one tap to mark one
done. Nothing else on the page.

The planning happens once, elsewhere. You set a schedule with its on weeks and
its break, and from then on the app answers the daily question for you,
including the weeks when the answer is "nothing, you are in a break".

It is not a coach. It makes no claim about your body and scores nothing. A dose
you did not mark is "not marked", never "skipped", and there are no streaks to
break, so opening it after a bad week costs nothing.
```
