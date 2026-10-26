import { describe, it, expect } from 'vitest';
import { POST_TRANSLATIONS_CA, caSlugFor, esSlugFor, postAlternates } from './postTranslations';

describe('POST_TRANSLATIONS_CA', () => {
  it('no repite slugs catalanes (la relacion es 1 a 1)', () => {
    const ca = Object.values(POST_TRANSLATIONS_CA);
    expect(new Set(ca).size).toBe(ca.length);
  });

  it('usa slugs validos para una URL (minusculas, digitos y guiones)', () => {
    for (const [es, ca] of Object.entries(POST_TRANSLATIONS_CA)) {
      expect(es).toMatch(/^[a-z0-9-]+$/);
      expect(ca).toMatch(/^[a-z0-9-]+$/);
    }
  });
});

describe('caSlugFor / esSlugFor', () => {
  it('traduce en los dos sentidos', () => {
    const [es, ca] = Object.entries(POST_TRANSLATIONS_CA)[0];
    expect(caSlugFor(es)).toBe(ca);
    expect(esSlugFor(ca)).toBe(es);
  });

  it('devuelve undefined si el articulo no tiene traduccion', () => {
    expect(caSlugFor('no-existe')).toBeUndefined();
    expect(esSlugFor('no-existe')).toBeUndefined();
  });
});

describe('postAlternates', () => {
  const es = 'joiner-mover-leaver-cuentas-huerfanas';
  const ca = 'joiner-mover-leaver-comptes-orfes';

  it('desde el articulo ES declara es y ca cuando la version catalana esta publicada', () => {
    expect(postAlternates('es', es, new Set([ca]))).toEqual({
      es: `/blog/post/${es}/`,
      ca: `/ca/blog/post/${ca}/`,
    });
  });

  it('NO declara alternos si la version catalana todavia no esta publicada', () => {
    expect(postAlternates('es', es, new Set())).toBeUndefined();
  });

  it('desde el articulo CA declara es y ca', () => {
    expect(postAlternates('ca', ca, new Set([ca]))).toEqual({
      es: `/blog/post/${es}/`,
      ca: `/ca/blog/post/${ca}/`,
    });
  });

  it('no declara alternos para un articulo sin traduccion', () => {
    expect(postAlternates('es', 'sin-traduccion', new Set([ca]))).toBeUndefined();
    expect(postAlternates('ca', 'sense-traduccio', new Set([ca]))).toBeUndefined();
  });
});
