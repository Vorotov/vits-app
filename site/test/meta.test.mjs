import test from 'node:test';
import assert from 'node:assert/strict';
import { htmlFiles } from './helpers.mjs';

const pages = htmlFiles();

test('dist/ holds at least the landing page', () => {
  assert.ok(pages.some((p) => p.rel === 'index.html'), 'run `npm run build` first');
});

for (const p of pages) {
  test(`${p.rel}: lang, title, description, canonical, og:image`, () => {
    assert.match(p.html, /<html[^>]*\blang="en"/);
    assert.match(p.html, /<title>[^<]+<\/title>/);
    assert.match(p.html, /<meta name="description" content="[^"]+"/);
    assert.match(p.html, /<link rel="canonical" href="https:\/\/vitomy\.app\/[^"]*"/);
    assert.match(p.html, /<meta property="og:image" content="https:\/\/vitomy\.app\/og\.png"/);
  });

  test(`${p.rel}: canonical and og:url never end in .html`, () => {
    const [canonical] = p.html.match(/<link rel="canonical" href="([^"]*)"/)?.slice(1) ?? [];
    const [ogUrl] = p.html.match(/<meta property="og:url" content="([^"]*)"/)?.slice(1) ?? [];
    assert.ok(canonical, 'no canonical link found');
    assert.ok(ogUrl, 'no og:url meta found');
    assert.doesNotMatch(canonical, /\.html$/, `canonical ends in .html: ${canonical}`);
    assert.doesNotMatch(ogUrl, /\.html$/, `og:url ends in .html: ${ogUrl}`);
    if (p.rel === 'index.html') {
      assert.equal(canonical, 'https://vitomy.app/');
      assert.equal(ogUrl, 'https://vitomy.app/');
    }
  });

  test(`${p.rel}: every <img> has alt, width and height; no inline script`, () => {
    for (const img of p.html.match(/<img\b[^>]*>/g) ?? []) {
      for (const a of ['alt', 'width', 'height']) {
        assert.match(img, new RegExp(`\\b${a}="`), `${img.slice(0, 120)} lacks ${a}`);
      }
    }
    for (const s of p.html.match(/<script\b[^>]*>[\s\S]*?<\/script>/g) ?? []) {
      assert.match(s, /\bsrc="/, `inline script found: ${s.slice(0, 120)}`);
    }
  });
}
