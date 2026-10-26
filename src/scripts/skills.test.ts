import { beforeEach, describe, expect, it } from 'vitest';
import { initSkillsModal } from './skills';

function mount(): void {
  document.body.innerHTML = `
    <button type="button" data-skills-open>Habilidades</button>
    <div data-skills-modal hidden role="dialog" aria-modal="true" aria-labelledby="t">
      <h3 id="t">Todas</h3>
      <button type="button" data-skills-close>Cerrar</button>
      <a href="#x" data-skills-link>enlace</a>
    </div>`;
}
const modal = (): HTMLElement => document.querySelector<HTMLElement>('[data-skills-modal]')!;
const opener = (): HTMLButtonElement => document.querySelector<HTMLButtonElement>('[data-skills-open]')!;
const press = (key: string): void => {
  document.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true }));
};

beforeEach(() => {
  document.body.style.overflow = '';
  mount();
  initSkillsModal();
});

describe('initSkillsModal', () => {
  it('opens from the trigger, locks scroll and focuses the close button', () => {
    opener().click();
    expect(modal().hidden).toBe(false);
    expect(opener().getAttribute('aria-expanded')).toBe('true');
    expect(document.body.style.overflow).toBe('hidden');
    expect(document.activeElement).toBe(document.querySelector('[data-skills-close]'));
  });

  it('closes with the close button and returns focus to the trigger', () => {
    opener().focus();
    opener().click();
    document.querySelector<HTMLButtonElement>('[data-skills-close]')!.click();
    expect(modal().hidden).toBe(true);
    expect(opener().getAttribute('aria-expanded')).toBe('false');
    expect(document.body.style.overflow).toBe('');
    expect(document.activeElement).toBe(opener());
  });

  it('closes with Escape', () => {
    opener().click();
    press('Escape');
    expect(modal().hidden).toBe(true);
  });

  it('closes when the backdrop (the dialog root) is clicked, not its content', () => {
    opener().click();
    modal().querySelector<HTMLElement>('h3')!.click();
    expect(modal().hidden).toBe(false);
    modal().click();
    expect(modal().hidden).toBe(true);
  });

  it('ignores Escape while closed', () => {
    press('Escape');
    expect(modal().hidden).toBe(true);
  });

  it('keeps focus inside the dialog on Tab', () => {
    opener().click();
    const links = [...modal().querySelectorAll<HTMLElement>('button, a')];
    links[links.length - 1].focus();
    const ev = new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true });
    document.dispatchEvent(ev);
    expect(ev.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(links[0]);
  });

  it('does not stack listeners when initialised twice', () => {
    initSkillsModal();
    opener().click();
    press('Escape');
    expect(modal().hidden).toBe(true);
  });

  it('does nothing when the page has no skills modal', () => {
    document.body.innerHTML = '';
    expect(() => initSkillsModal()).not.toThrow();
  });

  it('pulls focus back into the dialog when Tab is pressed from outside it', () => {
    opener().click();
    (document.activeElement as HTMLElement).blur();
    const ev = new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true });
    document.dispatchEvent(ev);
    expect(ev.defaultPrevented).toBe(true);
    expect(modal().contains(document.activeElement)).toBe(true);
  });

  it('leaves Escape to the command palette when it is open on top', () => {
    document.body.insertAdjacentHTML('beforeend', '<div data-palette></div>');
    opener().click();
    press('Escape');
    expect(modal().hidden).toBe(false);
  });
});
