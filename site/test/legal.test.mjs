import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { htmlFiles, textOf, attrValues } from './helpers.mjs';
import { legalPages } from '../src/config.ts';
import { assertNoPlaceholders } from '../integrations/legal-gate.mjs';

const legalDir = fileURLToPath(new URL('../../docs/legal/', import.meta.url));
const candidates = ['privacy', 'terms'];
const pages = htmlFiles();

test('assertNoPlaceholders throws on a bracketed token with file and line', () => {
  const dir = mkdtempSync(join(tmpdir(), 'legal-'));
  const bad = join(dir, 'bad.md');
  writeFileSync(bad, '# T\n\nLast updated: [LAST_UPDATED]\n');
  assert.throws(() => assertNoPlaceholders([{ name: 'bad', path: bad }]), /bad\.md:3: placeholder \[LAST_UPDATED\]/);
});

test('every published document is free of placeholders', () => {
  assertNoPlaceholders(legalPages.map((name) => ({ name, path: join(legalDir, `${name}.md`) })));
});

for (const name of candidates) {
  const listed = legalPages.includes(name);
  test(`${name}: emitted only when listed (${listed})`, () => {
    assert.equal(existsSync(join(fileURLToPath(new URL('../dist/', import.meta.url)), `${name}.html`)), listed);
  });
  if (!listed) {
    test(`${name}: linked from no page while unlisted`, () => {
      for (const p of pages) {
        assert.ok(!attrValues(p.html, 'href').includes(`/${name}`), `${p.rel} links to /${name}`);
      }
    });
  } else {
    test(`${name}: every ## of the source is an h2 on the page`, () => {
      const md = readFileSync(join(legalDir, `${name}.md`), 'utf8');
      const heads = [...md.matchAll(/^## (.+)$/gm)].map((m) => m[1].trim());
      const page = pages.find((p) => p.rel === `${name}.html`);
      assert.ok(page, `${name}.html missing`);
      const h2s = [...page.html.matchAll(/<h2[^>]*>([\s\S]*?)<\/h2>/g)].map((m) => textOf(m[1]).trim());
      for (const h of heads) assert.ok(h2s.includes(h), `heading "${h}" not rendered`);
      assert.match(textOf(page.html), /Last updated: \d{1,2} \w+ \d{4}/);
    });
  }
}
