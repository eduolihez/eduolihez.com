/**
 * Paleta de comandos (Ctrl/Cmd+K). Navegar, cambiar de tema o de idioma sin
 * ratón. Los comandos llegan ya traducidos desde Palette.astro en el atributo
 * data-commands; aquí solo hay filtrado, teclado y accesibilidad (patrón
 * combobox + listbox con aria-activedescendant).
 *
 * Todo el texto se escribe con textContent: nada de lo que viene del atributo
 * se interpreta como HTML.
 */
import { setTheme, type ThemePreference } from './theme';

export type PaletteAction = 'theme-light' | 'theme-dark' | 'theme-system';

export interface PaletteCommand {
  id: string;
  label: string;
  group: string;
  /** Texto extra por el que también se puede buscar (sinónimos). */
  keywords?: string;
  /** Texto secundario a la derecha (ruta, atajo...). */
  hint?: string;
  href?: string;
  external?: boolean;
  action?: PaletteAction;
}

const ACTION_THEME: Record<PaletteAction, ThemePreference> = {
  'theme-light': 'light',
  'theme-dark': 'dark',
  'theme-system': 'system',
};

/** Minúsculas y sin diacríticos: "Català" y "catala" son lo mismo al buscar. */
export function normalize(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

const SCORE_LABEL_PREFIX = 4;
const SCORE_WORD_PREFIX = 3;
const SCORE_LABEL_INCLUDES = 2;
const SCORE_KEYWORD = 1;

function score(cmd: PaletteCommand, q: string): number {
  const label = normalize(cmd.label);
  if (label.startsWith(q)) return SCORE_LABEL_PREFIX;
  if (label.split(/\s+/).some((word) => word.startsWith(q))) return SCORE_WORD_PREFIX;
  if (label.includes(q)) return SCORE_LABEL_INCLUDES;
  if (normalize(`${cmd.keywords ?? ''} ${cmd.group}`).includes(q)) return SCORE_KEYWORD;
  return 0;
}

/** Filtra y ordena por relevancia (estable: a igual puntuación, orden original). */
export function filterCommands(commands: PaletteCommand[], query: string): PaletteCommand[] {
  const q = normalize(query);
  if (!q) return [...commands];
  return commands
    .map((cmd, index) => ({ cmd, index, s: score(cmd, q) }))
    .filter((r) => r.s > 0)
    .sort((a, b) => b.s - a.s || a.index - b.index)
    .map((r) => r.cmd);
}

function parseCommands(raw: string | undefined): PaletteCommand[] {
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as PaletteCommand[]) : [];
  } catch {
    return [];
  }
}

// Una sola instancia viva: reiniciar (astro:page-load) suelta los listeners
// del documento de la anterior en vez de acumularlos.
let teardown: AbortController | null = null;

export function initPalette(): void {
  teardown?.abort();
  teardown = null;

  const root = document.querySelector<HTMLElement>('[data-palette]');
  const input = root?.querySelector<HTMLInputElement>('[data-palette-input]');
  const list = root?.querySelector<HTMLElement>('[data-palette-list]');
  const empty = root?.querySelector<HTMLElement>('[data-palette-empty]');
  if (!root || !input || !list || !empty) return;

  const controller = new AbortController();
  teardown = controller;
  const { signal } = controller;

  const all = parseCommands(root.dataset.commands);
  let visible: PaletteCommand[] = [];
  let selected = 0;
  let opener: HTMLElement | null = null;

  function setSelected(next: number): void {
    const items = list!.querySelectorAll<HTMLElement>('[role="option"]');
    if (items.length === 0) {
      input!.removeAttribute('aria-activedescendant');
      return;
    }
    selected = (next + items.length) % items.length;
    items.forEach((el, i) => el.setAttribute('aria-selected', String(i === selected)));
    input!.setAttribute('aria-activedescendant', items[selected].id);
    items[selected].scrollIntoView({ block: 'nearest' });
  }

  function render(query: string): void {
    visible = filterCommands(all, query);
    list!.replaceChildren();
    empty!.hidden = visible.length > 0;
    empty!.textContent = empty!.hidden ? '' : (root!.dataset.empty ?? '');

    let lastGroup = '';
    visible.forEach((cmd, i) => {
      if (cmd.group !== lastGroup) {
        lastGroup = cmd.group;
        const heading = document.createElement('li');
        heading.setAttribute('role', 'presentation');
        heading.className = 'palette-group';
        heading.textContent = cmd.group;
        list!.append(heading);
      }
      const li = document.createElement('li');
      li.setAttribute('role', 'presentation');
      const el = document.createElement(cmd.action ? 'button' : 'a');
      el.id = `palette-opt-${i}`;
      el.className = 'palette-option';
      el.setAttribute('role', 'option');
      el.tabIndex = -1;
      if (el instanceof HTMLAnchorElement && cmd.href) {
        el.href = cmd.href;
        if (cmd.external) {
          el.target = '_blank';
          el.rel = 'noopener noreferrer';
        }
      } else if (el instanceof HTMLButtonElement) {
        el.type = 'button';
      }
      const label = document.createElement('span');
      label.textContent = cmd.label;
      el.append(label);
      if (cmd.hint) {
        const hint = document.createElement('span');
        hint.className = 'palette-hint';
        hint.textContent = cmd.hint;
        el.append(hint);
      }
      el.addEventListener('click', () => run(cmd));
      el.addEventListener('mousemove', () => {
        if (selected !== i) setSelected(i);
      });
      li.append(el);
      list!.append(li);
    });
    setSelected(0);
  }

  function run(cmd: PaletteCommand): void {
    if (cmd.action) setTheme(ACTION_THEME[cmd.action]);
    close(!cmd.href);
  }

  function open(): void {
    opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    root!.hidden = false;
    document.body.style.overflow = 'hidden';
    input!.value = '';
    render('');
    input!.focus();
  }

  function close(restoreFocus = true): void {
    root!.hidden = true;
    document.body.style.overflow = '';
    if (restoreFocus) opener?.focus();
  }

  function activateSelected(): void {
    const el = list!.querySelectorAll<HTMLElement>('[role="option"]')[selected];
    // click() deja que el navegador navegue (o ejecute la acción) por el camino normal.
    el?.click();
  }

  input.addEventListener('input', () => render(input.value), { signal });
  root.addEventListener(
    'click',
    (e) => {
      if (e.target === root) close();
    },
    { signal },
  );

  document.querySelectorAll<HTMLElement>('[data-palette-open]').forEach((btn) =>
    btn.addEventListener('click', open, { signal }),
  );

  document.addEventListener(
    'keydown',
    (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        if (root.hidden) open();
        else close();
        return;
      }
      if (root.hidden) return;
      if (e.key === 'Escape') {
        e.preventDefault();
        close();
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelected(selected + 1);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelected(selected - 1);
      } else if (e.key === 'Enter') {
        e.preventDefault();
        activateSelected();
      } else if (e.key === 'Tab') {
        // El foco no sale de la paleta: el único destino útil es el campo.
        e.preventDefault();
        input.focus();
      }
    },
    { signal },
  );
}
