import { describe, it, expect } from 'vitest';
import { ui } from './ui';
import { useTranslations } from './utils';

// T16: el pie usa el rol localizado (no SITE.jobTitle, en ingles) y el bloque
// de autor del post tiene paridad ES/EN/CA.
describe('ui T16', () => {
  it('hero.role difiere por idioma (el pie no muestra ingles en ES/CA)', () => {
    const es = useTranslations('es')('hero.role');
    const en = useTranslations('en')('hero.role');
    const ca = useTranslations('ca')('hero.role');
    expect(es).toContain('Analista de Ciberseguridad');
    expect(ca).toContain('Analista de Ciberseguretat');
    expect(en).toContain('Cybersecurity Analyst');
  });

  it.each(['post.author.title', 'post.author.body', 'post.author.profile', 'post.author.contact'])(
    'clave %s presente y no vacia en los 3 idiomas',
    (key) => {
      for (const l of ['es', 'en', 'ca'] as const) {
        const v = (ui[l] as Record<string, string>)[key];
        expect(v && v.length).toBeGreaterThan(0);
      }
    },
  );
});
