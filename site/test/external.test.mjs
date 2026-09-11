import test from 'node:test';
import assert from 'node:assert/strict';
import { htmlFiles, cssFiles, attrValues } from './helpers.mjs';
import { stores } from '../src/config.ts';

const allowedPrefixes = ['/', '#', 'mailto:support@vitomy.app', 'https://vitomy.app/'];
for (const s of Object.values(stores)) if (s.url) allowedPrefixes.push(s.url);

function allowed(url) {
  // A protocol-relative URL ("//host/path") is external: the browser fills
  // in the current scheme and resolves it off-site. It also starts with "/",
  // so it must be rejected before the "/" prefix below has a chance to admit it.
  if (url.startsWith('//')) return false;
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

// The production CSP says `font-src 'self'`, with no `data:` term. It can say
// that only while no font is inlined as a data: URI, which is a build artefact
// of Vite's assetsInlineLimit, not a decision anyone makes per commit: a small
// enough subset of any newly imported face lands inside the stylesheet and the
// CSP silently starts blocking it. The comment in deploy/vitomy.caddy points
// here. Undoing this means widening the CSP in the same commit, deliberately.
test('no font is inlined as a data: URI, which is what keeps the CSP at font-src \'self\'', () => {
  const bad = cssFiles().filter((c) => /url\(\s*["']?data:(?:font|application\/font|application\/x-font)/i.test(c.css));
  assert.deepEqual(bad.map((c) => c.rel), []);
});

for (const c of cssFiles()) {
  test(`${c.rel}: no external url() or @import`, () => {
    const urls = [...c.css.matchAll(/url\(\s*["']?([^"')]+)["']?\s*\)/g)].map((m) => m[1]);
    // Same "//host" trap as the HTML check: it starts with "/" but is external.
    const bad = urls.filter((u) => u.startsWith('//') || !(u.startsWith('/') || u.startsWith('data:')));
    assert.deepEqual(bad, []);
    // Matches an explicit scheme (http:/https:) or a bare protocol-relative
    // target, with or without url(...) wrapping.
    const importHit = c.css.match(/@import\s+(?:url\(\s*)?["']?(?:https?:)?\/\/[^"')\s;]*/);
    assert.equal(importHit, null, importHit && `external @import: ${importHit[0]}`);
  });
}
