import { describe, expect, it } from 'vitest';
import { metaDescription, postTitle, TITLE_MAX, DESCRIPTION_MAX } from './seoText';

describe('postTitle', () => {
  it('keeps "| Blog | site" when the whole title fits', () => {
    expect(postTitle('Priorizar CVEs sin fiarse del CVSS', 'Edu Olivares')).toBe(
      'Priorizar CVEs sin fiarse del CVSS | Blog | Edu Olivares',
    );
  });

  it('drops the "Blog" segment first when it would overflow', () => {
    const title = 'SPF, DKIM y DMARC: de p=none a p=reject';
    const out = postTitle(title, 'Edu Olivares');
    expect(out).toBe(`${title} | Edu Olivares`);
    expect(out.length).toBeLessThanOrEqual(TITLE_MAX);
  });

  it('uses the bare headline when even the brand does not fit', () => {
    const title = 'Hardening de FortiGate: lo que reviso antes de dar un despliegue por bueno';
    expect(postTitle(title, 'Edu Olivares')).toBe(title);
  });
});

describe('metaDescription', () => {
  it('returns short text untouched (trimmed)', () => {
    expect(metaDescription('  Auditoría básica de permisos.  ')).toBe('Auditoría básica de permisos.');
  });

  it('cuts long text on a word boundary and adds an ellipsis', () => {
    const long =
      'kev-digest comprueba el catalogo CISA KEV cada tres horas, detecta que ha cambiado y publica el resultado, todo sobre GitHub Actions y sin una sola dependencia externa. Como esta montado.';
    const out = metaDescription(long);
    expect(out.length).toBeLessThanOrEqual(DESCRIPTION_MAX);
    expect(out.endsWith('…')).toBe(true);
    expect(long.startsWith(out.slice(0, -1))).toBe(true);
    expect(out.slice(0, -1)).not.toMatch(/[\s,;:]$/);
  });

  it('collapses internal whitespace and newlines', () => {
    expect(metaDescription('uno\n  dos\t tres')).toBe('uno dos tres');
  });

  it('hard-cuts a single word longer than the limit', () => {
    const out = metaDescription('a'.repeat(400));
    expect(out).toHaveLength(DESCRIPTION_MAX);
  });
});
