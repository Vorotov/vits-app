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
