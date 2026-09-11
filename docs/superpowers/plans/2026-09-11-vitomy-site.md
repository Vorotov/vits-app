# vitomy.app Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `https://vitomy.app`: a landing page with real screenshots and one pinned scroll scene, the Privacy Policy and Support pages the stores require, the Terms page behind a placeholder gate, all deployed as static files to the server `bot` behind Caddy.

**Architecture:** An Astro static project in `site/` inside the app repository. Legal pages render at build time from `docs/legal/*.md`; an Astro integration fails the build if a published document still carries a `[PLACEHOLDER]`. A set of `node:test` gates runs over the built `dist/` before every deploy and rejects medical vocabulary, dashes, placeholders, external resources and missing metadata. Deployment is rsync over ssh plus one Caddy vhost file.

**Tech Stack:** Astro 7.3, `@astrojs/sitemap` 3.7, GSAP 3.15 (ScrollTrigger, one pinned scene, lazy-loaded), `@phosphor-icons/core` 2.1 (inlined SVG), `@fontsource-variable/instrument-sans` and `@fontsource-variable/jetbrains-mono` 5.3 (self-hosted), Node 24 (`node --test`), Python 3 + Pillow for the OG image, Caddy on Ubuntu 22.04.

**Spec:** `docs/superpowers/specs/2026-09-11-vitomy-site-design.md`. Read it first; every task below argues from it. Also read `site/CLAUDE.md`.

## Global Constraints

- Node is at `/Users/dima/.nvm/versions/node/v24.16.0/bin`; it is NOT on PATH in a fresh shell. Every `npm`/`node`/`npx` command below assumes `export PATH=/Users/dima/.nvm/versions/node/v24.16.0/bin:$PATH` has been run first.
- All `npm`, `node`, `python3` commands run from `/Users/dima/supplements/site` unless stated. All `git` and `flutter` commands run from `/Users/dima/supplements`.
- **No health or medical vocabulary in any visible text or attribute.** The stem list is `legalForbiddenStems` in `test_release/legal_copy_safety_test.dart`; the site gate reads that list from the Dart file. Also banned: `donate`, `donation`.
- **No em dash (U+2014) or en dash (U+2013)** in any visible text or attribute. Use a comma, period, colon or hyphen.
- **No external resource.** No CDN, no Google Fonts `<link>`, no hotlinked image, no analytics. The only permitted non-site URLs are `mailto:support@vitomy.app` and, when enabled in config, the two store URLs.
- **Colours come from `lib/core/theme/tokens.dart`** via the custom properties in `src/styles/tokens.css`. No new hex literal outside that file.
- **One accent (`--accent`), one radius system** (pills for interactive elements, 20px panels, 14px phone screen), **one theme per page** with the dark variant from `prefers-color-scheme`.
- **Every animation** sits behind `@media (prefers-reduced-motion: no-preference)` or a `matchMedia` check for the same query. `window.addEventListener('scroll', ...)` is banned.
- **No inline `<script>`.** Astro bundles `<script>` tags in `.astro` files to external modules; do not use `is:inline`.
- `build.inlineStylesheets: 'never'` stays set; the CSP on the server has no `unsafe-inline`.
- Legal text is never authored in `site/`. It renders from `docs/legal/`.
- Commits are local. **This repository has no remote; never push.** Commit messages use `feat(site):`, `fix(site):`, `test(site):`, `docs(site):`, `chore(site):`.
- Other files in the working tree that you did not create (`skills-lock.json`, `.planning/quick/`, `store/screenshots/ios-6.5/`) belong to another session. Never `git add` them; always add by explicit path.
- The Flutter suites must stay green and untouched: `flutter test` reads `test/` only; nothing in this plan edits `lib/` or `test/`. Task 4 edits `docs/legal/privacy.md` (one line) and runs the Dart legal gate to prove it still passes.

## File Structure

```
site/
  package.json, package-lock.json, astro.config.mjs, tsconfig.json
  README.md                          run / test / deploy / Lighthouse record      (Task 10)
  src/
    config.ts                        stores, legalPages, supportEmail            (Task 1)
    content.config.ts                the legal collection over ../docs/legal      (Task 4)
    styles/tokens.css                custom properties, both schemes             (Task 1)
    styles/global.css                reset, type, focus, buttons, reduced motion (Task 1)
    layouts/Base.astro               head, header, footer                        (Task 1, footer Task 2, links Task 4)
    layouts/Legal.astro              68ch article                                (Task 4)
    components/Mark.astro            GENERATED SVG mark                          (Task 2)
    components/StoreButton.astro                                                 (Task 5)
    components/PhoneFrame.astro                                                  (Task 6)
    components/Scene.astro, Scene.ts pinned section and its GSAP island         (Task 7)
    pages/index.astro                                                            (Task 1 shell; 6, 7, 8 fill it)
    pages/[legal].astro                                                          (Task 4)
    pages/support.astro                                                          (Task 9)
    pages/404.astro                                                              (Task 9)
    assets/screens/                  copied from store/screenshots (gitignored)  (Task 6)
  integrations/legal-gate.mjs                                                    (Task 4)
  scripts/make_og.py                 favicon.svg, og.png, apple-touch-icon.png, Mark.astro (Task 2)
  scripts/sync-screens.mjs                                                       (Task 6)
  scripts/deploy.sh                                                              (Task 10)
  deploy/vitomy.caddy                                                            (Task 10)
  public/robots.txt, favicon.svg, og.png, apple-touch-icon.png, badges/.gitkeep
  test/helpers.mjs                   dist walker, text extraction                (Task 1)
  test/meta.test.mjs                                                             (Task 1)
  test/mark.test.mjs                                                             (Task 2)
  test/placeholders.test.mjs, dashes.test.mjs, vocabulary.test.mjs, external.test.mjs (Task 3)
  test/legal.test.mjs                                                            (Task 4)
  test/stores.test.mjs                                                           (Task 5)
  test/scene.test.mjs                                                            (Task 7)
```

---

### Task 1: Project scaffold, tokens, base layout, and the `meta` gate

**Files:**
- Create: `site/package.json`, `site/astro.config.mjs`, `site/tsconfig.json`
- Create: `site/src/config.ts`, `site/src/styles/tokens.css`, `site/src/styles/global.css`
- Create: `site/src/layouts/Base.astro`, `site/src/pages/index.astro`
- Create: `site/public/robots.txt`, `site/public/badges/.gitkeep`
- Create: `site/test/helpers.mjs`, `site/test/meta.test.mjs`

**Interfaces:**
- Produces: `Base.astro` with `Props { title: string; description: string }` and a default slot. `config.ts` exporting `stores`, `legalPages`, `supportEmail`. `helpers.mjs` exporting `DIST`, `htmlFiles()`, `textOf(html)`, `attrValues(html, name)`.

- [ ] **Step 1: Create `package.json`**

```json
{
  "name": "vitomy-site",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview",
    "test": "node --test test/",
    "assets": "python3 scripts/make_og.py",
    "deploy": "bash scripts/deploy.sh"
  },
  "dependencies": {
    "@astrojs/sitemap": "^3.7.4",
    "@fontsource-variable/instrument-sans": "^5.3.0",
    "@fontsource-variable/jetbrains-mono": "^5.3.0",
    "@phosphor-icons/core": "^2.1.1",
    "astro": "^7.3.2",
    "gsap": "^3.15.0"
  }
}
```

- [ ] **Step 2: Create `astro.config.mjs` and `tsconfig.json`**

```js
// site/astro.config.mjs
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://vitomy.app',
  output: 'static',
  trailingSlash: 'never',
  build: {
    format: 'file',            // /privacy -> privacy.html, served by Caddy try_files
    inlineStylesheets: 'never', // the CSP has no 'unsafe-inline'
  },
  integrations: [sitemap()],
});
```

```json
{ "extends": "astro/tsconfigs/strict", "include": [".astro/types.d.ts", "**/*"], "exclude": ["dist"] }
```

- [ ] **Step 3: Install**

Run: `npm install`
Expected: `node_modules/` created, `package-lock.json` written, no vulnerabilities blocking. Confirm `git status --short` shows `site/package-lock.json` as untracked and NOT `site/node_modules` (the root `.gitignore` already excludes it).

- [ ] **Step 4: Create `src/config.ts`**

```ts
// The two switches the spec puts in one place. Both are read at build time.

/** Store links. `url: null` renders an inert "Coming soon" button; a URL
 *  renders the OFFICIAL badge from public/badges/ and links to it. Set both
 *  on launch day. */
export const stores = {
  apple: { url: null as string | null, label: 'App Store', badge: '/badges/app-store.svg' },
  google: { url: null as string | null, label: 'Google Play', badge: '/badges/google-play.png' },
} as const;

export type StoreId = keyof typeof stores;

/** Which documents in ../docs/legal are published. A listed document that
 *  still contains a [PLACEHOLDER] fails the build (integrations/legal-gate.mjs).
 *  Add 'terms' once [NOMINAL_SUM] is filled. */
export const legalPages: readonly string[] = ['privacy'];

export const supportEmail = 'support@vitomy.app';
```

- [ ] **Step 5: Create `src/styles/tokens.css`**

Every value is transcribed from `lib/core/theme/tokens.dart`; the comment names the token. Dark values are the spec's.

```css
/* Transcribed from lib/core/theme/tokens.dart. Change there first. */
:root {
  color-scheme: light dark;
  --paper: #F7F6F3;                 /* BqColors.paper */
  --canvas: #EAE9E4;                /* BqColors.canvas */
  --panel: #FBFBF9;                 /* BqColors.surfaceAlt */
  --ink: #17171B;                   /* BqColors.ink */
  --ink-2: #5C5C66;                 /* BqColors.textSecondary */
  --accent: #4A4E7C;                /* BqColors.accent */
  --accent-pressed: #3D4169;        /* BqColors.accentPressed */
  --hairline: rgb(23 23 27 / 0.08); /* BqColors.hairline */
  --shadow: 0 24px 60px -24px rgb(23 23 27 / 0.25);

  --font-sans: 'Instrument Sans Variable', system-ui, -apple-system, 'Segoe UI', sans-serif;
  --font-mono: 'JetBrains Mono Variable', ui-monospace, 'SF Mono', Menlo, monospace;

  --radius-panel: 20px;
  --radius-screen: 14px;
  --radius-pill: 999px;
  --header-h: 64px;
  --measure: 65ch;
}

@media (prefers-color-scheme: dark) {
  :root {
    --paper: #141417;
    --canvas: #1C1C21;
    --panel: #222228;
    --ink: #EDECE8;
    --ink-2: #A9A9B3;
    --accent: #8D93B8;              /* the icon's lighter navy, VARIANTS['3b'].back_capsule[1] */
    --accent-pressed: #A3A8C8;
    --hairline: rgb(255 255 255 / 0.10);
    --shadow: 0 24px 60px -24px rgb(0 0 0 / 0.5);
  }
}
```

