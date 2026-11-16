/**
 * evidence.ts - Ficha de evidencias del hero (E-01...E-nn).
 *
 * - `linkAttrs`: los enlaces externos (https) abren en pestana nueva con
 *   rel="noopener noreferrer"; los archivos locales (/certificaciones/...)
 *   se abren en la misma pestana y sin rel.
 * - `evidenceAnchor` / `permalink`: cada evidencia tiene un ancla propia
 *   (#e-01). Sin JS el ID ya es un enlace permanente; con JS, ademas, al
 *   pulsarlo se copia la URL al portapapeles y se anuncia en una region viva.
 */

export interface LinkAttrs {
  external: boolean;
  target?: '_blank';
  rel?: 'noopener noreferrer';
}

/** Atributos del enlace "Verificar" segun la URL sea externa o local. */
export function linkAttrs(href: string): LinkAttrs {
  if (/^https?:\/\//i.test(href)) {
    return { external: true, target: '_blank', rel: 'noopener noreferrer' };
  }
  return { external: false };
}

/** Tipo de fuente que ve el visitante: Credly (insignia) o PDF (archivo). Otra cosa: null. */
export function sourceType(href: string): 'Credly' | 'PDF' | null {
  if (/^https:\/\/([a-z0-9-]+\.)*credly\.com\//i.test(href)) return 'Credly';
  if (/\.pdf([?#]|$)/i.test(href)) return 'PDF';
  return null;
}

/** Id del ancla de una evidencia: "E-01" -> "e-01". */
export function evidenceAnchor(id: string): string {
  return id.toLowerCase();
}

/** URL absoluta de una evidencia, sin hash previo: base#e-01. */
export function permalink(base: string, id: string): string {
  return `${base.split('#')[0]}#${evidenceAnchor(id)}`;
}

type Clipboard = Pick<globalThis.Clipboard, 'writeText'> | undefined;

/**
 * Engancha "copiar enlace" a los [data-evidence-copy] de `root`. No impide la
 * navegacion al ancla (sigue siendo un permalink normal). Devuelve cuantos
 * enlaces ha preparado. Idempotente: no duplica oyentes en astro:page-load.
 */
export function initEvidenceCopy(
  root: ParentNode = document,
  clipboard: Clipboard = typeof navigator !== 'undefined' ? navigator.clipboard : undefined,
): number {
  const live = root.querySelector<HTMLElement>('[data-evidence-live]');
  const links = root.querySelectorAll<HTMLAnchorElement>('a[data-evidence-copy]');
  let count = 0;
  links.forEach((a) => {
    if (a.dataset.evidenceReady === '1') return;
    a.dataset.evidenceReady = '1';
    count++;
    a.addEventListener('click', () => {
      if (!clipboard) return;
      const id = a.dataset.evidenceCopy ?? '';
      const url = permalink(window.location.href, id);
      clipboard.writeText(url).then(
        () => {
          if (live) live.textContent = `${live.dataset.copiedText ?? ''} ${url}`.trim();
        },
        () => {
          /* Sin permiso de portapapeles: el ancla ya cambia la URL. */
        },
      );
    });
  });
  return count;
}
