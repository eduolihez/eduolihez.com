/**
 * certifications.ts - Trae las certificaciones desde /api/certifications.php
 * EN BUILD TIME. Mismo motivo que src/lib/projects.ts: solo para rellenar el
 * primer pintado de <Certifications /> antes de que initCerts() reconstruya
 * la cuadricula completa (agrupada por emisor, con buscador y paginacion) al
 * cargar. Fallo en build = array vacio, nunca build roto.
 */
import { SITE } from '../config';
import type { Lang } from '../i18n/ui';
import { fetchJsonSoft } from './buildFetch';

export interface CertificationSummary {
  name?: string;
  issuer?: string;
  category?: string;
  credential_url?: string;
  logo_url?: string;
  issue_date?: string;
}

export async function fetchCertificationSummaries(lang: Lang): Promise<CertificationSummary[]> {
  return fetchJsonSoft<CertificationSummary[]>(`${SITE.domain}/api/certifications.php?lang=${lang}`);
}

/** Convierte la URL remota de un logo en la de su version optimizada. */
export type LogoOptimizer = (url: string) => Promise<string>;

/**
 * Las insignias de Credly son PNG de hasta 200 KB que se pintan a 64 px. En el
 * build se genera una version WebP pequena de cada una (getImage de
 * astro:assets) y este mapa original -> optimizada viaja en data-logos para
 * que initCerts() la use al repintar. Un logo que falla se queda sin entrada
 * (se sigue sirviendo el original): nunca rompe el build.
 */
export async function buildLogoMap(
  certs: CertificationSummary[],
  optimize: LogoOptimizer,
): Promise<Record<string, string>> {
  const urls = [...new Set(certs.map((c) => c.logo_url ?? ''))].filter((url) => /^https:\/\//i.test(url));
  const entries = await Promise.all(
    urls.map(async (url) => {
      try {
        return [url, await optimize(url)] as const;
      } catch {
        return null;
      }
    }),
  );
  return Object.fromEntries(entries.filter((e): e is readonly [string, string] => e !== null));
}
