import { beforeEach, describe, expect, it } from 'vitest';
import {
  THEME_STORAGE_KEY,
  applyTheme,
  effectiveTheme,
  getStoredTheme,
  initThemeToggle,
  setTheme,
  toggleTheme,
} from './theme';

function mockSystemDark(dark: boolean): void {
  window.matchMedia = ((query: string) =>
    ({
      matches: query.includes('dark') ? dark : false,
      media: query,
      addEventListener: () => {},
      removeEventListener: () => {},
    }) as unknown as MediaQueryList) as typeof window.matchMedia;
}

beforeEach(() => {
  localStorage.clear();
  document.documentElement.removeAttribute('data-theme');
  document.head.innerHTML = '<meta name="theme-color" content="#000000">';
  document.body.innerHTML = '';
  mockSystemDark(false);
});

describe('getStoredTheme', () => {
  it('returns "system" when nothing is stored', () => {
    expect(getStoredTheme()).toBe('system');
  });

  it('returns the stored explicit choice', () => {
    localStorage.setItem(THEME_STORAGE_KEY, 'dark');
    expect(getStoredTheme()).toBe('dark');
  });

  it('ignores unknown stored values', () => {
    localStorage.setItem(THEME_STORAGE_KEY, 'purple');
    expect(getStoredTheme()).toBe('system');
  });

  it('falls back to "system" when storage throws', () => {
    const original = Storage.prototype.getItem;
    Storage.prototype.getItem = () => {
      throw new Error('blocked');
    };
    try {
      expect(getStoredTheme()).toBe('system');
    } finally {
      Storage.prototype.getItem = original;
    }
  });
});

describe('effectiveTheme', () => {
  it('follows the system when the preference is "system"', () => {
    mockSystemDark(true);
    expect(effectiveTheme('system')).toBe('dark');
    mockSystemDark(false);
    expect(effectiveTheme('system')).toBe('light');
  });

  it('ignores the system when the choice is explicit', () => {
    mockSystemDark(true);
    expect(effectiveTheme('light')).toBe('light');
    mockSystemDark(false);
    expect(effectiveTheme('dark')).toBe('dark');
  });
});

describe('applyTheme', () => {
  it('sets data-theme for explicit choices', () => {
    applyTheme('dark');
    expect(document.documentElement.dataset.theme).toBe('dark');
  });

  it('removes data-theme for "system" so CSS follows prefers-color-scheme', () => {
    document.documentElement.dataset.theme = 'dark';
    applyTheme('system');
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });

  it('updates the theme-color meta to match the effective theme', () => {
    applyTheme('dark');
    const dark = document.querySelector('meta[name="theme-color"]')?.getAttribute('content');
    applyTheme('light');
    const light = document.querySelector('meta[name="theme-color"]')?.getAttribute('content');
    expect(dark).not.toBe(light);
  });
});

describe('setTheme', () => {
  it('persists an explicit choice and applies it', () => {
    setTheme('dark');
    expect(localStorage.getItem(THEME_STORAGE_KEY)).toBe('dark');
    expect(document.documentElement.dataset.theme).toBe('dark');
  });

  it('clears the stored value when going back to "system"', () => {
    setTheme('dark');
    setTheme('system');
    expect(localStorage.getItem(THEME_STORAGE_KEY)).toBeNull();
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });

  it('still applies the theme when storage throws', () => {
    const original = Storage.prototype.setItem;
    Storage.prototype.setItem = () => {
      throw new Error('quota');
    };
    try {
      setTheme('dark');
      expect(document.documentElement.dataset.theme).toBe('dark');
    } finally {
      Storage.prototype.setItem = original;
    }
  });
});

describe('toggleTheme', () => {
  it('flips from the effective light theme to dark', () => {
    mockSystemDark(false);
    expect(toggleTheme()).toBe('dark');
    expect(getStoredTheme()).toBe('dark');
  });

  it('flips from the effective dark theme (system) to light', () => {
    mockSystemDark(true);
    expect(toggleTheme()).toBe('light');
    expect(getStoredTheme()).toBe('light');
  });

  it('flips an explicit choice', () => {
    setTheme('dark');
    expect(toggleTheme()).toBe('light');
  });
});

describe('initThemeToggle', () => {
  it('toggles on click and reflects state in aria-pressed', () => {
    document.body.innerHTML = '<button data-theme-toggle aria-pressed="false"></button>';
    mockSystemDark(false);
    initThemeToggle();
    const btn = document.querySelector<HTMLButtonElement>('[data-theme-toggle]')!;
    btn.click();
    expect(document.documentElement.dataset.theme).toBe('dark');
    expect(btn.getAttribute('aria-pressed')).toBe('true');
    btn.click();
    expect(document.documentElement.dataset.theme).toBe('light');
    expect(btn.getAttribute('aria-pressed')).toBe('false');
  });

  it('is idempotent: re-initialising does not double the click handler', () => {
    document.body.innerHTML = '<button data-theme-toggle aria-pressed="false"></button>';
    mockSystemDark(false);
    initThemeToggle();
    initThemeToggle();
    document.querySelector<HTMLButtonElement>('[data-theme-toggle]')!.click();
    expect(document.documentElement.dataset.theme).toBe('dark');
  });

  it('does nothing when there is no toggle in the page', () => {
    expect(() => initThemeToggle()).not.toThrow();
  });
});
