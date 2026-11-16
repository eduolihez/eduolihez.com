import { describe, it, expect } from 'vitest';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { evidence, validateEvidence, type Evidence } from '../config';

const inPublic = (p: string) => existsSync(join(process.cwd(), 'public', p));
const ok: Evidence = { id: 'E-01', kind: 'file', label: 'x', href: '/a.pdf' };

describe('evidence (datos reales)', () => {
  it('es valida: ids unicos, rutas locales en public/, externas https', () => {
    expect(validateEvidence(evidence, inPublic)).toEqual([]);
  });
  it('tiene E-01..E-04 en orden', () => {
    expect(evidence.map((e) => e.id)).toEqual(['E-01', 'E-02', 'E-03', 'E-04']);
  });
});

describe('validateEvidence (ramas de fallo)', () => {
  const yes = () => true;
  it('acepta una entrada valida', () => {
    expect(validateEvidence([ok], yes)).toEqual([]);
  });
  it('detecta id con formato invalido', () => {
    expect(validateEvidence([{ ...ok, id: 'X-1' }], yes)).toHaveLength(1);
  });
  it('detecta ids duplicados', () => {
    expect(validateEvidence([ok, ok], yes)).toEqual(['E-01: id duplicado']);
  });
  it('detecta label vacio', () => {
    expect(validateEvidence([{ ...ok, label: '' }], yes)).toEqual(['E-01: falta label']);
  });
  it('detecta href vacio', () => {
    expect(validateEvidence([{ ...ok, href: '' }], yes)).toEqual(['E-01: falta href']);
  });
  it('detecta ruta local inexistente y decodifica %20', () => {
    const seen: string[] = [];
    const errs = validateEvidence([{ ...ok, href: '/a%20b.pdf' }], (p) => (seen.push(p), false));
    expect(seen).toEqual(['/a b.pdf']);
    expect(errs).toEqual(['E-01: no existe /a%20b.pdf']);
  });
  it('detecta href externo no https', () => {
    expect(validateEvidence([{ ...ok, href: 'http://x.com' }], yes)).toEqual([
      'E-01: href externo debe ser https',
    ]);
  });
});
