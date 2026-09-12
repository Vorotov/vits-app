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

The domain sits behind Cloudflare, so the server's address stays private. Two things follow, and the vhost's own comments carry the reasoning:

- TLS is a Cloudflare Origin Certificate at `/etc/ssl/cloudflare/vitomy-origin.pem` and `.key`, valid to 2041, issued for `vitomy.app` and `*.vitomy.app`. The neighbours' `origin.pem` covers rin.live and does not cover this name.
- Only Cloudflare's published address ranges may reach the origin; anything else is refused. Cloudflare changes that list rarely, and when it does the site goes dark, so the fix is to re-fetch `cloudflare.com/ips-v4` and `/ips-v6` into the vhost and redeploy.

Because of the second point there is no way to test the site except through Cloudflare: a direct request to the address is supposed to fail, and the smoke test asserts exactly that.

DNS lives at Cloudflare: `A @ 45.159.220.17` proxied, `A www 45.159.220.17` proxied, with the two Spaceship MX records kept and left unproxied so mail to `support@vitomy.app` still arrives. The nameservers at Spaceship point at Cloudflare.

## Lighthouse

Run `npm run preview`, then in another shell
`npx lighthouse http://localhost:4321/ --preset=desktop --chrome-flags=--headless --output=json --output-path=/tmp/lh.json --quiet && node -e "const r=require('/tmp/lh.json').categories;console.log(Object.fromEntries(Object.entries(r).map(([k,v])=>[k,Math.round(v.score*100)])))"`.

Last recorded: 2026-09-11, desktop preset, against `npx astro preview --port 4330`.

| Page | Scheme | Performance | Accessibility | Best Practices | SEO |
|---|---|---|---|---|---|
| / | light | 100 | 100 | 100 | 100 |
| / | dark | 100 | 100 | 100 | 100 |
| /privacy | light | 100 | 100 | 100 | 100 |
| /support | light | 100 | 100 | 100 | 100 |

All four categories hit target (performance at least 95, the other three at 100) on every run. No failing audits to list.
