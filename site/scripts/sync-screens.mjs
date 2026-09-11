// Copies the three landing screenshots from the store set into src/assets so
// Astro's image pipeline can import them. The store set is the source; this
// directory is gitignored and rebuilt on every build.
import { copyFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const from = fileURLToPath(new URL('../../store/screenshots/ios-6.9/', import.meta.url));
const to = fileURLToPath(new URL('../src/assets/screens/', import.meta.url));
mkdirSync(to, { recursive: true });
for (const [src, dst] of [['02-today.png', 'today.png'], ['03-cycles.png', 'cycles.png'], ['04-year.png', 'year.png']]) {
  copyFileSync(from + src, to + dst);
}