- [ ] **Step 6: Create `src/styles/global.css`**

```css
*, *::before, *::after { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; scroll-behavior: auto; }
body {
  margin: 0;
  background: var(--paper);
  color: var(--ink);
  font-family: var(--font-sans);
  font-size: 17px;
  line-height: 1.55;
  font-feature-settings: 'ss01', 'cv11';
}
img, picture, svg { display: block; max-width: 100%; height: auto; }
h1, h2, h3 { margin: 0; font-weight: 600; letter-spacing: -0.02em; line-height: 1.05; }
h1 { font-size: clamp(2.5rem, 6vw, 4.25rem); }
h2 { font-size: clamp(1.75rem, 3.5vw, 2.5rem); }
p { margin: 0; max-width: var(--measure); }
a { color: inherit; text-decoration-thickness: 1px; text-underline-offset: 0.15em; }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; border-radius: 4px; }

.wrap { width: min(100% - 2rem, 1200px); margin-inline: auto; }
.muted { color: var(--ink-2); }
.mono { font-family: var(--font-mono); font-size: 0.8125rem; letter-spacing: 0.02em; }

/* One pill button. Interactive feedback only where there is an actual link. */
.pill {
  display: inline-flex; align-items: center; gap: 0.6rem;
  min-height: 48px; padding: 0 1.25rem;
  border-radius: var(--radius-pill);
  font-weight: 600; text-decoration: none;
}
.pill--solid { background: var(--accent); color: var(--paper); }
a.pill--solid:hover { background: var(--accent-pressed); transform: translateY(-1px); }
a.pill--solid:active { transform: scale(0.98); }
@media (prefers-reduced-motion: no-preference) {
  a.pill { transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), background 0.2s; }
}

.site-header {
  height: var(--header-h);
  display: flex; align-items: center; justify-content: space-between;
  border-bottom: 1px solid var(--hairline);
}
.site-header__brand { display: inline-flex; align-items: center; gap: 0.6rem; font-weight: 600; text-decoration: none; }
.site-header__nav { display: flex; gap: 1.5rem; }
.site-header__nav a { text-decoration: none; }
.site-header__nav a:hover { text-decoration: underline; }

.site-footer { border-top: 1px solid var(--hairline); padding-block: 3rem; margin-top: 6rem; }
.site-footer__row { display: grid; grid-template-columns: 1fr; gap: 2rem; }
@media (min-width: 768px) { .site-footer__row { grid-template-columns: 1fr 1fr; } }
.site-footer__links { display: flex; flex-wrap: wrap; gap: 1.25rem 2rem; justify-self: start; }
@media (min-width: 768px) { .site-footer__links { justify-self: end; } }
```

- [ ] **Step 7: Create `src/layouts/Base.astro`**

The header brand shows the wordmark only for now; Task 2 inserts the SVG mark. The footer links are filtered by `legalPages`, which is what Task 4's gate checks.

```astro
---
import '@fontsource-variable/instrument-sans';
import '@fontsource-variable/jetbrains-mono';
import '../styles/tokens.css';
import '../styles/global.css';
import { legalPages, supportEmail } from '../config';

interface Props { title: string; description: string }
const { title, description } = Astro.props;
const canonical = new URL(Astro.url.pathname, Astro.site);
const ogImage = new URL('/og.png', Astro.site);
const legalLinks = [
  { id: 'privacy', label: 'Privacy' },
  { id: 'terms', label: 'Terms' },
].filter((l) => legalPages.includes(l.id));
---
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={canonical} />
    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
    <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="VitoMy" />
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:url" content={canonical} />
    <meta property="og:image" content={ogImage} />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="theme-color" media="(prefers-color-scheme: light)" content="#F7F6F3" />
    <meta name="theme-color" media="(prefers-color-scheme: dark)" content="#141417" />
  </head>
  <body>
    <header class="site-header wrap">
      <a class="site-header__brand" href="/">VitoMy</a>
      <nav class="site-header__nav" aria-label="Site">
        <a href="/support">Support</a>
        <a href="/privacy">Privacy</a>
      </nav>
    </header>
    <main><slot /></main>
    <footer class="site-footer">
      <div class="wrap site-footer__row">
        <div>
          <div class="site-header__brand">VitoMy</div>
          <p class="muted">© 2026 VitoMy</p>
        </div>
        <nav class="site-footer__links" aria-label="Legal and support">
          {legalLinks.map((l) => <a href={`/${l.id}`}>{l.label}</a>)}
          <a href="/support">Support</a>
          <a href={`mailto:${supportEmail}`}>{supportEmail}</a>
        </nav>
      </div>
    </footer>
  </body>
</html>
```

The `theme-color` hex values duplicate two tokens on purpose: `<meta>` cannot read CSS. They are the only hex literals outside `tokens.css`, and this comment in the plan is where that is recorded.

- [ ] **Step 8: Create `src/pages/index.astro` as a shell**

Tasks 6, 7 and 8 replace the body. For now it proves the layout builds.

```astro
---
import Base from '../layouts/Base.astro';
---
<Base title="VitoMy: Supplement Planner" description="Plan your supplement cycles, get reminders, mark what you take. All on-device.">
  <section class="wrap" style="padding-block: 4rem">
    <h1>Plan what you take. See it laid out.</h1>
  </section>
</Base>
```

- [ ] **Step 9: Create `public/robots.txt` and `public/badges/.gitkeep`**

```
User-agent: *
Allow: /

Sitemap: https://vitomy.app/sitemap-index.xml
```

`.gitkeep` is empty.

- [ ] **Step 10: Write `test/helpers.mjs`**

```js
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

export const DIST = fileURLToPath(new URL('../dist/', import.meta.url));

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

/** Every file in dist/ as { path, rel, html|css|text }. */
export function distFiles() {
  return walk(DIST).map((path) => ({ path, rel: relative(DIST, path) }));
}

export function htmlFiles() {
  return distFiles()
    .filter((f) => f.rel.endsWith('.html'))
    .map((f) => ({ ...f, html: readFileSync(f.path, 'utf8') }));
}

export function cssFiles() {
  return distFiles()
    .filter((f) => f.rel.endsWith('.css'))
    .map((f) => ({ ...f, css: readFileSync(f.path, 'utf8') }));
}

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', '#39': "'" };
export function decode(s) {
  return s.replace(/&(#\d+|#x[0-9a-f]+|[a-z]+);/gi, (m, e) => {
    if (e[0] === '#') return String.fromCodePoint(e[1] === 'x' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10));
    return ENTITIES[e] ?? m;
  });
}

/** Visible text of a page: scripts, styles, comments and tags removed. */
export function textOf(html) {
  return decode(
    html
      .replace(/<script\b[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style\b[\s\S]*?<\/style>/gi, ' ')
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<[^>]+>/g, ' '),
  );
}

/** All values of a given attribute across the page, decoded. */
export function attrValues(html, name) {
  const re = new RegExp(`\\b${name}="([^"]*)"`, 'g');
  return [...html.matchAll(re)].map((m) => decode(m[1]));
}

