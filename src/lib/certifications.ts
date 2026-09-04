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
  issue_date?: string;
}

export async function fetchCertificationSummaries(lang: Lang): Promise<CertificationSummary[]> {
  return fetchJsonSoft<CertificationSummary[]>(`${SITE.domain}/api/certifications.php?lang=${lang}`);
}
