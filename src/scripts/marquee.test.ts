import { beforeEach, describe, expect, it } from 'vitest';
import { cloneMarquee } from './marquee';

const track = (): HTMLElement => document.querySelector<HTMLElement>('[data-marquee]')!;

beforeEach(() => {
  document.body.innerHTML = '<ul data-marquee><li>Python</li><li>XDR</li></ul>';
});

describe('cloneMarquee', () => {
  it('appends a hidden copy of every item for the seamless loop', () => {
    cloneMarquee();
    const items = [...track().children];
    expect(items).toHaveLength(4);
    expect(items.slice(2).every((li) => li.getAttribute('aria-hidden') === 'true')).toBe(true);
    expect(items.slice(2).map((li) => li.textContent)).toEqual(['Python', 'XDR']);
  });

  it('leaves the original items readable (not aria-hidden)', () => {
    cloneMarquee();
    expect(track().children[0].hasAttribute('aria-hidden')).toBe(false);
  });

  it('is idempotent when called again (astro:page-load)', () => {
    cloneMarquee();
    cloneMarquee();
    expect(track().children).toHaveLength(4);
  });

  it('does nothing without a marquee or with an empty one', () => {
    document.body.innerHTML = '';
    expect(() => cloneMarquee()).not.toThrow();
    document.body.innerHTML = '<ul data-marquee></ul>';
    cloneMarquee();
    expect(track().children).toHaveLength(0);
  });
});

describe('cloneMarquee — several tracks', () => {
  it('clones every track on the page, each one once', () => {
    document.body.innerHTML =
      '<ul data-marquee><li>A</li></ul><ul data-marquee><li>B</li><li>C</li></ul>';
    cloneMarquee();
    cloneMarquee();
    const tracks = [...document.querySelectorAll('[data-marquee]')];
    expect(tracks.map((t) => t.children.length)).toEqual([2, 4]);
  });
});
