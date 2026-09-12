# vitomy.app website, design spec

Date: 2026-09-11. Status: awaiting Dima's review.

## What this is

The public website for VitoMy at `https://vitomy.app`. It exists for three
reasons, in this order:

1. Apple's App Store Connect requires a Support URL and a Privacy Policy URL,
   both of which must be pages (a `mailto:` is rejected). Google Play requires
   a privacy policy link. These two fields are the last hard blocker before
   either store submission.
2. A landing page that shows what the app does, with real screenshots and the
   kind of motion Apple's product pages use, so that a visitor from a store
   listing or a link lands somewhere that reads as a finished product.
3. A place for the Terms of Use, once its one remaining placeholder is filled.

It is a subproject of the app repository, in `site/`, built with Astro to
static files and deployed by rsync to the server `bot` behind Caddy.

Interview answers this spec is built on (2026-09-11):

| Question | Answer |
|---|---|
| Languages | English only. Other languages are a later phase. |
| Store buttons before launch | Visible, non-interactive, labelled "Coming soon". One config flag turns them into live links. |
| Visual base | The app's own light palette, with an automatic dark theme. |
| DNS | Dima adds the records in Spaceship; this spec says which. |
| Stack | Astro, static build. |
| Landing sections | Today, Cycles, Year. Not a separate privacy section. |
| Terms placeholder | The build fails on a placeholder. Privacy and Support publish first; Terms publishes when `[NOMINAL_SUM]` is filled. |
| Analytics | None. Caddy access logs only. |

## Design read

Reading this as: a consumer app landing for people who take supplements on a
schedule and value privacy, with a calm, premium, Apple-adjacent language,
leaning toward Astro plus native CSS, one GSAP-pinned phone scene, in the
app's own palette and type.

Dials (`design-taste-frontend`): `DESIGN_VARIANCE 7`, `MOTION_INTENSITY 6`,
`VISUAL_DENSITY 3`. The "premium consumer" preset, one notch calmer on
variance because the legal pages share the shell.

Two deliberate overrides of that skill, recorded so nobody "fixes" them:

- **The palette is cream, navy and ochre.** The skill bans warm paper plus
  ochre as a default for premium-consumer briefs. This is not a default: it is
  the palette of `lib/core/theme/tokens.dart` and of the shipped icon
  (colourway 3b). The site and the app must read as one product. Ochre is
  confined to the mark; the page accent is the navy.
- **Instrument Sans is the display and body face, and the only face.** It is
  the app's bundled font (OFL), so the site uses it too. The spec first paired
  it with JetBrains Mono for numerals and an eyebrow; the page ended up with
  neither, so the mono font was dropped in `03f2b04`. It was 57% of the
  render-blocking CSS and its inlined subset was the only reason the CSP
  needed `font-src 'self' data:`. A gate in `site/test/external.test.mjs` now
  fails the build if any built stylesheet inlines a font.

## Pages and URLs

| URL | Page | Notes |
|---|---|---|
| `/` | Landing | Described below. |
| `/privacy` | Privacy Policy | Rendered from `docs/legal/privacy.md`. The Privacy Policy URL for both stores. |
| `/terms` | Terms of Use | Rendered from `docs/legal/terms.md`. Not emitted until listed in config (see Legal pages). |
| `/support` | Support | The Apple Support URL and the site's contact page. |
| `/404` | Not found | Caddy serves it for any unknown path. |

Slugs are permanent once the store fields are filled in.

## Visual system

**Colour.** CSS custom properties transcribed from `tokens.dart`, with the
token name kept in a comment beside each value so a change in the app is a
one-line change here.

| Property | Light | Dark | Source |
|---|---|---|---|
| `--paper` (page) | `#F7F6F3` | `#141417` | `BqColors.paper`; dark is a warm off-black, not `#000` |
| `--canvas` (bands) | `#EAE9E4` | `#1C1C21` | `BqColors.canvas` |
| `--panel` | `#FBFBF9` | `#222228` | `BqColors.surfaceAlt` |
| `--ink` | `#17171B` | `#EDECE8` | `BqColors.ink` |
| `--ink-2` | `#5C5C66` | `#A9A9B3` | `BqColors.textSecondary` |
| `--accent` | `#4A4E7C` | `#8D93B8` | `BqColors.accent`; dark uses the icon's lighter navy |
| `--hairline` | `rgb(23 23 27 / .08)` | `rgb(255 255 255 / .10)` | `BqColors.hairline` |

