import { describe, it, expect } from 'vitest';
import { privacyMeta, privacyPaths, privacySections, PRIVACY_UPDATED } from './privacy';

const LANGS = ['es', 'en', 'ca'] as const;

describe('privacy data', () => {
  it('la fecha de revision es ISO YYYY-MM-DD y valida', () => {
    expect(PRIVACY_UPDATED).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(Number.isNaN(new Date(PRIVACY_UPDATED).getTime())).toBe(false);
  });

  it('cada idioma tiene su ruta con barra final', () => {
    expect(privacyPaths).toEqual({ es: '/privacy/', en: '/en/privacy/', ca: '/ca/privacitat/' });
  });

  it('la meta esta completa en los tres idiomas', () => {
    for (const key of Object.keys(privacyMeta) as (keyof typeof privacyMeta)[]) {
      for (const l of LANGS) expect(privacyMeta[key][l].trim(), `${key}.${l}`).not.toBe('');
    }
  });

  it('la description cabe en un snippet (<= 200 caracteres)', () => {
    for (const l of LANGS) expect(privacyMeta.description[l].length).toBeLessThanOrEqual(200);
  });

  it('ids unicos y cada seccion traducida en es/en/ca', () => {
    const ids = privacySections.map((s) => s.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const s of privacySections) {
      expect(s.body?.length || s.list?.length, s.id).toBeGreaterThan(0);
      for (const l of LANGS) {
        expect(s.title[l].trim(), `${s.id}.title.${l}`).not.toBe('');
        for (const p of [...(s.body ?? []), ...(s.list ?? [])]) {
          expect(p[l].trim(), `${s.id}.${l}`).not.toBe('');
        }
      }
    }
  });

  it('existe la seccion #cookies a la que enlazan el banner y el pie', () => {
    expect(privacySections.some((s) => s.id === 'cookies')).toBe(true);
  });

  it('el plazo de conservacion declarado coincide con el purgado del servidor (400 dias)', () => {
    const cons = privacySections.find((s) => s.id === 'conservacion')!;
    for (const l of LANGS) expect(cons.list![0][l]).toContain('400');
  });
});
