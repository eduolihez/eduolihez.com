import { beforeEach, describe, expect, it } from 'vitest';
import { filterCommands, initPalette, normalize, type PaletteCommand } from './palette';

const COMMANDS: PaletteCommand[] = [
  { id: 'projects', label: 'Proyectos', group: 'Navegar', href: '/#proyectos' },
  { id: 'blog', label: 'Blog', group: 'Navegar', href: '/blog/', keywords: 'articulos escritos' },
  { id: 'contact', label: 'Contacto', group: 'Navegar', href: '/#contacto' },
  { id: 'ca', label: 'Català', group: 'Idioma', href: '/ca/', keywords: 'catalan idioma' },
  { id: 'theme-dark', label: 'Tema oscuro', group: 'Acciones', action: 'theme-dark' },
  { id: 'theme-system', label: 'Tema del sistema', group: 'Acciones', action: 'theme-system' },
];

describe('normalize', () => {
  it('lowercases and strips accents', () => {
    expect(normalize('  Català  ÁÉÍÓÚ ')).toBe('catala aeiou');
  });
});

describe('filterCommands', () => {
  it('returns every command, in order, for an empty query', () => {
    expect(filterCommands(COMMANDS, '').map((c) => c.id)).toEqual(COMMANDS.map((c) => c.id));
    expect(filterCommands(COMMANDS, '   ').length).toBe(COMMANDS.length);
  });

  it('matches without accents or case', () => {
    expect(filterCommands(COMMANDS, 'CATALA').map((c) => c.id)).toEqual(['ca']);
  });

  it('matches against keywords, not only the label', () => {
    expect(filterCommands(COMMANDS, 'articulos').map((c) => c.id)).toEqual(['blog']);
  });

  it('ranks a label prefix above a mid-label match', () => {
    const ids = filterCommands(COMMANDS, 'tema').map((c) => c.id);
    expect(ids.slice(0, 2).sort()).toEqual(['theme-dark', 'theme-system']);
  });

  it('ranks label matches above keyword-only matches', () => {
    const cmds: PaletteCommand[] = [
      { id: 'a', label: 'Otra cosa', group: 'x', keywords: 'blog' },
      { id: 'b', label: 'Blog', group: 'x' },
    ];
    expect(filterCommands(cmds, 'blog').map((c) => c.id)).toEqual(['b', 'a']);
  });

  it('returns nothing when nothing matches', () => {
    expect(filterCommands(COMMANDS, 'zzzz')).toEqual([]);
  });

  it('does not mutate the input array', () => {
    const copy = [...COMMANDS];
    filterCommands(COMMANDS, 'tema');
    expect(COMMANDS).toEqual(copy);
  });
});

function mountPalette(commands: PaletteCommand[] = COMMANDS): void {
  document.body.innerHTML = `
    <button type="button" data-palette-open>Abrir</button>
    <div data-palette hidden role="dialog" aria-modal="true" aria-label="Paleta"
         data-commands='${JSON.stringify(commands)}' data-empty="Sin resultados">
      <input data-palette-input role="combobox" aria-expanded="true" aria-controls="pl" />
      <ul id="pl" data-palette-list role="listbox"></ul>
      <p data-palette-empty hidden></p>
    </div>`;
}

function press(key: string, opts: KeyboardEventInit = {}): void {
  document.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, ...opts }));
}

const root = (): HTMLElement => document.querySelector<HTMLElement>('[data-palette]')!;
const input = (): HTMLInputElement => document.querySelector<HTMLInputElement>('[data-palette-input]')!;
const options = (): HTMLElement[] => [...document.querySelectorAll<HTMLElement>('[role="option"]')];

beforeEach(() => {
  document.documentElement.removeAttribute('data-theme');
  localStorage.clear();
  mountPalette();
  initPalette();
});

