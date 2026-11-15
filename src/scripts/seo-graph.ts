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
