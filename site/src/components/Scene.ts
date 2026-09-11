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

  root.classList.add('scene--pinned');
  gsap.set(steps.slice(1), { autoAlpha: 0, y: 24 });
  gsap.set(screens.slice(1), { autoAlpha: 0 });

  const tl = gsap.timeline({
    defaults: { ease: 'none' },
    scrollTrigger: {
      trigger: root,
      start: 'top top',
      end: () => `+=${(steps.length - 1) * window.innerHeight}`,
      pin,
      scrub: 0.6,
      invalidateOnRefresh: true,
    },
  });

  for (let i = 1; i < steps.length; i++) {
    tl.to(steps[i - 1], { autoAlpha: 0, y: -24, duration: 0.45 }, i - 1 + 0.35)
      .to(screens[i - 1], { autoAlpha: 0, duration: 0.45 }, '<')
      .to(steps[i], { autoAlpha: 1, y: 0, duration: 0.45 }, '<0.15')
      .to(screens[i], { autoAlpha: 1, duration: 0.45 }, '<');
  }
}