describe('initPalette — opening and closing', () => {
  it('opens with Ctrl+K and focuses the input', () => {
    expect(root().hidden).toBe(true);
    press('k', { ctrlKey: true });
    expect(root().hidden).toBe(false);
    expect(document.activeElement).toBe(input());
  });

  it('opens with Cmd+K', () => {
    press('k', { metaKey: true });
    expect(root().hidden).toBe(false);
  });

  it('does not open on a bare "k" press', () => {
    press('k');
    expect(root().hidden).toBe(true);
  });

  it('opens from the trigger button', () => {
    document.querySelector<HTMLButtonElement>('[data-palette-open]')!.click();
    expect(root().hidden).toBe(false);
  });

  it('closes with Escape and returns focus to the opener', () => {
    const opener = document.querySelector<HTMLButtonElement>('[data-palette-open]')!;
    opener.focus();
    opener.click();
    press('Escape');
    expect(root().hidden).toBe(true);
    expect(document.activeElement).toBe(opener);
  });

  it('closes when the backdrop (the dialog root) is clicked', () => {
    press('k', { ctrlKey: true });
    root().click();
    expect(root().hidden).toBe(true);
  });

  it('toggles closed on a second Ctrl+K', () => {
    press('k', { ctrlKey: true });
    press('k', { ctrlKey: true });
    expect(root().hidden).toBe(true);
  });
});

describe('initPalette — listing and filtering', () => {
  it('renders one option per command with the first one selected', () => {
    press('k', { ctrlKey: true });
    expect(options().length).toBe(COMMANDS.length);
    expect(options()[0].getAttribute('aria-selected')).toBe('true');
    expect(input().getAttribute('aria-activedescendant')).toBe(options()[0].id);
  });

  it('filters as the user types', () => {
    press('k', { ctrlKey: true });
    input().value = 'catala';
    input().dispatchEvent(new Event('input', { bubbles: true }));
    expect(options().map((o) => o.textContent)).toEqual([expect.stringContaining('Català')]);
  });

  it('shows the empty message when nothing matches', () => {
    press('k', { ctrlKey: true });
    input().value = 'zzzz';
    input().dispatchEvent(new Event('input', { bubbles: true }));
    expect(options().length).toBe(0);
    expect(document.querySelector<HTMLElement>('[data-palette-empty]')!.hidden).toBe(false);
    expect(document.querySelector('[data-palette-empty]')!.textContent).toBe('Sin resultados');
  });

  it('renders commands with textContent, never as HTML', () => {
    document.body.innerHTML = '';
    mountPalette([{ id: 'x', label: '<img src=x onerror=alert(1)>', group: 'g', href: '/' }]);
    initPalette();
    press('k', { ctrlKey: true });
    expect(document.querySelector('[data-palette-list] img')).toBeNull();
  });

  it('resets the query every time it opens', () => {
    press('k', { ctrlKey: true });
    input().value = 'blog';
    input().dispatchEvent(new Event('input', { bubbles: true }));
    press('Escape');
    press('k', { ctrlKey: true });
    expect(input().value).toBe('');
    expect(options().length).toBe(COMMANDS.length);
  });
});

describe('initPalette — keyboard selection', () => {
  it('moves the selection with ArrowDown/ArrowUp and wraps around', () => {
    press('k', { ctrlKey: true });
    press('ArrowDown');
    expect(options()[1].getAttribute('aria-selected')).toBe('true');
    press('ArrowUp');
    press('ArrowUp');
    expect(options()[COMMANDS.length - 1].getAttribute('aria-selected')).toBe('true');
  });

  it('runs an action command on Enter and closes', () => {
    press('k', { ctrlKey: true });
    input().value = 'oscuro';
    input().dispatchEvent(new Event('input', { bubbles: true }));
    press('Enter');
    expect(document.documentElement.dataset.theme).toBe('dark');
    expect(root().hidden).toBe(true);
  });

  it('clicks the link for a navigation command on Enter', () => {
    press('k', { ctrlKey: true });
    const anchor = options()[0] as HTMLAnchorElement;
    let clicked = false;
    anchor.addEventListener('click', (e) => {
      clicked = true;
      e.preventDefault();
    });
    press('Enter');
    expect(clicked).toBe(true);
  });

  it('runs the "system" theme action, clearing data-theme', () => {
    document.documentElement.dataset.theme = 'dark';
    press('k', { ctrlKey: true });
    input().value = 'sistema';
    input().dispatchEvent(new Event('input', { bubbles: true }));
    press('Enter');
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });
});

describe('initPalette — robustness', () => {
  it('does nothing when the page has no palette', () => {
    document.body.innerHTML = '';
    expect(() => initPalette()).not.toThrow();
  });

  it('survives malformed command JSON', () => {
    document.body.innerHTML = '';
    mountPalette();
    root().setAttribute('data-commands', '{not json');
    expect(() => initPalette()).not.toThrow();
    press('k', { ctrlKey: true });
    expect(options().length).toBe(0);
  });
});
