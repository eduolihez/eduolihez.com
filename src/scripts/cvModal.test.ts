import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CV_OPEN_EVENT, initCvModal } from './cvModal';

const modal = (): HTMLElement => document.getElementById('cv-modal')!;

beforeEach(() => {
  vi.useFakeTimers();
  document.body.style.overflow = '';
  document.body.innerHTML = `
    <button id="hero-btn" type="button" data-cv-open>CV</button>
    <a id="footer-link" href="#cv" data-cv-open><span id="inner">icon</span></a>
    <div id="cv-modal" hidden>
      <div id="panel">
        <button id="cv-modal-close" type="button">x</button>
        <button id="cv-modal-btn-close" type="button">Cerrar</button>
      </div>
    </div>`;
  initCvModal();
});

describe('initCvModal', () => {
  it('opens from any [data-cv-open] trigger, including clicks on a child', () => {
    document.getElementById('inner')!.click();
    expect(modal().hidden).toBe(false);
    expect(modal().classList.contains('open')).toBe(true);
    expect(document.body.style.overflow).toBe('hidden');
  });

  it('cancels the navigation of an anchor trigger', () => {
    const event = new MouseEvent('click', { bubbles: true, cancelable: true });
    document.getElementById('footer-link')!.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
  });

  it('opens on the custom event the command palette dispatches', () => {
    document.dispatchEvent(new CustomEvent(CV_OPEN_EVENT));
    expect(modal().hidden).toBe(false);
  });

  it('moves focus into the dialog and gives it back to the opener on close', () => {
    const opener = document.getElementById('hero-btn')!;
    opener.focus();
    opener.click();
    expect(document.activeElement?.id).toBe('cv-modal-close');

    document.getElementById('cv-modal-btn-close')!.click();
    vi.runAllTimers();
    expect(modal().hidden).toBe(true);
    expect(document.body.style.overflow).toBe('');
    expect(document.activeElement).toBe(opener);
  });

  it('closes with Escape and on a backdrop click, but not on a click inside the panel', () => {
    document.getElementById('hero-btn')!.click();
    document.getElementById('panel')!.click();
    expect(modal().classList.contains('open')).toBe(true);

    modal().dispatchEvent(new MouseEvent('click', { bubbles: true }));
    vi.runAllTimers();
    expect(modal().hidden).toBe(true);

    document.getElementById('hero-btn')!.click();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    vi.runAllTimers();
    expect(modal().hidden).toBe(true);
  });

  it('ignores Escape while the dialog is closed', () => {
    const spy = vi.spyOn(modal().classList, 'remove');
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(spy).not.toHaveBeenCalled();
  });

  it('binds only once when called again', () => {
    initCvModal();
    const opener = document.getElementById('hero-btn')!;
    opener.click();
    document.getElementById('cv-modal-close')!.click();
    vi.runAllTimers();
    expect(modal().hidden).toBe(true);
  });

  it('does nothing on a page without the dialog', () => {
    document.body.innerHTML = '<button data-cv-open>CV</button>';
    expect(() => initCvModal()).not.toThrow();
  });
});
