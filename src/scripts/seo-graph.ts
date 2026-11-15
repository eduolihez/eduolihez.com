/**
 * Fechas de ProfilePage en ISO 8601 completo (fecha + hora + zona).
 * Google Search Console marca "Invalid datetime value" si solo llevan la fecha
 * (2026-11-14), asi que dateCreated se fija con su zona horaria y dateModified
 * sale del instante del build en UTC.
 */
export function profileDates(now: Date = new Date()): { dateCreated: string; dateModified: string } {
  return {
    // Primer commit del repositorio (verano: CEST, +02:00).
    dateCreated: '2026-07-25T00:00:00+02:00',
    dateModified: now.toISOString(),
  };
}

/**
 * Decide si una pagina lleva el nodo ProfilePage en su JSON-LD.
 *
 * Google reserva ProfilePage para paginas cuyo tema principal es una persona.
 * Por defecto solo las portadas (es/en/ca); cualquier otra pagina (posts,
 * proyectos, "sobre esta web") no debe declararlo. Una pagina de perfil
 * concreta, como la de analista SOC, lo activa con `profile: true`.
 */
export function shouldEmitProfilePage(
  profile: boolean | undefined,
  path: string,
  homePath: string,
): boolean {
  return profile ?? path === homePath;
}

/**
 * Nodo FAQPage de JSON-LD a partir de preguntas ya resueltas a un idioma.
 * Devuelve null si no hay preguntas (un FAQPage vacio es invalido).
 */
export function buildFaqPage(
  canonical: string,
  siteId: string,
  lang: string,
  items: { q: string; a: string }[],
): Record<string, unknown> | null {
  if (items.length === 0) return null;
  return {
    '@type': 'FAQPage',
    '@id': `${canonical}#faq`,
    inLanguage: lang,
    isPartOf: { '@id': siteId },
    mainEntity: items.map((i) => ({
      '@type': 'Question',
      name: i.q,
      acceptedAnswer: { '@type': 'Answer', text: i.a },
    })),
  };
}

const FAQ_HEADING = /<h2[^>]*>\s*(preguntas frecuentes|preguntes freq[uü]ents|frequently asked questions|faq)\s*<\/h2>/i;

function plainText(html: string): string {
  return html
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;|&apos;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Saca las preguntas del bloque "Preguntas frecuentes" de un articulo (HTML
 * del cuerpo): tras ese <h2>, cada <h3> es una pregunta y los parrafos/listas
 * hasta el siguiente <h3>/<h2> son su respuesta. Solo devuelve pares completos,
 * es decir, lo que el lector ve en la pagina.
 */
export function extractFaqFromHtml(html: string): { q: string; a: string }[] {
  const m = FAQ_HEADING.exec(html);
  if (!m) return [];
  let rest = html.slice(m.index + m[0].length);
  const nextH2 = rest.search(/<h2[\s>]/i);
  if (nextH2 >= 0) rest = rest.slice(0, nextH2);
  const out: { q: string; a: string }[] = [];
  const parts = rest.split(/<h3[^>]*>/i).slice(1);
  for (const part of parts) {
    const end = part.search(/<\/h3>/i);
    if (end < 0) continue;
    const q = plainText(part.slice(0, end));
    const a = plainText(part.slice(end + 5));
    if (q && a) out.push({ q, a });
  }
  return out;
}
