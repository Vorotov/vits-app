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

// Source gates over Scene.ts itself: the three fixes from the Task 11 audit
// (crossfade sequencing, opacity-not-autoAlpha, matchMedia cleanup) have no
// other coverage, so a future edit could silently reintroduce any of them.
// Comments stripped first, same as this repo's other source gates, so a
// comment naming the forbidden token cannot trip its own gate.
const sceneSrc = readFileSync(new URL('../src/components/Scene.ts', import.meta.url), 'utf8');
const sceneCode = sceneSrc.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

test('Scene.ts never animates autoAlpha', () => {
  // autoAlpha is opacity PLUS visibility, and a visibility:hidden node drops
  // out of the accessibility tree (audit finding 2) - opacity alone is the
  // fix, and it must stay the only property used to hide a step or a screen.
  assert.ok(!/autoAlpha/.test(sceneCode), 'Scene.ts uses autoAlpha outside a comment: this hides a node from the accessibility tree (audit finding 2) - use opacity instead');
});

test('the pinned scene mounts only inside gsap.matchMedia, and its cleanup fully releases the pin', () => {
  const query = '(min-width: 1024px) and (prefers-reduced-motion: no-preference)';
  assert.ok(sceneCode.includes('gsap.matchMedia()'), 'gsap.matchMedia() call went missing: the mount must live inside matchMedia so GSAP reverts it when the viewport or reduced-motion query stops matching (audit finding 3)');
  const addIdx = sceneCode.indexOf('mm.add(');
  assert.ok(addIdx >= 0, 'mm.add(...) call went missing');
  assert.ok(
    sceneCode.slice(addIdx).startsWith(`mm.add('${query}'`),
    `matchMedia query changed or is no longer exactly "${query}" - a widened or narrowed query changes which viewports get the pin`,
  );
  const region = sceneCode.slice(addIdx);
  const returnIdx = region.indexOf('return () => {');
  assert.ok(returnIdx >= 0, 'the matchMedia handler lost its cleanup (return () => {...}): without one, a viewport dragged below 1024px leaves the section pinned for the rest of the session (audit finding 3)');
  const cleanup = region.slice(returnIdx);
  assert.ok(
    cleanup.includes("classList.remove('scene--pinned')"),
    'cleanup no longer removes scene--pinned: the section would stay in its pinned two-column layout after the viewport shrinks (audit finding 3)',
  );
  assert.ok(
    cleanup.includes("classList.remove('scene__step--active')"),
    'cleanup no longer clears the active-step marker: a stale scene__step--active would survive a revert (audit finding 3)',
  );
  assert.ok(
    cleanup.includes('clearProps'),
    'cleanup no longer calls gsap.set(..., { clearProps }): the inline opacity/transform gsap.set wrote would strand the fallback layout after revert (audit finding 3)',
  );
});

test('the outgoing and incoming step tweens never overlap', () => {
  // Parsed from source, not hard-coded, so a changed shape fails loudly
  // instead of silently matching nothing. tl.to(steps[i - 1], {...}, START)
  // is the outgoing headline; .to(steps[i], {...}, START) is the incoming
  // one. Two headlines superimposed word-on-word was audit finding 1.
  const outgoing = sceneCode.match(/tl\.to\(steps\[i - 1\],\s*\{([^}]*)\},\s*i - 1 \+ ([\d.]+)\)/);
  assert.ok(outgoing, 'could not find the outgoing steps[i - 1] tween (tl.to(steps[i - 1], { ... }, i - 1 + N)) - the crossfade shape changed, update this parser');
  const incoming = sceneCode.match(/\.to\(steps\[i\],\s*\{([^}]*)\},\s*i - 1 \+ ([\d.]+)\)/);
  assert.ok(incoming, 'could not find the incoming steps[i] tween (.to(steps[i], { ... }, i - 1 + N)) - the crossfade shape changed, update this parser');

  const outgoingDuration = outgoing[1].match(/duration:\s*([\d.]+)/);
  assert.ok(outgoingDuration, 'the outgoing tween has no duration - the crossfade shape changed, update this parser');
  const incomingStart = Number(incoming[2]);
  const outgoingEnd = Number(outgoing[2]) + Number(outgoingDuration[1]);

  assert.ok(
    incomingStart >= outgoingEnd,
    `the incoming headline starts at ${incomingStart} but the outgoing one is not fully faded until ${outgoingEnd}: they overlap and two headlines read superimposed (audit finding 1)`,
  );
});
