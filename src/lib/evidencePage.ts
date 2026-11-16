/**
 * evidencePage.ts - Textos de /evidencias (ES/EN/CA) y filas de la tabla,
 * construidas solo con datos reales de config.ts (evidence + credentials).
 */
import { evidence, SITE, type Evidence } from '../config';
import type { Lang } from '../i18n/ui';

export interface EvidenceRow {
  id: string;
  label: string;
  issuer: string;
  year: string;
  kind: Evidence['kind'];
  href: string;
}

/** Emisor: el de la credencial con el mismo nombre; si no hay, el primer tramo de la etiqueta. */
export function issuerOf(label: string): string {
  const cred = SITE.credentials.find((c) => c.name.toLowerCase() === label.toLowerCase());
  if (cred) return cred.issuer;
  return label.split(' ')[0] ?? '';
}

export function evidenceRows(list: readonly Evidence[] = evidence): EvidenceRow[] {
  return list.map((e) => ({
    id: e.id,
    label: e.label,
    issuer: issuerOf(e.label),
    year: e.year ?? '',
    kind: e.kind,
    href: e.href,
  }));
}

export const evidenceCopy: Record<Lang, Record<string, string>> = {
  es: {
    title: 'Evidencias | Eduardo Olivares',
    description:
      'Índice de evidencias verificables de Eduardo Olivares: credenciales y archivos con emisor, año, fuente y enlace permanente.',
    h1: 'Evidencias',
    lede: 'Cada afirmación del perfil tiene una fuente. Aquí están todas, con su emisor, su año si consta y un enlace permanente.',
    id: 'ID',
    what: 'Evidencia',
    issuer: 'Emisor',
    year: 'Año',
    source: 'Fuente',
    verify: 'Verificar',
    credly: 'Credly (insignia)',
    pdf: 'Archivo PDF',
    other: 'Enlace',
    back: 'Volver al inicio',
    print: 'Imprimir / guardar dossier',
    crumb: 'Evidencias',
  },
  en: {
    title: 'Evidence | Eduardo Olivares',
    description:
      'Index of verifiable evidence for Eduardo Olivares: credentials and files with issuer, year, source and permalink.',
    h1: 'Evidence',
    lede: 'Every claim on the profile has a source. All of them are listed here with issuer, year when known, and a permalink.',
    id: 'ID',
    what: 'Evidence',
    issuer: 'Issuer',
    year: 'Year',
    source: 'Source',
    verify: 'Verify',
    credly: 'Credly (badge)',
    pdf: 'PDF file',
    other: 'Link',
    back: 'Back to home',
    print: 'Print / save dossier',
    crumb: 'Evidence',
  },
  ca: {
    title: 'Evidències | Eduardo Olivares',
    description:
      "Índex d'evidències verificables d'Eduardo Olivares: credencials i fitxers amb emissor, any, font i enllaç permanent.",
    h1: 'Evidències',
    lede: "Cada afirmació del perfil té una font. Aquí hi són totes, amb l'emissor, l'any si consta i un enllaç permanent.",
    id: 'ID',
    what: 'Evidència',
    issuer: 'Emissor',
    year: 'Any',
    source: 'Font',
    verify: 'Verificar',
    credly: 'Credly (insígnia)',
    pdf: 'Fitxer PDF',
    other: 'Enllaç',
    back: "Tornar a l'inici",
    print: 'Imprimir / desar dossier',
    crumb: 'Evidències',
  },
};

export const evidencePaths: Record<Lang, string> = {
  es: '/evidencias/',
  en: '/en/evidence/',
  ca: '/ca/evidencies/',
};