/** Text plus the human-readable attributes, for copy gates. */
export function copyOf(html) {
  return [textOf(html), ...attrValues(html, 'alt'), ...attrValues(html, 'aria-label'), ...attrValues(html, 'title'), ...attrValues(html, 'content')].join('\n');
}
```

- [ ] **Step 11: Write the failing `test/meta.test.mjs`**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { htmlFiles } from './helpers.mjs';

const pages = htmlFiles();

test('dist/ holds at least the landing page', () => {
  assert.ok(pages.some((p) => p.rel === 'index.html'), 'run `npm run build` first');
});

for (const p of pages) {
  test(`${p.rel}: lang, title, description, canonical, og:image`, () => {
    assert.match(p.html, /<html[^>]*\blang="en"/);
    assert.match(p.html, /<title>[^<]+<\/title>/);
    assert.match(p.html, /<meta name="description" content="[^"]+"/);
    assert.match(p.html, /<link rel="canonical" href="https:\/\/vitomy\.app\/[^"]*"/);
    assert.match(p.html, /<meta property="og:image" content="https:\/\/vitomy\.app\/og\.png"/);
  });

  test(`${p.rel}: every <img> has alt, width and height; no inline script`, () => {
    for (const img of p.html.match(/<img\b[^>]*>/g) ?? []) {
      for (const a of ['alt', 'width', 'height']) {
        assert.match(img, new RegExp(`\\b${a}="`), `${img.slice(0, 120)} lacks ${a}`);
      }
    }
    for (const s of p.html.match(/<script\b[^>]*>[\s\S]*?<\/script>/g) ?? []) {
      assert.match(s, /\bsrc="/, `inline script found: ${s.slice(0, 120)}`);
    }
  });
}
```

- [ ] **Step 12: Run the test to see it fail**

Run: `npm test`
Expected: FAIL. `dist/` does not exist yet, so `htmlFiles()` throws `ENOENT` or the first test fails with "run `npm run build` first".

- [ ] **Step 13: Build**

Run: `npm run build`
Expected: `dist/index.html`, `dist/_astro/*.css`, `dist/_astro/*.woff2` (the two fonts), `dist/sitemap-index.xml`, `dist/robots.txt`. No warnings about `site` being unset.

- [ ] **Step 14: Run the test to see it pass**

Run: `npm test`
Expected: PASS, 3 tests (one page).

- [ ] **Step 15: Look at it once**

Run: `npm run preview` in the background, open `http://localhost:4321/` in a browser, confirm the header, the headline in Instrument Sans, the footer with "Privacy", "Support" and the mailto link, and that switching the OS to dark mode flips the page. Stop the preview.

- [ ] **Step 16: Commit**

```bash
cd /Users/dima/supplements
git add site/package.json site/package-lock.json site/astro.config.mjs site/tsconfig.json site/src site/public site/test
git commit -m "feat(site): Astro scaffold, tokens from tokens.dart, base layout and the meta gate"
```

---

### Task 2: The mark, favicon, OG image, and the mark parity test

**Files:**
- Create: `site/scripts/make_og.py`
- Create (generated): `site/src/components/Mark.astro`, `site/public/favicon.svg`, `site/public/og.png`, `site/public/apple-touch-icon.png`
- Modify: `site/src/layouts/Base.astro` (header and footer brand)
- Create: `site/test/mark.test.mjs`

**Interfaces:**
- Consumes: `tool/make_icons.py` (`_GEOMETRY`, `VARIANTS`, `ARTBOARD`, `draw_mark(variant, size, *, ground, scale)`), `assets/fonts/InstrumentSans[wdth,wght].ttf`, `store/icon/3b/appstore-icon-1024.png`.
- Produces: `Mark.astro` with `Props { size?: number; title?: string }`. `python3 scripts/make_og.py` regenerates all four files; `python3 scripts/make_og.py --check` exits 1 if any committed file differs from a fresh generation.

The SVG is generated from the same constants that draw the store icon, so parity is by construction rather than by pixel diff (the spec asked for a raster diff; no SVG rasteriser is installed and `qlmanage` is macOS-only, so the gate is `--check` on the generated text and the numbers it carries).

- [ ] **Step 1: Write the failing `test/mark.test.mjs`**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const site = fileURLToPath(new URL('../', import.meta.url));

test('the mark, favicon and OG assets are fresh generations of make_og.py', () => {
  // exit code 0 means every committed file equals a fresh generation
  execFileSync('python3', ['scripts/make_og.py', '--check'], { cwd: site, stdio: 'pipe' });
});

test('Mark.astro carries the icon geometry', () => {
  const svg = readFileSync(new URL('../src/components/Mark.astro', import.meta.url), 'utf8');
  assert.match(svg, /viewBox="0 0 236 236"/);
  assert.match(svg, /rotate\(-26 118 169\.5\)/);
  assert.match(svg, /rotate\(26 118 169\.5\)/);
  for (const hex of ['#4b5079', '#8d93b8', '#e2b95c', '#b98a2e']) assert.ok(svg.includes(hex), `missing ${hex}`);
});

test('public assets exist', () => {
  for (const f of ['public/favicon.svg', 'public/og.png', 'public/apple-touch-icon.png']) {
    assert.ok(existsSync(new URL(`../${f}`, import.meta.url)), `${f} missing; run npm run assets`);
  }
});
```

- [ ] **Step 2: Run it to see it fail**

Run: `npm test -- test/mark.test.mjs`
Expected: FAIL, `scripts/make_og.py` not found.

- [ ] **Step 3: Write `scripts/make_og.py`**

```python
#!/usr/bin/env python3
"""Generates the website's brand assets from the SAME constants that draw the
store icon (tool/make_icons.py), so the mark on the site and the icon in the
store cannot drift apart.

Writes, relative to site/:
  src/components/Mark.astro   the mark as inline SVG (an Astro component)
  public/favicon.svg          the mark on its cream ground, rounded
  public/og.png               1200x630 Open Graph image
  public/apple-touch-icon.png 180x180 from the 1024 store icon

`--check` regenerates into memory and exits 1 if any committed file differs.
"""
from __future__ import annotations

import importlib.util
import io
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = pathlib.Path(__file__).resolve().parent.parent
ROOT = SITE.parent

spec = importlib.util.spec_from_file_location("make_icons", ROOT / "tool" / "make_icons.py")
make_icons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(make_icons)

G = make_icons._GEOMETRY
ART = make_icons.ARTBOARD
V = make_icons.VARIANTS["3b"]

W, H = G["capsule_w"], G["capsule_h"]
TOP = ART - G["bottom"] - H
LEFT = (ART - W) / 2
PIVOT = (ART / 2, TOP + G["pivot_y_fraction"] * H)
ROT = G["rotation_deg"]


def _num(x: float) -> str:
    s = f"{x:.3f}".rstrip("0").rstrip(".")
    return s if s else "0"


def _capsule_group(angle: float, top: str, bottom: str, clip_id: str) -> str:
    # Split lengthwise into two flat colours, clipped to the capsule, then
    # rotated about the shared pivot. PIL rotates counter-clockwise for a
    # positive angle and make_icons passes -css_angle, so the SVG angle is the
    # css angle unchanged: back capsule -26, front +26.
    return (
        f'<g transform="rotate({_num(angle)} {_num(PIVOT[0])} {_num(PIVOT[1])})" clip-path="url(#{clip_id})">'
        f'<rect x="{_num(LEFT)}" y="{_num(TOP)}" width="{_num(W)}" height="{_num(H / 2)}" fill="{top}"/>'
        f'<rect x="{_num(LEFT)}" y="{_num(TOP + H / 2)}" width="{_num(W)}" height="{_num(H / 2)}" fill="{bottom}"/>'
        f"</g>"
    )


def mark_body(clip_id: str) -> str:
    clip = (
        f'<clipPath id="{clip_id}"><rect x="{_num(LEFT)}" y="{_num(TOP)}" '
        f'width="{_num(W)}" height="{_num(H)}" rx="{_num(W / 2)}"/></clipPath>'
    )
    back = _capsule_group(-ROT, *V["back_capsule"], clip_id)
    front = _capsule_group(+ROT, *V["front_capsule"], clip_id)
    return f"<defs>{clip}</defs>{back}{front}"


def mark_astro() -> str:
    return (
        "---\n"
        "// GENERATED by site/scripts/make_og.py from tool/make_icons.py. Do not edit;\n"
        "// run `npm run assets`. The geometry and colours are the store icon's own.\n"
        "interface Props { size?: number; title?: string }\n"
        "const { size = 28, title } = Astro.props;\n"
        "const clipId = `vm-cap-${Math.random().toString(36).slice(2, 8)}`;\n"
        "---\n"
        f'<svg width={{size}} height={{size}} viewBox="0 0 {_num(ART)} {_num(ART)}" '
        'xmlns="http://www.w3.org/2000/svg" role={title ? "img" : undefined} '
        'aria-hidden={title ? undefined : "true"} focusable="false">\n'
        "  {title && <title>{title}</title>}\n"
        "  <Fragment set:html={body} />\n"
        "</svg>\n"
    ).replace("const clipId", f"const bodyFor = (id: string) => `{mark_body('${id}')}`;\nconst clipId").replace(
        "---\n<svg", "const body = bodyFor(clipId);\n---\n<svg", 1
    )


def favicon_svg() -> str:
    r = ART * 0.22
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {_num(ART)} {_num(ART)}">'
        f'<rect width="{_num(ART)}" height="{_num(ART)}" rx="{_num(r)}" fill="{V["background"]}"/>'
        f'{mark_body("cap")}</svg>\n'
    )


def og_png() -> bytes:
    img = Image.new("RGB", (1200, 630), make_icons._rgb("#F7F6F3"))  # BqColors.paper
    mark = make_icons.draw_mark("3b", 360, ground=False)
    img.paste(mark, (96, 135), mark)
    font_path = str(ROOT / "assets" / "fonts" / "InstrumentSans[wdth,wght].ttf")
    name = ImageFont.truetype(font_path, 96)
    name.set_variation_by_axes([100, 600])
    line = ImageFont.truetype(font_path, 44)
    line.set_variation_by_axes([100, 500])
    d = ImageDraw.Draw(img)
    d.text((520, 200), "VitoMy", font=name, fill=make_icons._rgb("#17171B"))  # BqColors.ink
    d.text((520, 322), "Plan what you take.", font=line, fill=make_icons._rgb("#5C5C66"))
    d.text((520, 378), "See it laid out.", font=line, fill=make_icons._rgb("#5C5C66"))
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def touch_icon_png() -> bytes:
    src = Image.open(ROOT / "store" / "icon" / "3b" / "appstore-icon-1024.png").convert("RGB")
    buf = io.BytesIO()
    src.resize((180, 180), Image.LANCZOS).save(buf, "PNG", optimize=True)
    return buf.getvalue()


OUTPUTS = {
    "src/components/Mark.astro": lambda: mark_astro().encode(),
    "public/favicon.svg": lambda: favicon_svg().encode(),
    "public/og.png": og_png,
    "public/apple-touch-icon.png": touch_icon_png,
}


def main(argv: list[str]) -> int:
    check = "--check" in argv
    stale: list[str] = []
    for rel, build in OUTPUTS.items():
        path = SITE / rel
        data = build()
        if check:
            if not path.exists() or path.read_bytes() != data:
                stale.append(rel)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            print(f"wrote {rel}")
    if stale:
        print("stale, run `npm run assets`: " + ", ".join(stale), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

The `mark_astro()` string surgery is ugly; the point is that the component's frontmatter builds the SVG body with a per-instance clip id so two marks on one page do not share an `id`. If the `.replace` chain is hard to follow, write the frontmatter as one explicit f-string instead; the required output is:

```astro
---
// GENERATED by site/scripts/make_og.py from tool/make_icons.py. Do not edit;
// run `npm run assets`. The geometry and colours are the store icon's own.
interface Props { size?: number; title?: string }
const bodyFor = (id: string) => `<defs><clipPath id="${id}">...</clipPath></defs><g transform="rotate(-26 118 169.5)" clip-path="url(#${id})">...</g><g transform="rotate(26 118 169.5)" clip-path="url(#${id})">...</g>`;
const { size = 28, title } = Astro.props;
const clipId = `vm-cap-${Math.random().toString(36).slice(2, 8)}`;
const body = bodyFor(clipId);
---
<svg width={size} height={size} viewBox="0 0 236 236" xmlns="http://www.w3.org/2000/svg" role={title ? "img" : undefined} aria-hidden={title ? undefined : "true"} focusable="false">
  {title && <title>{title}</title>}
  <Fragment set:html={body} />
</svg>
```

Geometry check, so the numbers in the test are not magic: `TOP = 236 - 44 - 166 = 26`, `LEFT = 95.5`, `PIVOT = (118, 26 + 166 * (166 - 22.5) / 166) = (118, 169.5)`, `rx = 22.5`.

- [ ] **Step 4: Generate and look**

Run: `npm run assets`
Expected: four `wrote ...` lines. Open `public/og.png` and `public/favicon.svg` (the Read tool renders PNG; for the SVG, open it in the browser) and compare the V against `store/icon/3b/appstore-icon-1024.png`: same lean, the two bottom caps coincide in one disc, navy behind ochre. If the front and back capsules are swapped or the V leans the wrong way, the rotation sign in `_capsule_group` is inverted; fix it there, not in the test.

Note that Pillow is fine with `set_variation_by_axes` on the variable font; if it raises, the wdth axis default is 100 and wght 600 can be selected with `set_variation_by_name('SemiBold')` instead.

- [ ] **Step 5: Use the mark in the layout**

In `Base.astro`, import it and replace both brand blocks:

```astro
import Mark from '../components/Mark.astro';
...
<a class="site-header__brand" href="/"><Mark size={28} /> VitoMy</a>
...
<div class="site-header__brand"><Mark size={24} /> VitoMy</div>
```

- [ ] **Step 6: Build and run the tests**

Run: `npm run build && npm test`
Expected: PASS. `mark.test.mjs` runs `--check` and finds every file fresh.

- [ ] **Step 7: Prove `--check` catches drift**

Run: `sed -i '' 's/#4b5079/#4b507a/' src/components/Mark.astro && python3 scripts/make_og.py --check; echo "exit $?"; git checkout site/src/components/Mark.astro`
Expected: `stale, run npm run assets: src/components/Mark.astro` and `exit 1`, then the file restored.

- [ ] **Step 8: Commit**

```bash
cd /Users/dima/supplements
git add site/scripts/make_og.py site/src/components/Mark.astro site/public/favicon.svg site/public/og.png site/public/apple-touch-icon.png site/src/layouts/Base.astro site/test/mark.test.mjs
git commit -m "feat(site): the mark as SVG, favicon, OG image and touch icon, generated from make_icons.py"
```

---

### Task 3: The copy gates: placeholders, dashes, vocabulary, external resources

**Files:**
- Create: `site/test/placeholders.test.mjs`, `site/test/dashes.test.mjs`, `site/test/vocabulary.test.mjs`, `site/test/external.test.mjs`

**Interfaces:**
- Consumes: `helpers.mjs` (`htmlFiles`, `cssFiles`, `copyOf`, `attrValues`), `test_release/legal_copy_safety_test.dart` (`legalForbiddenStems`, `legalAllowlist`), `src/config.ts` (`stores`).

Each gate is written to fail on a deliberately broken page first, so its wiring is proven, then the page is restored.

- [ ] **Step 1: Write `test/placeholders.test.mjs`**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { htmlFiles, copyOf } from './helpers.mjs';

for (const p of htmlFiles()) {
  test(`${p.rel}: no [PLACEHOLDER] reached the page`, () => {
    const hit = copyOf(p.html).match(/\[[A-Z_]+\]/);
    assert.equal(hit, null, hit && `found ${hit[0]}`);
  });
}
```

- [ ] **Step 2: Write `test/dashes.test.mjs`**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { htmlFiles, copyOf } from './helpers.mjs';

for (const p of htmlFiles()) {
  test(`${p.rel}: no em dash or en dash in visible copy`, () => {
    const text = copyOf(p.html);
    const i = text.search(/[–—]/);
    assert.equal(i, -1, i >= 0 && `dash near: "${text.slice(Math.max(0, i - 40), i + 40)}"`);
  });
}
```

- [ ] **Step 3: Write `test/vocabulary.test.mjs`**

Reads the stems from the Dart release gate so the two lists cannot drift.

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { htmlFiles, copyOf } from './helpers.mjs';

const dart = readFileSync(new URL('../../test_release/legal_copy_safety_test.dart', import.meta.url), 'utf8');

function dartList(name) {
  const block = dart.match(new RegExp(`const ${name} = <String>\\[([\\s\\S]*?)\\];`));
  assert.ok(block, `${name} not found in legal_copy_safety_test.dart`);
  const body = block[1].replace(/\/\/[^\n]*/g, '');
  return [...body.matchAll(/(r?)'((?:[^'\\]|\\.)*)'/g)].map(([, raw, s]) => ({ raw: raw === 'r', s }));
}

