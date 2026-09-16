# vitomy.app, the website

The marketing and legal site for VitoMy, live at `https://vitomy.app` since
2026-09-12. A subproject of the app repository: it lives in `site/`, it ships
as static files, and it is deployed by rsync to the server `bot` behind Caddy,
which in turn sits behind Cloudflare. It has no backend, no analytics, no
cookies and no third-party request of any kind.

`/privacy` and `/support` are the URLs both app stores require. Breaking either
one breaks a live store listing, so treat them as production.

Spec: `docs/superpowers/specs/2026-09-11-vitomy-site-design.md`. Read it
before changing a page. Everything below is the short form.

## What it is

Astro, static output, four pages: `/`, `/privacy`, `/terms` (gated, see
below), `/support`, plus `/404`. English only. Light theme in the app's own
palette with an automatic dark theme under `prefers-color-scheme`.

## Rules that carry liability, not taste

- **No health or medical vocabulary anywhere on the site.** The app is a
  planner in the Lifestyle category and the whole legal position depends on
  never describing an outcome. No *health*, *medical*, *dose safety*,
  *interaction*, *dietary*, *wellness*, *risk*, *advice*, *treatment*,
  *symptom*, *effective*. `site/test/` has the gate; store/listing.md has the
  reasoning.
- **No claim the app does not make.** It plans, reminds and records. It never
  suggests what to take, how much, or whether.
- **The words "donate" and "donation" never appear.** Apple 3.2.2(iv). Say
  "support" or "tip" if the subject ever comes up.
- **No em dash or en dash in rendered text.** Comma, period, colon or a plain
  hyphen. The app's ARB files were stripped of them and the site follows.
- **Address the reader impersonally, never guilt-framed.** Same copy rules as
  the app: `.claude/skills/vitomy-design/SKILL.md`, section "Copy constraints".

## Rules the build enforces

- **Legal pages render from `../docs/legal/*.md` at build time.** The markdown
  in the app repo is the only source; nothing legal is authored in `site/`.
  `src/config.ts` lists which documents are published. A listed document that
  still contains a `[PLACEHOLDER]` fails the build. An unlisted document is
  not emitted and not linked.
- **Store buttons are driven by `src/config.ts`.** A store with `url: null`
  renders a non-interactive in-brand button labelled "Coming soon". A store
  with a URL renders the official badge from `public/badges/` linking to it,
  and the build fails if that badge file is missing.
- **No external resource.** Fonts are self-hosted through `@fontsource-variable`
  packages, icons are inlined Phosphor SVGs, images are built by Astro. The
  gate rejects any `http(s)://` in `src` or `href` except the store links.
- **Every page has** `<html lang="en">`, a title, a meta description, a
  canonical URL and an OG image; every `<img>` has `alt`, `width` and
  `height`.

## Design in one paragraph

Palette and type come from the app: paper `#F7F6F3`, canvas `#EAE9E4`, ink
`#17171B`, navy accent `#4A4E7C`; Instrument Sans for everything. The ochre
of the icon appears in the mark only.
One accent colour on the whole page, one radius system (pill buttons, 20px
panels), no elevation beyond a soft shadow tinted to the paper. Dials from the
`design-taste-frontend` skill: `DESIGN_VARIANCE 7 / MOTION_INTENSITY 6 /
VISUAL_DENSITY 3`. Real screenshots from `store/screenshots/ios-6.9/`, never a
fake product UI built from divs. Motion is one GSAP-pinned scene and CSS
reveals, all of it off under `prefers-reduced-motion`.

## Workflow

- Load `design-taste-frontend` before touching a page and run its section 14
  pre-flight before calling anything done. `high-end-visual-design` is
  available for materiality and motion; where the two skills disagree, the
  spec and this file win, and both lose to the liability rules above.
- Agents: `site-builder` writes, `site-reviewer` audits read-only,
  `site-deployer` is the only thing that talks to the server. See
  `.claude/agents/site-*.md`.
- Commands, from `site/`: `npm run dev`, `npm run build`, `npm test` (gates
  over `dist/`), `npm run deploy` (build, gates, rsync, Caddy, smoke test).
- The app's own suites are untouched by this directory: `flutter test` reads
  `test/` only and `flutter analyze` ignores non-Dart files.