One accent on the whole page. The ochre (`#E2B95C` / `#B98A2E`) appears only
inside the SVG mark. No pure white, no pure black. Dark mode follows
`prefers-color-scheme` with no manual toggle.

**Type.** `@fontsource-variable/instrument-sans`, self-hosted,
`font-display: swap`. Fontsource hashes its file names, so a static
`<link rel="preload">` cannot name them; the swap plus a metric-compatible
fallback stack is what ships. Display: weight 600, `letter-spacing: -0.02em`,
`line-height: 1.05`. Body: weight 400, 17px, `line-height: 1.55`, measure
capped at 65ch. Headline scale `clamp(2.5rem, 6vw, 4.25rem)`.

**Shape.** One system: interactive elements are pills; panels and the phone
frame are 20px; the phone screen inside the frame is 14px. Nothing else has a
radius.

**Elevation.** One shadow, tinted to the paper:
`0 24px 60px -24px rgb(23 23 27 / .25)` in light, `rgb(0 0 0 / .5)` in dark.
Used on the phone frame only. No card shadows; grouping is by space and
hairlines.

**The mark.** An SVG transcription of `tool/make_icons.py`: two capsules
45x166 in a 236 artboard, bottom edge 44 up from the artboard bottom, rotated
plus and minus 26 degrees about a pivot at `(h - w/2)/h` of the capsule's
length, each split lengthwise into two flat colours (back: `#4B5079` over
`#8D93B8`; front: `#E2B95C` over `#B98A2E`). The SVG is rasterised during the
build of the OG image and diffed against
`store/icon/3b/appstore-icon-1024.png`; a visible mismatch is a build failure
of the asset script, not something to eyeball. The wordmark is "VitoMy" in
Instrument Sans 600.

**Icons.** Phosphor, regular weight, inlined at build time from
`@phosphor-icons/core`. One family, `stroke-width` fixed. The only icons on
the site are the Apple and Google Play logos in the store buttons and the
envelope on the support page.

## The landing page

Five sections, four layout families, zero or one eyebrow in total. Real
screenshots throughout, from `store/screenshots/ios-6.9/` (1320x2868,
regenerated by `tool/make_screenshots.sh`), passed through Astro's image
pipeline to AVIF and WebP at 480, 720 and 960 wide.

### 1. Header

64px, one line. Left: the mark and wordmark, linking to `/`. Right: "Support"
and "Privacy". No hamburger is needed at any width; on phones the two links
stay, the wordmark stays, nothing wraps.

### 2. Hero, asymmetric split

Left column (7 of 12): headline, subtext, the two store buttons. Right column
(5 of 12): the Today screenshot inside the phone frame, upright, with the one
shadow. `min-height: 100dvh` less the header, never `100vh`. Top padding
capped at 6rem.

- Headline, two lines at desktop: **Plan what you take. See it laid out.**
- Subtext, 17 words: *Set on and off weeks once. VitoMy shows what is due today
  and how the months line up.*
- CTAs: the two store buttons (see Store buttons). Nothing under them. No
  eyebrow, no trust strip, no tagline.

Load motion: headline, subtext, buttons and phone enter with a 600ms
`opacity` + `translateY(16px)` cascade on `cubic-bezier(.16,1,.3,1)`, in CSS,
gated by `prefers-reduced-motion: no-preference`.

Mobile: single column, phone below the copy, buttons full width and stacked.

### 3. The scene, pinned

The Apple moment and the only JavaScript on the page. A section of three
steps: Today, Cycles, Year. At desktop the section pins for three viewport
heights; the phone stays fixed on the right while its screenshot crossfades
between the three, and the copy on the left swaps in step. GSAP ScrollTrigger
with `pin: true`, `start: "top top"`, `scrub: 0.6`, following the canonical
skeleton in the skill. GSAP is imported dynamically when the section first
enters the viewport, so the legal pages and the initial landing paint never
load it.

Step copy, each a headline of at most eight words and one sentence of at most
twenty:

| Step | Headline | Sentence |
|---|---|---|
| Today | Everything due today, in one list. | Tap to mark it taken. The time sits beside each one. |
| Cycles | Eight weeks on, four off. Drawn, not remembered. | Every schedule is a bar across the months, breaks included. |
| Year | Twelve months at a glance. | How much of each month is covered, on one screen. |

