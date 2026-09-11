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
