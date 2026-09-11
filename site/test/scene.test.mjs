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