Motion is motivated: the swap tells the product's story in the order the app
presents it, Today then Cycles then Year, and the phone staying still while
its contents change is the same gesture the app makes when you switch tabs.

Below 1024px, and always under reduced motion, the section is not pinned:
three plain rows, copy above screenshot, no JavaScript loaded at all. That
fallback is the section's mobile design, not a degradation.

### 4. Download band

Full-width `--canvas` band, left-aligned content, no cards.

- Headline: **Coming to iPhone and Android.**
- One sentence: *No account and no server. What you enter stays on your
  phone.* (This is where the privacy point lives; it is not a section.)
- The two store buttons, same labels as the hero. The same intent uses the
  same label everywhere on the page, which is what the duplicate-CTA rule
  actually asks.

Reveal on scroll via CSS `animation-timeline: view()` inside `@supports`, so
browsers without scroll-driven animations simply show it.

### 5. Footer

Two columns on a hairline. Left: the mark, "VitoMy", "© 2026 VitoMy".
Right: Privacy, Terms (only when listed), Support, and
`support@vitomy.app` as a `mailto:` link. No version string, no locale, no
social row.

### What the landing deliberately does not have

No seven-languages section, no privacy section, no testimonials, no logo
wall, no pricing, no FAQ, no newsletter, no cookie banner (there are no
cookies). The page has one job: show three screens and point at two stores.

## Store buttons

`src/config.ts`:

```ts
export const stores = {
  apple:  { url: null as string | null },   // set to the App Store URL on launch day
  google: { url: null as string | null },   // set to the Play URL on launch day
};
```

`StoreButton.astro` takes `store: "apple" | "google"` and renders one of two
things:

- **`url` is null:** a `<span role="img" aria-label="App Store, coming soon">`
  styled as a pill button in `--accent` at 55% opacity, with the Phosphor
  logo glyph, the store name, and a smaller "Coming soon" beneath the name.
  Not focusable, not a link, no `href`. The cursor is default, not a
  pointer.
