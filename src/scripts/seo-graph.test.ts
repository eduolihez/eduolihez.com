import { describe, it, expect } from 'vitest';
import { profileDates, shouldEmitProfilePage, buildFaqPage, extractFaqFromHtml } from './seo-graph';

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

describe('buildFaqPage', () => {
  it('sin preguntas no emite nada', () => {
    expect(buildFaqPage('https://x.com/a/', 'https://x.com/#website', 'es', [])).toBeNull();
  });

  it('construye FAQPage con id, idioma y preguntas', () => {
    const n = buildFaqPage('https://x.com/a/', 'https://x.com/#website', 'es', [{ q: 'P1', a: 'R1' }])!;
    expect(n['@type']).toBe('FAQPage');
    expect(n['@id']).toBe('https://x.com/a/#faq');
    expect(n.inLanguage).toBe('es');
    expect(n.mainEntity).toEqual([
      { '@type': 'Question', name: 'P1', acceptedAnswer: { '@type': 'Answer', text: 'R1' } },
    ]);
  });
});

describe('extractFaqFromHtml', () => {
  const html = (h2: string) =>
    `<p>intro</p><h2>${h2}</h2><h3>¿Uno?</h3><p>Resp <strong>uno</strong> &amp; más.</p><p>Otra línea.</p><h3>¿Dos?</h3><p>Resp dos.</p><h2>Otro bloque</h2><h3>No</h3><p>fuera</p>`;

  it('extrae pares pregunta/respuesta y limpia etiquetas y entidades', () => {
    expect(extractFaqFromHtml(html('Preguntas frecuentes'))).toEqual([
      { q: '¿Uno?', a: 'Resp uno & más. Otra línea.' },
      { q: '¿Dos?', a: 'Resp dos.' },
    ]);
  });

  it.each(['Preguntes freqüents', 'Frequently asked questions'])('reconoce el encabezado %s', (h) => {
    expect(extractFaqFromHtml(html(h))).toHaveLength(2);
  });

  it('sin bloque de FAQ devuelve []', () => {
    expect(extractFaqFromHtml('<h2>Otra cosa</h2><h3>x</h3><p>y</p>')).toEqual([]);
  });

  it('ignora preguntas sin respuesta o h3 sin cerrar', () => {
    expect(extractFaqFromHtml('<h2>FAQ</h2><h3>¿Sola?</h3><h3>¿Rota')).toEqual([]);
  });

  it('el último bloque llega hasta el final si no hay otro h2', () => {
    expect(extractFaqFromHtml('<h2>FAQ</h2><h3>¿A?</h3><p>B</p>')).toEqual([{ q: '¿A?', a: 'B' }]);
  });
});
