import { describe, it, expect } from 'vitest';
import { profileDates, shouldEmitProfilePage } from './seo-graph';

describe('profileDates', () => {
  // ISO 8601 con hora y zona: lo que Google acepta (la fecha sola da aviso).
  const iso = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;

  it('dateCreated y dateModified llevan fecha, hora y zona', () => {
    const d = profileDates(new Date('2026-11-15T10:20:30Z'));
    expect(d.dateCreated).toMatch(iso);
    expect(d.dateModified).toMatch(iso);
  });

  it('dateModified refleja el instante recibido', () => {
    expect(profileDates(new Date('2026-11-15T10:20:30Z')).dateModified).toBe('2026-11-15T10:20:30.000Z');
  });

  it('sin argumento usa la hora actual y sigue siendo valida', () => {
    expect(profileDates().dateModified).toMatch(iso);
  });
});

describe('shouldEmitProfilePage', () => {
  it('por defecto solo en la portada', () => {
    expect(shouldEmitProfilePage(undefined, '/', '/')).toBe(true);
    expect(shouldEmitProfilePage(undefined, '/en/', '/en/')).toBe(true);
  });

  it('no en posts ni en otras paginas', () => {
    expect(shouldEmitProfilePage(undefined, '/blog/post/algo/', '/')).toBe(false);
    expect(shouldEmitProfilePage(undefined, '/projects/zeora/', '/')).toBe(false);
  });

  it('profile=true lo fuerza en una pagina de perfil', () => {
    expect(shouldEmitProfilePage(true, '/analista-soc-barcelona/', '/')).toBe(true);
  });

  it('profile=false lo impide incluso en la portada', () => {
    expect(shouldEmitProfilePage(false, '/', '/')).toBe(false);
  });
});