- **`url` is set:** an `<a>` to that URL wrapping the **official** badge
  image from `public/badges/app-store.svg` or `public/badges/google-play.png`,
  with `rel="noopener"`. Apple and Google both forbid altering their badges,
  which is why a greyed-out official badge is not an option before launch and
  why the pre-launch button is our own. The badge files are downloaded by a
  human on launch day (Apple's requires accepting its licence); the build
  fails if a store has a URL and its badge file is absent.

## Legal pages

`src/content.config.ts` defines a `legal` collection with a glob loader whose
`base` is `../docs/legal` and whose pattern is `privacy.md` and `terms.md`
only. The research document is never a candidate.

`src/config.ts`:

```ts
export const legalPages = ["privacy"] as const;   // add "terms" once [NOMINAL_SUM] is filled
```

`src/pages/[legal].astro` emits a page for each listed document and nothing
for the rest; the footer reads the same list. An Astro integration hook on
`astro:build:start` reads each listed source file and fails the build with
the file and line if `/\[[A-Z_]+\]/` matches. This is the mechanism behind
the interview answer "the build fails on a placeholder".

Two consequences, both intended:

- `docs/legal/privacy.md` line 3 reads `Last updated: [LAST_UPDATED]`. The
  first deploy fills it with the publication date. That is a one-word edit
  to the app repository, permitted by
  `test_release/legal_copy_safety_test.dart`, and it is in the plan.
- `/terms` returns 404 and is linked from nowhere until Dima fills
  `[NOMINAL_SUM]` and adds `"terms"` to the list. Neither store needs the
  Terms URL to accept a submission.

Rendering: `LegalLayout.astro`, the shared header and footer, a 68ch column,
`h1` from the document's first heading, the "Last updated" line as the
document wrote it, `h2` sections with a hairline above each. The document's
own words are the page; the layout adds no text.

## Support page

`/support`, in the same shell, one column:

- **Support**, then the address `support@vitomy.app` as a large `mailto:`
  link with the Phosphor envelope glyph.
- "What to include" as a short list: the phone model, the OS version, what
  was expected and what happened, and a screenshot if there is one.
- One paragraph on what VitoMy is, taken from `store/listing.md`: it plans,
  reminds and records; it does not suggest what to take, how much, or
  whether.
- A link to the Privacy Policy.

No form (there is no backend), no promised response time, no FAQ.

## 404

The shell, "This page does not exist", a link to `/`. Caddy's
`handle_errors` rewrites unknown paths to it with the 404 status preserved.

## Meta, SEO and assets

- Every page: `<html lang="en">`, `<title>`, `meta description`, canonical
  `https://vitomy.app<path>`, `og:title`, `og:description`, `og:image`,
  `twitter:card summary_large_image`, `theme-color` for both schemes.
- Landing title `VitoMy: Supplement Planner`; description is the Play short
  description from `store/listing.md` (77 characters).
- `site/scripts/make_og.py` (Python, PIL, same toolchain as `make_icons.py`)
  renders `public/og.png` at 1200x630: paper ground, the mark, the wordmark,
  the headline. It also writes `public/favicon.svg` from the mark and
  `public/apple-touch-icon.png` at 180 from the 1024 store icon.
- `@astrojs/sitemap` for `sitemap-index.xml`; `public/robots.txt` allowing
  everything and naming the sitemap.
- Astro config: `site: "https://vitomy.app"`, `output: "static"`,
  `build.inlineStylesheets: "never"` so the CSP below needs no
  `unsafe-inline`, `trailingSlash: "never"`, `build.format: "file"` so
  `/privacy` is `privacy.html` and Caddy serves it without a redirect.

## Deployment

**Layout on the server.** Document root `/var/www/vitomy`. Caddy block in
`/etc/caddy/sites/vitomy.caddy`, included by one `import
/etc/caddy/sites/*.caddy` line appended once to `/etc/caddy/Caddyfile`. The
existing blocks for rin.live, api.rin.live, cryptobot.rin.live and
shukaybook.com are never touched.

**`site/deploy/vitomy.caddy`:**

```
vitomy.app {
	root * /var/www/vitomy
	file_server
	try_files {path} {path}.html
	encode zstd gzip
	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options nosniff
		Referrer-Policy strict-origin-when-cross-origin
		Permissions-Policy "camera=(), microphone=(), geolocation=()"
		Content-Security-Policy "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; font-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'none'"
	}
	handle_errors {
		rewrite * /404.html
		file_server
	}
}

www.vitomy.app {
	redir https://vitomy.app{uri} 308
}
```

TLS is automatic: Caddy obtains a certificate the moment the A record
resolves to the server. There is no Cloudflare in front of this domain, so
none of the origin-certificate lines the neighbouring blocks carry apply.

**`site/scripts/deploy.sh`**, run as `npm run deploy` from `site/`:

1. `npm run build`, then `npm test`. Any failure stops the script.
2. `rsync -az --delete --chmod=D755,F644 dist/ bot:/var/www/vitomy/`,
   preceded by a `--dry-run` whose output is shown.
3. Copy `deploy/vitomy.caddy` to `/etc/caddy/sites/vitomy.caddy` if it
   differs; append the import line to the main Caddyfile if absent;
   `caddy validate`; `systemctl reload caddy` (never restart).
4. Smoke test from this machine: status codes for `/`, `/privacy`,
   `/support` (200), `/terms` (404 while unlisted), `/nonsense` (404); the
   landing HTML grepped for `[`, the em dash, and any third-party `src` or
   `href`.

Only the `site-deployer` agent runs this. Its definition carries the hard
limits.

**DNS, for Dima to add in Spaceship** (keep every existing MX and TXT
record):

| Type | Host | Value | TTL |
|---|---|---|---|
| A | `@` | `45.159.220.17` | 300 |
| A | `www` | `45.159.220.17` | 300 |

Until those exist the site can be previewed locally (`npm run preview`) and
on the server with `curl --resolve vitomy.app:443:45.159.220.17`, but Caddy
cannot hold a certificate for it.

## Gates

`site/test/*.test.mjs`, `node:test`, run by `npm test` over `dist/`. They
are the site's equivalent of the app's copy and platform gates, and they run
before every deploy.

| Gate | What it rejects |
|---|---|
| `placeholders` | `[UPPER_CASE]` anywhere in any emitted HTML |
| `dashes` | the em dash or the en dash in any text node |
| `vocabulary` | the English stems of `test_release/copy_safety_all_locales_test.dart`, read from that file so the two lists cannot drift, plus `donate` and `donation` |
| `external` | any `src`, `href`, `srcset`, `url()` or `@import` not on the site, other than `mailto:support@vitomy.app` and an enabled store URL |
| `stores` | with `url: null`: no anchor to `apps.apple.com` or `play.google.com` and the text "Coming soon" present twice on the landing; with a URL: the badge file exists and the anchor carries it |
| `legal` | every `##` of a listed source document appears as an `h2` in its page; an unlisted document has no emitted page and no link anywhere |
| `meta` | `lang`, title, description, canonical, `og:image` on every page; `alt`, `width`, `height` on every `img`; no inline `<script>` |

Not gated, but recorded in `site/README.md` and checked by `site-reviewer`
before the first deploy: Lighthouse at or above 95 performance and 100 on
accessibility, best practices and SEO, in both colour schemes; the hero CTA
visible without scrolling at 1440x900 and at 390x844; the pinned scene
correct in Safari, Chrome and Firefox, and fully static under reduced
motion.

## Project layout

```
site/
  CLAUDE.md                  the short rules; written
  README.md                  how to run, test, deploy; Lighthouse record
  package.json               astro, @astrojs/sitemap, gsap, @phosphor-icons/core,
                             @fontsource-variable/instrument-sans
  astro.config.mjs
  src/
    config.ts                stores, legalPages
    content.config.ts        the legal collection over ../docs/legal
    styles/tokens.css        the custom properties, both schemes
    styles/global.css        reset, type, focus rings, reduced-motion block
    layouts/Base.astro       head, header, footer
    layouts/Legal.astro
    components/Mark.astro    the SVG mark
    components/StoreButton.astro
    components/PhoneFrame.astro
    components/Scene.astro   the pinned section and its fallback
    components/Scene.ts      the GSAP island, imported dynamically
    pages/index.astro
    pages/[legal].astro
    pages/support.astro
    pages/404.astro
  integrations/legal-gate.mjs
  scripts/make_og.py
  scripts/deploy.sh
  deploy/vitomy.caddy
  public/robots.txt, favicon.svg, og.png, apple-touch-icon.png, badges/
  test/*.test.mjs
```

The Flutter suites do not see this directory: `flutter test` reads `test/`
only, `flutter analyze` ignores non-Dart files, and
`test/l10n/no_hardcoded_strings_test.dart` globs `lib/`.

## Agents

Three, in `.claude/agents/`, written alongside this spec:

- **`site-builder`** writes pages, styles, copy and assets. Loads
  `design-taste-frontend` and `high-end-visual-design`, reads `site/CLAUDE.md`
  and this spec first, commits locally, runs build and gates before reporting.
- **`site-reviewer`** is read-only. Runs the gates, the skill's section 14
  pre-flight, accessibility and the no-external-resource audit against the
  built output, and returns ranked findings.
- **`site-deployer`** is the only agent that opens an ssh session. It follows
  the deployment protocol above and carries the list of things on that server
  it must never touch.

## Process from here

1. Dima reviews this spec.
2. `writing-plans` produces the implementation plan.
3. Execution is subagent-driven with the three agents above, task by task,
   with a review between tasks. The site is tracked as `SITE-01` in
   `.planning/STATE.md`; every commit is local, nothing is pushed.
4. First deploy publishes `/`, `/privacy` and `/support`. `/terms` follows
   when `[NOMINAL_SUM]` is filled and `"terms"` is added to `legalPages`.
5. Launch day: set the two store URLs, drop the two official badge files
   into `public/badges/`, deploy.

## Open decisions, with the default this spec takes

| Decision | Default here | Change it if |
|---|---|---|
| Hero headline | "Plan what you take. See it laid out." | Dima prefers another line; two lines at desktop is the only constraint. |
| Dark theme | Automatic from the system, no toggle | Someone wants a toggle; the tokens already support it. |
| Store URLs | Unknown until the listings exist | Set on launch day in `config.ts`. |
| `[LAST_UPDATED]` in privacy.md | Filled with the first deploy date | Legal wants a different date. |
| Other languages | Not in this spec | A later phase: Astro's i18n routing, one folder per locale, translations of the landing copy only. Legal stays English unless translated by a lawyer. |
