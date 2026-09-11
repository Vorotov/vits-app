import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

export const DIST = fileURLToPath(new URL('../dist/', import.meta.url));

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

/** Every file in dist/ as { path, rel, html|css|text }. */
export function distFiles() {
  return walk(DIST).map((path) => ({ path, rel: relative(DIST, path) }));
}

export function htmlFiles() {
  return distFiles()
    .filter((f) => f.rel.endsWith('.html'))
    .map((f) => ({ ...f, html: readFileSync(f.path, 'utf8') }));
}

export function cssFiles() {
  return distFiles()
    .filter((f) => f.rel.endsWith('.css'))
    .map((f) => ({ ...f, css: readFileSync(f.path, 'utf8') }));
}

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', '#39': "'" };
export function decode(s) {
  return s.replace(/&(#\d+|#x[0-9a-f]+|[a-z]+);/gi, (m, e) => {
    if (e[0] === '#') return String.fromCodePoint(e[1] === 'x' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10));
    return ENTITIES[e] ?? m;
  });
}

/** Visible text of a page: scripts, styles, comments and tags removed. */
export function textOf(html) {
  return decode(
    html
      .replace(/<script\b[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style\b[\s\S]*?<\/style>/gi, ' ')
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<[^>]+>/g, ' '),
  );
}

/** All values of a given attribute across the page, decoded. */
export function attrValues(html, name) {
  const re = new RegExp(`\\b${name}="([^"]*)"`, 'g');
  return [...html.matchAll(re)].map((m) => decode(m[1]));
}

/** Text plus the human-readable attributes, for copy gates. */
export function copyOf(html) {
  return [textOf(html), ...attrValues(html, 'alt'), ...attrValues(html, 'aria-label'), ...attrValues(html, 'title'), ...attrValues(html, 'content')].join('\n');
}
