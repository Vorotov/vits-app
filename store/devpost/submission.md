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
