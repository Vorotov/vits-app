// Fails the build when a PUBLISHED legal document still carries a
// [PLACEHOLDER]. This is the interview decision of 2026-09-11: privacy and
// support ship first; terms ships when [NOMINAL_SUM] is filled and 'terms' is
// added to legalPages in src/config.ts. Unlisted documents are neither emitted
// nor linked, so nothing half-finished can reach the public page.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { legalPages } from '../src/config.ts';

const PLACEHOLDER = /\[[A-Z_]+\]/;

export function assertNoPlaceholders(files) {
  for (const { name, path } of files) {
    const lines = readFileSync(path, 'utf8').split('\n');
    lines.forEach((line, i) => {
      const m = PLACEHOLDER.exec(line);
      if (m) {
        throw new Error(
          `${name}.md:${i + 1}: placeholder ${m[0]} would be published. ` +
            `Fill it in docs/legal/${name}.md or remove "${name}" from legalPages in site/src/config.ts.`,
        );
      }
    });
  }
}

export default function legalGate() {
  return {
    name: 'vitomy-legal-gate',
    hooks: {
      'astro:build:start': () => {
        const dir = fileURLToPath(new URL('../../docs/legal/', import.meta.url));
        assertNoPlaceholders(legalPages.map((name) => ({ name, path: `${dir}${name}.md` })));
      },
    },
  };
}
