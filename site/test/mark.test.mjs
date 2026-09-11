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
