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
