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
