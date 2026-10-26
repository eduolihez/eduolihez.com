/**
 * Nodos JSON-LD de schema.org para el software publicado. Los enlaza a la
 * persona con `author: { '@id': personId }`, asi que un motor de IA que lea el
 * grafo entiende que son obra de la misma persona y no entidades sueltas.
 */
import { pick } from '../i18n/utils';
import type { Lang } from '../i18n/ui';
import { softwareEntries, type SoftwareEntry } from '../data/software';

type JsonLdNode = Record<string, unknown>;

export function resolveUrl(entry: SoftwareEntry, domain: string): string | undefined {
  if (entry.externalUrl) return entry.externalUrl;
  if (entry.path) return new URL(entry.path, domain).href;
  return entry.repo;
}

export function buildSoftwareNodes(lang: Lang, domain: string, personId: string): JsonLdNode[] {
  return softwareEntries.map((entry): JsonLdNode => {
    const url = resolveUrl(entry, domain);
    return {
      '@type': entry.kind === 'code' ? 'SoftwareSourceCode' : 'SoftwareApplication',
      '@id': `${domain}/#software-${entry.id}`,
      name: entry.name,
      description: pick(entry.description, lang),
      author: { '@id': personId },
      ...(url ? { url } : {}),
      ...(entry.repo ? { codeRepository: entry.repo } : {}),
      ...(entry.kind === 'app' && entry.category ? { applicationCategory: entry.category } : {}),
      ...(entry.inDevelopment ? { creativeWorkStatus: 'In development' } : {}),
    };
  });
}
