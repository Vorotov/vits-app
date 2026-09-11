// The one GSAP island. Imported dynamically by Scene.astro only when the
// section is near the viewport, at >= 1024px, and motion is not reduced.
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

export function mountScene(root: HTMLElement): void {
  gsap.registerPlugin(ScrollTrigger);
  const pin = root.querySelector<HTMLElement>('.scene__pin');
  const steps = Array.from(root.querySelectorAll<HTMLElement>('.scene__step'));
  const screens = Array.from(root.querySelectorAll<HTMLElement>('.scene__shot picture, .scene__shot img'))
    .filter((el, _, all) => el.tagName === 'PICTURE' || !all.some((o) => o.tagName === 'PICTURE' && o.contains(el)));
  if (!pin || steps.length < 2 || screens.length !== steps.length) return;

  /* The three steps stack in one grid cell, so the two that are transparent
     would still take the pointer and swallow selection of the visible
     headline. Only the most opaque one is left clickable; a strict `> 0.99`
     test would leave the cell dead through every transition. Nothing inside a
     step is interactive, so this costs a class toggle and buys back text
     selection. Three inline-style reads per scrub frame, no layout. */
  function markActiveStep(): void {
    let top = 0;
    let best = -1;
    steps.forEach((step, i) => {
      const o = Number(gsap.getProperty(step, 'opacity'));
      if (o > best) { best = o; top = i; }
    });
    steps.forEach((step, i) => step.classList.toggle('scene__step--active', i === top));
  }

  root.classList.add('scene--pinned');
  /* `opacity`, never `autoAlpha`. autoAlpha is opacity PLUS visibility, and a
     `visibility: hidden` node is pruned from the accessibility tree: with
     motion on, the tree carried one of the three headings and one of the three
     alt texts, and a screen reader's virtual cursor cannot land on the other
     two, so it never scrolls far enough to reveal them (audit finding 2). The
     copy of two of the three propositions exists nowhere else on the site.
     Hidden-by-opacity keeps every node exposed. */
  gsap.set(steps.slice(1), { opacity: 0, y: 24 });
  gsap.set(screens.slice(1), { opacity: 0 });
  markActiveStep();

  const tl = gsap.timeline({
    defaults: { ease: 'none' },
    onUpdate: markActiveStep,
    scrollTrigger: {
      trigger: root,
      start: 'top top',
      end: () => `+=${(steps.length - 1) * window.innerHeight}`,
      pin,
      scrub: 0.6,
      invalidateOnRefresh: true,
    },
  });

  /* Each step owns one unit of the timeline, which is one viewport of scroll.
     The two blocks of COPY never share the cell: the outgoing headline is at
     zero by 0.60 and the incoming one does not start until 0.65. Both sit in
     `grid-area: 1 / 1`, so any overlap superimposes two headlines word on word
     and neither can be read (audit finding 1). The SCREENS do overlap, from
     0.50 to 0.75: they are photographs, which cross-dissolve cleanly, and a
     gap between them would show an empty phone frame instead. Each screen
     still starts or ends with its own step, so the picture and its sentence
     read as one move. Dwell at full opacity: 0.30 of a viewport for the first
     step, 0.35 for every one after it. */
  for (let i = 1; i < steps.length; i++) {
    tl.to(steps[i - 1], { opacity: 0, y: -24, duration: 0.3 }, i - 1 + 0.3)
      .to(screens[i - 1], { opacity: 0, duration: 0.45 }, '<')
      .to(screens[i], { opacity: 1, duration: 0.45 }, i - 1 + 0.5)
      .to(steps[i], { opacity: 1, y: 0, duration: 0.3 }, i - 1 + 0.65);
  }
}
