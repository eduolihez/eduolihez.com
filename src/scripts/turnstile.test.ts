import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { loadTurnstileOnDemand } from './turnstile';

const SRC = 'https://challenges.cloudflare.com/turnstile/v0/api.js';
const scripts = (): HTMLScriptElement[] => [...document.querySelectorAll<HTMLScriptElement>(`script[src="${SRC}"]`)];

let observed: { callback: IntersectionObserverCallback; target?: Element; disconnected: boolean } | null;

class FakeObserver {
  constructor(callback: IntersectionObserverCallback) {
    observed = { callback, disconnected: false };
  }
  observe(target: Element): void {
    observed!.target = target;
  }
  disconnect(): void {
    observed!.disconnected = true;
  }
}

const form = (): HTMLFormElement => document.getElementById('contact-form') as HTMLFormElement;

beforeEach(() => {
  observed = null;
  document.head.innerHTML = '';
  document.body.innerHTML = '<form id="contact-form"><input id="name" /><div class="cf-turnstile"></div></form>';
  vi.stubGlobal('IntersectionObserver', FakeObserver);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('loadTurnstileOnDemand', () => {
  it('does not load the script on page load', () => {
    loadTurnstileOnDemand(form(), SRC);
    expect(scripts()).toHaveLength(0);
  });

  it('loads it once when the visitor focuses a field of the form', () => {
    loadTurnstileOnDemand(form(), SRC);
    document.getElementById('name')!.dispatchEvent(new FocusEvent('focusin', { bubbles: true }));
    document.getElementById('name')!.dispatchEvent(new FocusEvent('focusin', { bubbles: true }));
    expect(scripts()).toHaveLength(1);
    expect(scripts()[0].async).toBe(true);
  });

  it('loads it when the form comes close to the viewport, then stops observing', () => {
    loadTurnstileOnDemand(form(), SRC);
    expect(observed!.target).toBe(form());

    observed!.callback([{ isIntersecting: false } as IntersectionObserverEntry], {} as IntersectionObserver);
    expect(scripts()).toHaveLength(0);

    observed!.callback([{ isIntersecting: true } as IntersectionObserverEntry], {} as IntersectionObserver);
    expect(scripts()).toHaveLength(1);
    expect(observed!.disconnected).toBe(true);
  });

  it('loads it straight away in browsers without IntersectionObserver', () => {
    vi.stubGlobal('IntersectionObserver', undefined);
    loadTurnstileOnDemand(form(), SRC);
    expect(scripts()).toHaveLength(1);
  });

  it('does nothing when the form has no Turnstile widget', () => {
    form().querySelector('.cf-turnstile')!.remove();
    loadTurnstileOnDemand(form(), SRC);
    document.getElementById('name')!.dispatchEvent(new FocusEvent('focusin', { bubbles: true }));
    expect(scripts()).toHaveLength(0);
    expect(observed).toBeNull();
  });

  it('never injects a second copy if the script is already on the page', () => {
    const existing = document.createElement('script');
    existing.src = SRC;
    document.head.append(existing);
    loadTurnstileOnDemand(form(), SRC);
    document.getElementById('name')!.dispatchEvent(new FocusEvent('focusin', { bubbles: true }));
    expect(scripts()).toHaveLength(1);
  });
});
