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