const stems = dartList('legalForbiddenStems').map(({ raw, s }) =>
  new RegExp(raw ? s : s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'),
);
const allow = dartList('legalAllowlist').map(({ s }) => s);
const extra = [/\bdonat(e|es|ed|ing|ion|ions)\b/i]; // Apple 3.2.2(iv)

test('the stem list was read from the Dart gate', () => {
  assert.ok(stems.length >= 20, `only ${stems.length} stems parsed`);
  assert.ok(allow.includes('Apple Health'));
});

for (const p of htmlFiles()) {
  test(`${p.rel}: no medical or outcome vocabulary, no donation wording`, () => {
    let text = copyOf(p.html);
    for (const phrase of allow) text = text.split(phrase).join(' ');
    const hits = [];
    for (const re of [...stems, ...extra]) {
      const m = text.match(re);
      if (m) hits.push(`${re.source} near "${text.slice(Math.max(0, m.index - 30), m.index + 30).replace(/\s+/g, ' ')}"`);
    }
    assert.deepEqual(hits, []);
  });
}
```

- [ ] **Step 4: Write `test/external.test.mjs`**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { htmlFiles, cssFiles, attrValues } from './helpers.mjs';
import { stores } from '../src/config.ts';

const allowedPrefixes = ['/', '#', 'mailto:support@vitomy.app', 'https://vitomy.app/'];
for (const s of Object.values(stores)) if (s.url) allowedPrefixes.push(s.url);

function allowed(url) {
  return allowedPrefixes.some((p) => url === p || url.startsWith(p));
}

for (const p of htmlFiles()) {
  test(`${p.rel}: every src, href and srcset points at the site`, () => {
    const urls = [
      ...attrValues(p.html, 'src'),
      ...attrValues(p.html, 'href'),
      ...attrValues(p.html, 'srcset').flatMap((v) => v.split(',').map((c) => c.trim().split(/\s+/)[0])),
    ];
    const bad = urls.filter((u) => u && !allowed(u));
    assert.deepEqual(bad, []);
  });
}

for (const c of cssFiles()) {
  test(`${c.rel}: no external url() or @import`, () => {
    const urls = [...c.css.matchAll(/url\(\s*["']?([^"')]+)["']?\s*\)/g)].map((m) => m[1]);
    const bad = urls.filter((u) => !(u.startsWith('/') || u.startsWith('data:')));
    assert.deepEqual(bad, []);
    assert.doesNotMatch(c.css, /@import\s+(url\()?["']?https?:/);
  });
}
```

Node 24 strips the types from `../src/config.ts` on import; if the runtime refuses it, run tests with `node --experimental-strip-types --test test/` and put that in `package.json`.

- [ ] **Step 5: Prove each gate bites**

Temporarily change the `<h1>` in `src/pages/index.astro` to `Plan your health [SOON] — safely` (one line carrying a placeholder, an em dash and two stems), add `<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">` to the head of `Base.astro`, then:

Run: `npm run build && npm test`
Expected: FAIL in `placeholders` (`[SOON]`), `dashes`, `vocabulary` (`health`, `safe`), and `external` (the Google Fonts URL). `meta` and `mark` still pass.

Restore both files (`git checkout site/src/pages/index.astro site/src/layouts/Base.astro`).

- [ ] **Step 6: Build and run to see green**

Run: `npm run build && npm test`
Expected: PASS, every gate.

- [ ] **Step 7: Commit**

```bash
cd /Users/dima/supplements
git add site/test/placeholders.test.mjs site/test/dashes.test.mjs site/test/vocabulary.test.mjs site/test/external.test.mjs
git commit -m "test(site): gates for placeholders, dashes, medical vocabulary and external resources"
```

---

### Task 4: Legal pages from `docs/legal`, the placeholder integration, and the first filled date

**Files:**
- Create: `site/src/content.config.ts`, `site/src/layouts/Legal.astro`, `site/src/pages/[legal].astro`
- Create: `site/integrations/legal-gate.mjs`
- Modify: `site/astro.config.mjs` (register the integration)
- Modify: `docs/legal/privacy.md:3` (`[LAST_UPDATED]` becomes the date)
- Create: `site/test/legal.test.mjs`

**Interfaces:**
- Consumes: `legalPages` from `config.ts`; `Base.astro`.
- Produces: `assertNoPlaceholders(files: {name, path}[])` exported from `legal-gate.mjs`; the default export is the Astro integration.

- [ ] **Step 1: Write the failing `test/legal.test.mjs`**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { htmlFiles, textOf, attrValues } from './helpers.mjs';
import { legalPages } from '../src/config.ts';
import { assertNoPlaceholders } from '../integrations/legal-gate.mjs';

const legalDir = fileURLToPath(new URL('../../docs/legal/', import.meta.url));
const candidates = ['privacy', 'terms'];
const pages = htmlFiles();

test('assertNoPlaceholders throws on a bracketed token with file and line', () => {
  const dir = mkdtempSync(join(tmpdir(), 'legal-'));
  const bad = join(dir, 'bad.md');
  writeFileSync(bad, '# T\n\nLast updated: [LAST_UPDATED]\n');
  assert.throws(() => assertNoPlaceholders([{ name: 'bad', path: bad }]), /bad\.md:3: placeholder \[LAST_UPDATED\]/);
});

test('every published document is free of placeholders', () => {
  assertNoPlaceholders(legalPages.map((name) => ({ name, path: join(legalDir, `${name}.md`) })));
});

for (const name of candidates) {
  const listed = legalPages.includes(name);
  test(`${name}: emitted only when listed (${listed})`, () => {
    assert.equal(existsSync(join(fileURLToPath(new URL('../dist/', import.meta.url)), `${name}.html`)), listed);
  });
  if (!listed) {
    test(`${name}: linked from no page while unlisted`, () => {
      for (const p of pages) {
        assert.ok(!attrValues(p.html, 'href').includes(`/${name}`), `${p.rel} links to /${name}`);
      }
    });
  } else {
    test(`${name}: every ## of the source is an h2 on the page`, () => {
      const md = readFileSync(join(legalDir, `${name}.md`), 'utf8');
      const heads = [...md.matchAll(/^## (.+)$/gm)].map((m) => m[1].trim());
      const page = pages.find((p) => p.rel === `${name}.html`);
      assert.ok(page, `${name}.html missing`);
      const h2s = [...page.html.matchAll(/<h2[^>]*>([\s\S]*?)<\/h2>/g)].map((m) => textOf(m[1]).trim());
      for (const h of heads) assert.ok(h2s.includes(h), `heading "${h}" not rendered`);
      assert.match(textOf(page.html), /Last updated: \d{1,2} \w+ \d{4}/);
    });
  }
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `npm test -- test/legal.test.mjs`
Expected: FAIL, cannot find `../integrations/legal-gate.mjs`.

- [ ] **Step 3: Write `integrations/legal-gate.mjs`**

```js
// Fails the build when a PUBLISHED legal document still carries a
// [PLACEHOLDER]. This is the interview decision of 2026-09-11: privacy and
// support ship first; terms ships when [NOMINAL_SUM] is filled and 'terms' is
// added to legalPages in src/config.ts. Unlisted documents are neither emitted
// nor linked, so nothing half-finished can reach the public page.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { legalPages } from '../src/config.ts';

const PLACEHOLDER = /\[[A-Z_]+\]/;

export function assertNoPlaceholders(files) {
  for (const { name, path } of files) {
    const lines = readFileSync(path, 'utf8').split('\n');
    lines.forEach((line, i) => {
      const m = PLACEHOLDER.exec(line);
      if (m) {
        throw new Error(
          `${name}.md:${i + 1}: placeholder ${m[0]} would be published. ` +
            `Fill it in docs/legal/${name}.md or remove "${name}" from legalPages in site/src/config.ts.`,
        );
      }
    });
  }
}

export default function legalGate() {
  return {
    name: 'vitomy-legal-gate',
    hooks: {
      'astro:build:start': () => {
        const dir = fileURLToPath(new URL('../../docs/legal/', import.meta.url));
        assertNoPlaceholders(legalPages.map((name) => ({ name, path: `${dir}${name}.md` })));
      },
    },
  };
}
```

Register it in `astro.config.mjs`:

```js
import legalGate from './integrations/legal-gate.mjs';
...
integrations: [sitemap(), legalGate()],
```

- [ ] **Step 4: Write `src/content.config.ts`**

```ts
import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';

// The two publishable documents, read from the app repository. The research
// notes in the same directory are never a candidate.
export const collections = {
  legal: defineCollection({
    loader: glob({ pattern: ['privacy.md', 'terms.md'], base: '../docs/legal' }),
  }),
};
```

- [ ] **Step 5: Write `src/layouts/Legal.astro`**

```astro
---
import Base from './Base.astro';
interface Props { title: string; description: string }
const { title, description } = Astro.props;
---
<Base title={`${title} | VitoMy`} description={description}>
  <article class="legal wrap"><slot /></article>
</Base>

<style>
  .legal { max-width: 68ch; padding-block: 3rem 2rem; }
  .legal :global(h1) { font-size: clamp(2rem, 4vw, 3rem); margin-bottom: 0.5rem; }
  .legal :global(h1 + p) { color: var(--ink-2); }
  .legal :global(h2) { font-size: 1.5rem; margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid var(--hairline); }
  .legal :global(h3) { font-size: 1.125rem; margin-top: 2rem; }
  .legal :global(p), .legal :global(li) { margin-top: 1rem; max-width: none; }
  .legal :global(ul), .legal :global(ol) { padding-inline-start: 1.25rem; }
  .legal :global(a) { color: var(--accent); }
</style>
```

- [ ] **Step 6: Write `src/pages/[legal].astro`**

```astro
---
import { getCollection, render } from 'astro:content';
import Legal from '../layouts/Legal.astro';
import { legalPages } from '../config';

export async function getStaticPaths() {
  const entries = await getCollection('legal', (e) => legalPages.includes(e.id));
  return entries.map((entry) => ({ params: { legal: entry.id }, props: { entry } }));
}

const { entry } = Astro.props;
const { Content, headings } = await render(entry);
const title = headings.find((h) => h.depth === 1)?.text ?? entry.id;
const description =
  entry.id === 'privacy' ? 'The privacy policy for the VitoMy app.' : 'The terms of use for the VitoMy app.';
---
<Legal title={title} description={description}><Content /></Legal>
```

- [ ] **Step 7: Build, and watch the gate refuse the date placeholder**

Run: `npm run build`
Expected: the build fails with `privacy.md:3: placeholder [LAST_UPDATED] would be published...`. That is the gate working. Do not weaken it.

- [ ] **Step 8: Fill the date in the app repository**

The document's text last changed on 2026-09-11 (commits `d7e82fc` and `42a0d80`), so that is the honest date, independent of the deploy day. Edit `docs/legal/privacy.md` line 3:

```
Last updated: 11 September 2026
```

Leave `terms.md` untouched; it is unlisted.

- [ ] **Step 9: Prove the app's own legal gate still passes**

Run (from the repo root): `flutter test test_release/legal_copy_safety_test.dart`
Expected: PASS. `knownPlaceholders` permits a filled value; the vocabulary sweep is unchanged.

- [ ] **Step 10: Build and run all gates**

Run: `npm run build && npm test`
Expected: PASS. `dist/privacy.html` exists, `dist/terms.html` does not, the footer of every page links Privacy but not Terms, every `##` of privacy.md is an `h2`.

- [ ] **Step 11: Look at `/privacy` once**

`npm run preview`, open `http://localhost:4321/privacy`. The `h1`, the "Last updated" line in the muted colour, hairlines above each `h2`, a 68ch column, links in the accent. Stop the preview.

- [ ] **Step 12: Commit**

```bash
cd /Users/dima/supplements
git add site/src/content.config.ts site/src/layouts/Legal.astro "site/src/pages/[legal].astro" site/integrations/legal-gate.mjs site/astro.config.mjs site/test/legal.test.mjs docs/legal/privacy.md
git commit -m "feat(site): privacy and terms rendered from docs/legal behind a placeholder gate; privacy dated"
```

---

### Task 5: Store buttons and the `stores` gate

**Files:**
- Create: `site/src/components/StoreButton.astro`
- Modify: `site/src/pages/index.astro` (place two buttons under the headline; Task 6 restructures the hero around them)
- Create: `site/test/stores.test.mjs`

**Interfaces:**
- Consumes: `stores`, `StoreId` from `config.ts`; Phosphor SVGs via `?raw`.
- Produces: `StoreButton.astro` with `Props { store: StoreId }`.

- [ ] **Step 1: Write the failing `test/stores.test.mjs`**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { htmlFiles, attrValues } from './helpers.mjs';
import { stores } from '../src/config.ts';

const landing = htmlFiles().find((p) => p.rel === 'index.html');

for (const [id, s] of Object.entries(stores)) {
  test(`${id}: ${s.url ? 'live badge link' : 'inert "Coming soon" button'}`, () => {
    assert.ok(landing, 'index.html missing');
    const hrefs = attrValues(landing.html, 'href');
    if (s.url) {
      assert.ok(hrefs.includes(s.url), `no link to ${s.url}`);
      assert.ok(attrValues(landing.html, 'src').includes(s.badge), `official badge ${s.badge} not used`);
    } else {
      assert.ok(!hrefs.some((h) => /apps\.apple\.com|play\.google\.com/.test(h)), 'a store link leaked while the store is off');
      const label = `${s.label}, coming soon`;
      const n = attrValues(landing.html, 'aria-label').filter((v) => v === label).length;
      assert.ok(n >= 2, `expected the "${label}" button in the hero and the download band, found ${n}`);
    }
  });
}

test('the label "Coming soon" is the only wording used for an inert store button', () => {
  const soon = (landing.html.match(/Coming soon/g) ?? []).length;
  const off = Object.values(stores).filter((s) => !s.url).length;
  assert.equal(soon, off * 2, 'one "Coming soon" per inert button, hero and band');
});
```

- [ ] **Step 2: Run it to see it fail**

Run: `npm run build && npm test -- test/stores.test.mjs`
Expected: FAIL, no `aria-label="App Store, coming soon"` on the landing.

- [ ] **Step 3: Write `src/components/StoreButton.astro`**

```astro
---
import { existsSync } from 'node:fs';
import { stores, type StoreId } from '../config';
import appleLogo from '@phosphor-icons/core/assets/regular/apple-logo.svg?raw';
import playLogo from '@phosphor-icons/core/assets/regular/google-play-logo.svg?raw';

interface Props { store: StoreId }
const { store } = Astro.props;
const { url, label, badge } = stores[store];
const glyph = store === 'apple' ? appleLogo : playLogo;

// Apple and Google forbid altering their badges, so before launch the button
// is our own; on launch day the OFFICIAL badge file must be present.
if (url && !existsSync(new URL(`../../public${badge}`, import.meta.url))) {
  throw new Error(`${store}: a store URL is set but public${badge} is missing. Download the official badge first.`);
}
---
{url ? (
  <a class="store store--live" href={url} rel="noopener">
    <img src={badge} alt={`Get VitoMy on ${label}`} width="180" height="60" />
  </a>
) : (
  <span class="pill store store--soon" role="img" aria-label={`${label}, coming soon`}>
    <span class="store__glyph" set:html={glyph} />
    <span class="store__text">
      <span class="store__name">{label}</span>
      <span class="store__soon">Coming soon</span>
    </span>
  </span>
)}

<style>
  .store--live img { width: 180px; height: 60px; }
  .store--soon {
    background: color-mix(in oklab, var(--accent) 14%, transparent);
    color: var(--accent);
    border: 1px solid color-mix(in oklab, var(--accent) 30%, transparent);
    cursor: default;
    user-select: none;
    padding-block: 0.4rem;
  }
  .store__glyph { display: inline-flex; }
  .store__glyph :global(svg) { width: 24px; height: 24px; fill: currentColor; }
  .store__text { display: flex; flex-direction: column; line-height: 1.15; }
  .store__name { font-weight: 600; }
  .store__soon { font-size: 0.75rem; font-weight: 500; opacity: 0.85; }
</style>
```

The inert button is a tinted pill rather than the spec's 55% opacity version: same reading (clearly not a link), better contrast for the label. Record this in the task report.

- [ ] **Step 4: Place two buttons on the landing**

In `src/pages/index.astro`, under the `<h1>`:

```astro
---
import Base from '../layouts/Base.astro';
import StoreButton from '../components/StoreButton.astro';
---
<Base title="VitoMy: Supplement Planner" description="Plan your supplement cycles, get reminders, mark what you take. All on-device.">
  <section class="wrap" style="padding-block: 4rem">
    <h1>Plan what you take. See it laid out.</h1>
    <div class="ctas"><StoreButton store="apple" /><StoreButton store="google" /></div>
  </section>
  <section class="wrap" style="padding-block: 4rem">
    <h2>Coming to iPhone and Android.</h2>
    <div class="ctas"><StoreButton store="apple" /><StoreButton store="google" /></div>
  </section>
</Base>
<style>
  .ctas { display: flex; flex-wrap: wrap; gap: 0.75rem; margin-top: 1.5rem; }
</style>
```

- [ ] **Step 5: Build and test**

Run: `npm run build && npm test`
Expected: PASS. `stores.test.mjs` finds each label twice and four "Coming soon".

- [ ] **Step 6: Prove the badge guard**

Temporarily set `apple.url` in `config.ts` to `'https://apps.apple.com/app/id0'`, run `npm run build`.
Expected: build fails with `apple: a store URL is set but public/badges/app-store.svg is missing`. Restore `config.ts` (`git checkout site/src/config.ts`).

- [ ] **Step 7: Commit**

```bash
cd /Users/dima/supplements
git add site/src/components/StoreButton.astro site/src/pages/index.astro site/test/stores.test.mjs
git commit -m "feat(site): store buttons, inert until launch, with the official-badge guard"
```

---

### Task 6: The hero, the phone frame, and the screenshot pipeline

**Files:**
- Create: `site/scripts/sync-screens.mjs`
- Modify: `site/package.json` (add `"prebuild": "node scripts/sync-screens.mjs"` and `"predev"` the same)
- Modify: `/Users/dima/supplements/.gitignore` (add `/site/src/assets/screens/`)
- Create: `site/src/components/PhoneFrame.astro`
- Modify: `site/src/pages/index.astro` (the hero)

**Interfaces:**
- Consumes: `store/screenshots/ios-6.9/02-today.png`, `03-cycles.png`, `04-year.png` (1320x2868 RGBA).
- Produces: `src/assets/screens/{today,cycles,year}.png` (build artefacts, gitignored); `PhoneFrame.astro` with `Props { src: ImageMetadata; alt: string; priority?: boolean; class?: string }`, whose frame chrome is a border so stacked frames stay transparent inside (Task 7 relies on this).

- [ ] **Step 1: Write `scripts/sync-screens.mjs`**

```js
// Copies the three landing screenshots from the store set into src/assets so
// Astro's image pipeline can import them. The store set is the source; this
// directory is gitignored and rebuilt on every build.
import { copyFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const from = fileURLToPath(new URL('../../store/screenshots/ios-6.9/', import.meta.url));
const to = fileURLToPath(new URL('../src/assets/screens/', import.meta.url));
mkdirSync(to, { recursive: true });
for (const [src, dst] of [['02-today.png', 'today.png'], ['03-cycles.png', 'cycles.png'], ['04-year.png', 'year.png']]) {
  copyFileSync(from + src, to + dst);
}
```

Add to `package.json` scripts: `"prebuild": "node scripts/sync-screens.mjs"`, `"predev": "node scripts/sync-screens.mjs"`. Append to the root `.gitignore` under the site block: `/site/src/assets/screens/`.

- [ ] **Step 2: Write `src/components/PhoneFrame.astro`**

```astro
---
import { Picture } from 'astro:assets';
import type { ImageMetadata } from 'astro';

interface Props { src: ImageMetadata; alt: string; priority?: boolean; class?: string }
const { src, alt, priority = false, class: cls } = Astro.props;
---
<figure class:list={['phone', cls]}>
  <Picture
    src={src}
    alt={alt}
    widths={[360, 540, 720]}
    sizes="(min-width: 1024px) 360px, 72vw"
    formats={['avif', 'webp']}
    loading={priority ? 'eager' : 'lazy'}
    fetchpriority={priority ? 'high' : 'auto'}
    decoding="async"
  />
</figure>

<style>
  /* The frame is a BORDER, not a background, so frames stacked on top of each
     other (the scene in Task 7) stay transparent inside and only the screens
     cross-fade. */
  .phone {
    margin: 0;
    width: min(100%, 360px);
    border: 10px solid var(--ink);
    border-radius: var(--radius-panel);
    background: transparent;
    box-shadow: var(--shadow);
  }
  .phone :global(img) { width: 100%; height: auto; border-radius: var(--radius-screen); }
  @media (prefers-color-scheme: dark) {
    .phone { border-color: #2A2A31; }
  }
</style>
```

The dark border colour is one hex outside `tokens.css`; move it there as `--phone-border` (light `#17171B`, dark `#2A2A31`) and use `var(--phone-border)` instead. Do that rather than leaving the literal here.

- [ ] **Step 3: Write the hero into `src/pages/index.astro`**

```astro
---
import Base from '../layouts/Base.astro';
import StoreButton from '../components/StoreButton.astro';
import PhoneFrame from '../components/PhoneFrame.astro';
import today from '../assets/screens/today.png';
---
<Base title="VitoMy: Supplement Planner" description="Plan your supplement cycles, get reminders, mark what you take. All on-device.">
  <section class="hero wrap">
    <div class="hero__copy">
      <h1>Plan what you take. See&nbsp;it laid&nbsp;out.</h1>
      <p class="hero__sub">Set on and off weeks once. VitoMy shows what is due today and how the months line up.</p>
      <div class="ctas"><StoreButton store="apple" /><StoreButton store="google" /></div>
    </div>
    <PhoneFrame class="hero__phone" src={today} alt="The Today screen: the doses due today in one list, each with its time, ready to mark taken" priority />
  </section>

  <section class="band">
    <div class="wrap">
      <h2>Coming to iPhone and Android.</h2>
      <p class="muted">No account and no server. What you enter stays on your phone.</p>
      <div class="ctas"><StoreButton store="apple" /><StoreButton store="google" /></div>
    </div>
  </section>
</Base>

<style>
  .hero {
    min-height: calc(100dvh - var(--header-h));
    display: grid; gap: 3rem; align-items: center;
    padding-block: min(6rem, 10vh) 4rem;
  }
  .hero__sub { margin-top: 1.25rem; font-size: 1.125rem; color: var(--ink-2); max-width: 34ch; }
  .ctas { display: flex; flex-wrap: wrap; gap: 0.75rem; margin-top: 2rem; }
  .hero__phone { justify-self: center; }
  @media (min-width: 1024px) {
    .hero { grid-template-columns: 7fr 5fr; }
    .hero__phone { justify-self: end; }
  }
  @media (max-width: 640px) {
    .ctas :global(.store) { width: 100%; justify-content: center; }
  }

  .band { background: var(--canvas); padding-block: 5rem; margin-top: 4rem; }
  .band .muted { margin-top: 1rem; }

  @media (prefers-reduced-motion: no-preference) {
    .hero__copy > *, .hero__phone { animation: rise 0.6s cubic-bezier(0.16, 1, 0.3, 1) both; }
    .hero__copy > :nth-child(2) { animation-delay: 0.08s; }
    .hero__copy > :nth-child(3) { animation-delay: 0.16s; }
    .hero__phone { animation-delay: 0.2s; }
  }
  @keyframes rise { from { opacity: 0; transform: translateY(16px); } }
</style>
```

- [ ] **Step 4: Build and test**

Run: `npm run build && npm test`
Expected: PASS. `dist/_astro/` contains `today.*.avif` and `.webp` at three widths plus a PNG fallback; `index.html` has a `<picture>` with `<source type="image/avif">`, `<source type="image/webp">` and an `<img>` carrying `alt`, `width`, `height`, `loading="eager"`, `fetchpriority="high"`. If Astro emits the Picture without `width`/`height`, pass `width={1320} height={2868}` explicitly on the `Picture`.

- [ ] **Step 5: Look at it at three widths**

`npm run preview`, open `http://localhost:4321/` at 1440x900: headline two lines, subtext, both buttons visible without scrolling, phone on the right with the shadow. At 390x844 (device toolbar): single column, phone under the buttons, buttons full width. Confirm the load cascade runs once, and with "Emulate CSS prefers-reduced-motion: reduce" in devtools it does not. Stop the preview.

- [ ] **Step 6: Commit**

```bash
cd /Users/dima/supplements
git add .gitignore site/package.json site/scripts/sync-screens.mjs site/src/components/PhoneFrame.astro site/src/styles/tokens.css site/src/pages/index.astro
git commit -m "feat(site): the hero with the real Today screenshot, and the screenshot pipeline"
```

---

### Task 7: The pinned scene

**Files:**
- Create: `site/src/components/Scene.astro`, `site/src/components/Scene.ts`
- Modify: `site/src/pages/index.astro` (insert `<Scene />` between the hero and the band)
- Create: `site/test/scene.test.mjs`

**Interfaces:**
- Consumes: `PhoneFrame.astro` (border-only frame), the three screenshots.
- Produces: `mountScene(root: HTMLElement): void` in `Scene.ts`.

- [ ] **Step 1: Write the failing `test/scene.test.mjs`**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { htmlFiles, distFiles, DIST } from './helpers.mjs';

const landing = htmlFiles().find((p) => p.rel === 'index.html');

test('the scene has its three steps in order', () => {
  const h2s = [...landing.html.matchAll(/<h2[^>]*>([\s\S]*?)<\/h2>/g)].map((m) => m[1].replace(/<[^>]+>/g, '').trim());
  const idx = ['Everything due today, in one list.', 'Eight weeks on, four off. Drawn, not remembered.', 'Twelve months at a glance.'].map((h) => h2s.indexOf(h));
  assert.deepEqual(idx.map((i) => i >= 0), [true, true, true], `h2s: ${h2s.join(' | ')}`);
  assert.ok(idx[0] < idx[1] && idx[1] < idx[2], 'steps out of order');
});

test('GSAP is a separate chunk, not in the page script', () => {
  const srcs = [...landing.html.matchAll(/<script[^>]*\bsrc="([^"]+)"/g)].map((m) => m[1]);
  assert.ok(srcs.length >= 1, 'the landing has no bundled script');
  for (const s of srcs) {
    const js = readFileSync(`${DIST}${s.replace(/^\//, '')}`, 'utf8');
    assert.ok(!js.includes('ScrollTrigger'), `${s} bundles ScrollTrigger eagerly`);
    assert.ok(!js.includes('addEventListener("scroll"'), `${s} listens to scroll`);
  }
  const chunks = distFiles().filter((f) => f.rel.startsWith('_astro/') && f.rel.endsWith('.js'));
  assert.ok(chunks.some((f) => readFileSync(f.path, 'utf8').includes('ScrollTrigger')), 'no chunk carries ScrollTrigger');
});
```

- [ ] **Step 2: Run it to see it fail**

Run: `npm run build && npm test -- test/scene.test.mjs`
Expected: FAIL, the step headlines are missing.

- [ ] **Step 3: Write `src/components/Scene.ts`**

```ts
// The one GSAP island. Imported dynamically by Scene.astro only when the
// section is near the viewport, at >= 1024px, and motion is not reduced.
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

export function mountScene(root: HTMLElement): void {
  gsap.registerPlugin(ScrollTrigger);
  const pin = root.querySelector<HTMLElement>('.scene__pin');
  const steps = Array.from(root.querySelectorAll<HTMLElement>('.scene__step'));
  const screens = Array.from(root.querySelectorAll<HTMLElement>('.scene__shot picture, .scene__shot img'))
    .filter((el, _, all) => el.tagName === 'PICTURE' || !all.some((o) => o.tagName === 'PICTURE' && o.contains(el)));
  if (!pin || steps.length < 2 || screens.length !== steps.length) return;

  root.classList.add('scene--pinned');
  gsap.set(steps.slice(1), { autoAlpha: 0, y: 24 });
  gsap.set(screens.slice(1), { autoAlpha: 0 });

  const tl = gsap.timeline({
    defaults: { ease: 'none' },
    scrollTrigger: {
      trigger: root,
      start: 'top top',
      end: () => `+=${(steps.length - 1) * window.innerHeight}`,
      pin,
      scrub: 0.6,
      invalidateOnRefresh: true,
    },
  });

  for (let i = 1; i < steps.length; i++) {
    tl.to(steps[i - 1], { autoAlpha: 0, y: -24, duration: 0.45 }, i - 1 + 0.35)
      .to(screens[i - 1], { autoAlpha: 0, duration: 0.45 }, '<')
      .to(steps[i], { autoAlpha: 1, y: 0, duration: 0.45 }, '<0.15')
      .to(screens[i], { autoAlpha: 1, duration: 0.45 }, '<');
  }
}
```

The `screens` selection prefers the `<picture>` element so the whole responsive image fades, falling back to bare `<img>` if `Picture` ever renders without one.

- [ ] **Step 4: Write `src/components/Scene.astro`**

```astro
---
import PhoneFrame from './PhoneFrame.astro';
import today from '../assets/screens/today.png';
import cycles from '../assets/screens/cycles.png';
import year from '../assets/screens/year.png';

const steps = [
  { h: 'Everything due today, in one list.', p: 'Tap to mark it taken. The time sits beside each one.', src: today, alt: 'The Today screen with the day\'s doses listed by time' },
  { h: 'Eight weeks on, four off. Drawn, not remembered.', p: 'Every schedule is a bar across the months, breaks included.', src: cycles, alt: 'The Cycles screen: each schedule as a bar across four months, with a break shown hatched' },
  { h: 'Twelve months at a glance.', p: 'How much of each month is covered, on one screen.', src: year, alt: 'The Year screen: twelve month cards showing how much of each is covered' },
];
---
<section class="scene wrap" data-scene aria-label="What VitoMy shows">
  <div class="scene__pin">
    <div class="scene__copy">
      {steps.map((s, i) => (
        <div class="scene__step" style={`--i:${i}`}>
          <h2>{s.h}</h2>
          <p class="muted">{s.p}</p>
        </div>
      ))}
    </div>
    <div class="scene__shots">
      {steps.map((s, i) => (
        <PhoneFrame class="scene__shot" src={s.src} alt={s.alt} />
      ))}
    </div>
  </div>
</section>

<script>
  const root = document.querySelector<HTMLElement>('[data-scene]');
  const wants = matchMedia('(min-width: 1024px) and (prefers-reduced-motion: no-preference)');
  if (root && wants.matches) {
    const io = new IntersectionObserver(
      async ([entry]) => {
        if (!entry.isIntersecting) return;
        io.disconnect();
        const { mountScene } = await import('./Scene');
        mountScene(root);
      },
      { rootMargin: '300px 0px' },
    );
    io.observe(root);
  }
</script>

<style>
  /* Default (phones, tablets, reduced motion, no JS): three plain rows,
     copy above its screenshot. The two columns dissolve with display:contents
     and `order` interleaves them. This is the section's mobile design. */
  .scene { padding-block: 4rem; }
  .scene__pin { display: grid; gap: 2.5rem 3rem; }
  .scene__copy, .scene__shots { display: contents; }
  .scene__step { order: calc(var(--i) * 2); }
  .scene__shots :global(.scene__shot) { order: calc(var(--i) * 2 + 1); justify-self: center; }
  .scene__step p { margin-top: 0.75rem; max-width: 36ch; }

  /* Pinned (added by Scene.ts at >= 1024px, motion allowed): one viewport,
     copy stacked in the left cell, screens stacked in the right cell. */
  .scene--pinned .scene__pin {
    grid-template-columns: 5fr 7fr; align-items: center;
    height: 100dvh; gap: 3rem;
  }
  .scene--pinned .scene__copy { display: grid; }
  .scene--pinned .scene__step { grid-area: 1 / 1; order: 0; }
  .scene--pinned .scene__shots {
    display: grid; justify-self: center;
    border-radius: var(--radius-panel); box-shadow: var(--shadow);
  }
  .scene--pinned .scene__shots :global(.scene__shot) { grid-area: 1 / 1; order: 0; box-shadow: none; }
</style>
```

The `style={`--i:${i}`}` attribute is inline CSS, not an inline script; the CSP allows `style-src 'self'` only, which blocks inline **stylesheets** and `style` attributes alike in strict mode. Replace the custom property with explicit classes: give each step `class="scene__step scene__step--{i}"` and each shot `class="scene__shot scene__shot--{i}"`, and write the six `order` rules out by hand:

```css
.scene__step--0 { order: 0 } .scene__shots :global(.scene__shot--0) { order: 1 }
.scene__step--1 { order: 2 } .scene__shots :global(.scene__shot--1) { order: 3 }
.scene__step--2 { order: 4 } .scene__shots :global(.scene__shot--2) { order: 5 }
```

Do it that way; no `style=` attribute anywhere on the site. `PhoneFrame` takes `class` and passes it through `class:list`, so `class={`scene__shot scene__shot--${i}`}` works.

- [ ] **Step 5: Insert the scene**

In `src/pages/index.astro`, import `Scene` and place `<Scene />` between the hero section and the band.

- [ ] **Step 6: Build and test**

Run: `npm run build && npm test`
Expected: PASS. `scene.test.mjs` finds the three `h2`s in order, the page script free of `ScrollTrigger`, and a second chunk that carries it.

- [ ] **Step 7: Look at it, carefully**

`npm run preview`, open `http://localhost:4321/` at 1440x900 in Chrome, Safari and Firefox:

- Scrolling into the scene pins it at the top of the viewport (not halfway; if it pins late, `start` is wrong).
- The phone frame does not flicker between steps; only the screen changes.
- After the third step the page releases and the download band follows.
- Scroll back up: the steps reverse.
- At 900px wide: no pin, three rows, no GSAP request in the Network panel.
- With reduced motion emulated at 1440px: same three rows, no GSAP request.

Stop the preview.

- [ ] **Step 8: Commit**

```bash
cd /Users/dima/supplements
git add site/src/components/Scene.astro site/src/components/Scene.ts site/src/pages/index.astro site/test/scene.test.mjs
git commit -m "feat(site): the pinned scene, Today to Cycles to Year, GSAP loaded only where it plays"
```

---

### Task 8: The download band's reveal, and the landing pre-flight

**Files:**
- Modify: `site/src/pages/index.astro` (band reveal, final spacing)

**Interfaces:**
- Consumes: everything above. Produces the finished landing page.

- [ ] **Step 1: Add the scroll-driven reveal to the band**

In the `<style>` of `index.astro`:

```css
@supports (animation-timeline: view()) {
  @media (prefers-reduced-motion: no-preference) {
    .band .wrap > * {
      animation: rise linear both;
      animation-timeline: view();
      animation-range: entry 0% entry 40%;
    }
  }
}
```

Browsers without scroll-driven animations show the band as is.

- [ ] **Step 2: Run the section 14 pre-flight of `design-taste-frontend` against the landing**

Read `site/dist/index.html` and the page in the browser and tick, in the task report, every box. The ones most likely to need work:

- Eyebrow count: the landing has zero. Keep it so.
- Hero: headline two lines at 1440, subtext 17 words, two CTAs visible, `pt` at most 6rem.
- Layout families: split hero, pinned scene, full-width band, footer columns. Four, none repeated.
- Duplicate CTA intent: the same two labels in hero and band. Allowed; different labels would not be.
- Button contrast: the inert pill's `--accent` text on the 14% tint: measure it in devtools (contrast ratio at least 4.5:1 in both schemes; if the dark scheme fails, raise the tint to 20%).
- Dark mode: open both schemes.
- Em dashes: `npm test` proves zero.
- Real images: three real screenshots, no div mock-ups.

- [ ] **Step 3: Build, test, commit**

Run: `npm run build && npm test`
Expected: PASS.

```bash
cd /Users/dima/supplements
git add site/src/pages/index.astro
git commit -m "feat(site): download band reveal; landing pre-flight clean"
```

---

### Task 9: Support and 404

**Files:**
- Create: `site/src/pages/support.astro`, `site/src/pages/404.astro`

**Interfaces:**
- Consumes: `Base.astro`, `supportEmail`, the Phosphor `envelope.svg`.

- [ ] **Step 1: Write `src/pages/support.astro`**

```astro
---
import Base from '../layouts/Base.astro';
import { supportEmail } from '../config';
import envelope from '@phosphor-icons/core/assets/regular/envelope.svg?raw';
---
<Base title="Support | VitoMy" description="How to reach VitoMy support, and what to include so a problem can be looked at.">
  <section class="support wrap">
    <h1>Support</h1>
    <p class="support__lead">Questions and problems go to one address.</p>
    <a class="pill pill--solid support__mail" href={`mailto:${supportEmail}`}>
      <span class="support__glyph" set:html={envelope} />
      {supportEmail}
    </a>

    <h2>What to include</h2>
    <ul>
      <li>The phone model and the OS version.</li>
      <li>What was expected, and what happened instead.</li>
      <li>A screenshot, if there is one.</li>
    </ul>

    <h2>What VitoMy is</h2>
    <p>VitoMy is a planner. It records what you decide to take and when, and reminds you at the times you set. It does not suggest what to take, how much, or whether to take anything at all.</p>

    <p class="support__legal">The <a href="/privacy">Privacy Policy</a> describes what the app stores and where.</p>
  </section>
</Base>

<style>
  .support { max-width: 68ch; padding-block: 3rem 2rem; }
  .support__lead { margin-top: 0.75rem; color: var(--ink-2); }
  .support__mail { margin-top: 1.5rem; }
  .support__glyph { display: inline-flex; }
  .support__glyph :global(svg) { width: 22px; height: 22px; fill: currentColor; }
  .support h2 { font-size: 1.5rem; margin-top: 3rem; }
  .support ul { padding-inline-start: 1.25rem; margin-top: 1rem; }
  .support li { margin-top: 0.5rem; }
  .support p { margin-top: 1rem; }
  .support__legal { margin-top: 2rem; }
  .support a:not(.pill) { color: var(--accent); }
</style>
```

- [ ] **Step 2: Write `src/pages/404.astro`**

```astro
---
import Base from '../layouts/Base.astro';
---
<Base title="Not found | VitoMy" description="This page does not exist.">
  <section class="wrap" style="">
    <h1 class="nf">This page does not exist.</h1>
    <p class="nf__p"><a href="/">Back to the front page</a></p>
  </section>
</Base>
<style>
  .nf { padding-top: 4rem; }
  .nf__p { margin-top: 1.5rem; }
  .nf__p a { color: var(--accent); }
</style>
```

Remove the empty `style=""` attribute; it was a slip in this plan and the CSP forbids `style` attributes.

- [ ] **Step 3: Build and test**

Run: `npm run build && npm test`
Expected: PASS. `dist/support.html` and `dist/404.html` exist; the vocabulary gate accepts both (re-read the support copy: "problem", "expected", "happened" carry no stem; if a stem fires, reword, never allowlist).

- [ ] **Step 4: Look at both**

`npm run preview`, open `/support` and `/nothing-here` (Astro's preview serves `404.html` for unknown paths). Stop the preview.

- [ ] **Step 5: Commit**

```bash
cd /Users/dima/supplements
git add site/src/pages/support.astro site/src/pages/404.astro
git commit -m "feat(site): support and 404 pages"
```

---

### Task 10: Deployment files, README, the STATE entry, and the first deploy

**Files:**
- Create: `site/deploy/vitomy.caddy`, `site/scripts/deploy.sh`, `site/README.md`
- Modify: `.planning/STATE.md` (one `SITE-01` row in the blockers table)

**Interfaces:**
- Consumes: the built `dist/`, `ssh bot`.
- Produces: the site live at `https://vitomy.app` once DNS resolves; before that, reachable with `--resolve`.

This task's server steps are run by the `site-deployer` agent, which carries the hard limits (never touch the neighbouring vhosts, never restart Caddy, never `rm` outside the site's two paths).

- [ ] **Step 1: Write `deploy/vitomy.caddy`**

```
# vitomy.app: static files from /var/www/vitomy. Included by the single
# `import /etc/caddy/sites/*.caddy` line at the end of /etc/caddy/Caddyfile.
# TLS is automatic (ACME); this domain is not behind Cloudflare.

vitomy.app {
	root * /var/www/vitomy
	encode zstd gzip
	try_files {path} {path}.html
	file_server

	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options nosniff
		Referrer-Policy strict-origin-when-cross-origin
		Permissions-Policy "camera=(), microphone=(), geolocation=()"
		Content-Security-Policy "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; font-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'none'"
		-Server
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

- [ ] **Step 2: Write `scripts/deploy.sh`**

```bash
#!/usr/bin/env bash
# Build, gate, rsync, Caddy, smoke. Run as `npm run deploy` from site/.
# Only the site-deployer agent runs this against the real server.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=bot
ROOT=/var/www/vitomy
VHOST=/etc/caddy/sites/vitomy.caddy
CADDYFILE=/etc/caddy/Caddyfile
IMPORT_LINE='import /etc/caddy/sites/*.caddy'
IP=45.159.220.17

echo "== build and gates"
npm run build
npm test

echo "== rsync (dry run)"
rsync -az --delete --chmod=D755,F644 --dry-run --itemize-changes dist/ "$HOST:$ROOT/"
echo "== rsync"
rsync -az --delete --chmod=D755,F644 --stats dist/ "$HOST:$ROOT/" | grep -E 'Number of (regular files transferred|deleted files)|Total transferred'

echo "== caddy vhost"
ssh "$HOST" "mkdir -p /etc/caddy/sites"
if ssh "$HOST" "test -f $VHOST" && diff <(ssh "$HOST" "cat $VHOST") deploy/vitomy.caddy >/dev/null; then
  echo "vhost unchanged"
else
  ssh "$HOST" "test -f $VHOST && cat $VHOST" | diff - deploy/vitomy.caddy || true
  scp -q deploy/vitomy.caddy "$HOST:$VHOST"
  echo "vhost written"
fi
if ! ssh "$HOST" "grep -qF '$IMPORT_LINE' $CADDYFILE"; then
  ssh "$HOST" "printf '\n# Sites managed one file each; see /etc/caddy/sites/.\n%s\n' '$IMPORT_LINE' >> $CADDYFILE"
  echo "import line appended to $CADDYFILE"
fi
ssh "$HOST" "caddy validate --config $CADDYFILE --adapter caddyfile >/dev/null && systemctl reload caddy"
echo "caddy reloaded"

echo "== smoke"
if [ -n "$(dig +short A vitomy.app)" ]; then RESOLVE=(); else RESOLVE=(--resolve "vitomy.app:443:$IP"); echo "(no A record yet; using --resolve, TLS may fail)"; fi
code() { curl -sk -o /dev/null -w '%{http_code}' "${RESOLVE[@]}" "https://vitomy.app$1"; }
printf '%-12s %s\n' path status
for p in / /privacy /support /terms /does-not-exist; do printf '%-12s %s\n' "$p" "$(code "$p")"; done
html=$(curl -sk "${RESOLVE[@]}" https://vitomy.app/)
grep -q '\[[A-Z_]*\]' <<<"$html" && { echo "placeholder on the live page"; exit 1; }
grep -qP '\x{2014}|\x{2013}' <<<"$html" && { echo "dash on the live page"; exit 1; }
grep -oE '(src|href)="https?://[^"]+"' <<<"$html" | grep -vE 'https://vitomy\.app/' && { echo "external resource on the live page"; exit 1; }
echo "smoke clean"
```

Make it executable: `chmod +x scripts/deploy.sh`.

- [ ] **Step 3: Write `site/README.md`**

```markdown
# vitomy.app

The website. Rules in `CLAUDE.md`; design in
`../docs/superpowers/specs/2026-09-11-vitomy-site-design.md`.

Node lives at `~/.nvm/versions/node/v24.16.0/bin`; put it on PATH first.

| Command | What it does |
|---|---|
| `npm run dev` | Astro dev server on :4321 (copies the three screenshots first) |
| `npm run build` | Static build to `dist/`; fails if a listed legal document has a placeholder |
| `npm test` | The gates, over `dist/`: meta, mark, placeholders, dashes, vocabulary, external, legal, stores, scene |
| `npm run assets` | Regenerate the mark, favicon, OG image and touch icon from `tool/make_icons.py` |
| `npm run deploy` | Build, gates, rsync to `bot:/var/www/vitomy`, Caddy vhost, reload, smoke test |

## Switches (`src/config.ts`)

- `stores.apple.url`, `stores.google.url`: `null` renders an inert "Coming soon" button. Set the URL and put the OFFICIAL badge in `public/badges/` (`app-store.svg`, `google-play.png`) on launch day.
- `legalPages`: which of `../docs/legal/{privacy,terms}.md` are published. Add `'terms'` after `[NOMINAL_SUM]` is filled.

## Server

`ssh bot`, Caddy on 80/443, vhost `/etc/caddy/sites/vitomy.caddy`, root `/var/www/vitomy`. Other sites live on the same box; `deploy.sh` touches only those two paths and the one import line.

DNS at Spaceship: `A @ 45.159.220.17`, `A www 45.159.220.17`.

## Lighthouse

Run `npm run preview`, then in another shell
`npx lighthouse http://localhost:4321/ --preset=desktop --chrome-flags=--headless --output=json --output-path=/tmp/lh.json --quiet && node -e "const r=require('/tmp/lh.json').categories;console.log(Object.fromEntries(Object.entries(r).map(([k,v])=>[k,Math.round(v.score*100)])))"`.

Last recorded: (filled in by Task 11)
```

- [ ] **Step 4: Add the STATE row**

In `.planning/STATE.md`, in the open-items table that holds the `Legal` row (line 307 area), add directly after it:

```
| Site | `SITE-01` vitomy.app: Astro static site in `site/`, spec `docs/superpowers/specs/2026-09-11-vitomy-site-design.md`, plan `docs/superpowers/plans/2026-09-11-vitomy-site.md`. Closes Apple's Support URL and both stores' privacy-policy URL. `/terms` waits on `[NOMINAL_SUM]`; store buttons inert until launch | Dima adds two A records at Spaceship; deploy via `site-deployer` | 2026-09-11 |
```

Check `git diff .planning/STATE.md` shows only that line before adding. Another session may be editing this file; if the diff shows other changes, add with `git add -p .planning/STATE.md` and stage only your hunk.

- [ ] **Step 5: Commit the files before deploying**

```bash
cd /Users/dima/supplements
git add site/deploy/vitomy.caddy site/scripts/deploy.sh site/README.md .planning/STATE.md
git commit -m "feat(site): Caddy vhost, deploy script, README, and the SITE-01 state entry"
```

- [ ] **Step 6: Deploy (site-deployer agent)**

Run: `npm run deploy`
Expected: gates pass; the dry run lists only paths under `/var/www/vitomy`; `vhost written`; `import line appended`; `caddy reloaded`; the smoke table. Without DNS the statuses may be `000` (TLS refused for an unknown host) rather than 200; report what was observed and `dig +short A vitomy.app`.

Then verify by hand on the server, read-only: `ssh bot 'ls /var/www/vitomy; tail -3 /etc/caddy/Caddyfile; systemctl is-active caddy; curl -sI -H "Host: rin.live" http://127.0.0.1/ | head -1'`. The neighbour must still answer.

- [ ] **Step 7: Report the DNS step to Dima**

The task report ends with the two A records and the sentence: once they resolve, run `npm run deploy` again (or just wait; Caddy retries certificate issuance on its own) and the smoke table should read 200 / 200 / 200 / 404 / 404.

---

### Task 11: Review and Lighthouse

**Files:**
- Modify: `site/README.md` (the Lighthouse record)
- Whatever the review finds (fixes go through `site-builder`, each with its own commit)

- [ ] **Step 1: Run `site-reviewer` on the built site**

Dispatch the `site-reviewer` agent with: "Review the built site in `site/dist/` for the landing, privacy, support and 404 pages against `site/CLAUDE.md`, the spec, and section 14 of `design-taste-frontend`. Report ranked findings." It edits nothing.

- [ ] **Step 2: Fix what it found**

Each finding of severity "must fix" becomes one `site-builder` dispatch with the finding text, ending in `npm run build && npm test` green and a `fix(site): ...` commit. Findings the reviewer rated cosmetic are listed in the final report, not fixed now.

- [ ] **Step 3: Lighthouse**

Run the command from `site/README.md` against the preview server, once with the OS in light mode and once in dark (Lighthouse follows the system scheme in headless Chrome only with `--chrome-flags="--headless --force-dark-mode"` for the dark pass).
Expected: performance at or above 95, accessibility 100, best practices 100, SEO 100. Anything lower is a finding for Step 2.

Write the four numbers and the date under "Last recorded" in `site/README.md`.

- [ ] **Step 4: Commit and report**

```bash
cd /Users/dima/supplements
git add site/README.md
git commit -m "docs(site): Lighthouse record after review"
```

Final report: the URL state (DNS pending or live), the smoke table, the Lighthouse numbers, the findings fixed and the ones deferred, and the two switches left for launch day.

---

## Self-review notes

- **Spec coverage.** Pages (T1, T4, T9), visual system (T1, T2, T6), landing sections 1 to 5 (T1 header/footer, T6 hero, T7 scene, T8 band, T2 footer mark), store buttons (T5), legal pages and the placeholder gate (T4), support (T9), 404 (T9), meta and assets (T1, T2), sitemap and robots (T1), deployment and DNS (T10), gates (T1, T2, T3, T4, T5, T7), project layout (all), agents (written before this plan), process (T10, T11). Not covered: the spec's "fonts preloaded" line; Fontsource hashes its file names so a `<link rel="preload">` cannot be written statically, and `font-display: swap` plus a metric-compatible fallback stack is what ships. The reviewer should check self-hosting, not preloading.
- **Two spec deviations, both recorded in the tasks:** the inert store button is a tinted pill (T5) rather than 55% opacity; the mark parity gate is `make_og.py --check` (T2) rather than a raster diff.
- **Type consistency.** `stores[id]` has `{ url, label, badge }` in T1 and is consumed as such in T3, T5. `legalPages: readonly string[]` in T1, consumed by `.includes(id)` in T1's footer, T4's page and gate, T4's test. `assertNoPlaceholders([{ name, path }])` in T4 code and test. `PhoneFrame` `class` prop in T6, used by T7. `mountScene(root)` in T7 code and its `Scene.astro` caller. `copyOf`, `attrValues`, `textOf`, `htmlFiles`, `cssFiles`, `distFiles`, `DIST` from `helpers.mjs` (T1) used in T3, T4, T5, T7.
- **Placeholder scan.** No TBD/TODO. Every code step has its code. The one "(filled in by Task 11)" in the README is filled by Task 11.
