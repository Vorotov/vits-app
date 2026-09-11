import test from 'node:test';
import assert from 'node:assert/strict';
import { htmlFiles, copyOf } from './helpers.mjs';

for (const p of htmlFiles()) {
  test(`${p.rel}: no [PLACEHOLDER] reached the page`, () => {
    const hit = copyOf(p.html).match(/\[[A-Z_]+\]/);
    assert.equal(hit, null, hit && `found ${hit[0]}`);
  });
}
