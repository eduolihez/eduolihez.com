/**
 * projects.ts - Trae los proyectos desde /api/projects.php EN BUILD TIME.
 * ---------------------------------------------------------------------------
 * POR QUE EXISTE: <Projects /> pintaba la cuadricula entera en el navegador
 * tras un fetch (ver src/scripts/projects.ts) -- igual que el blog antes de
 * la migracion de src/lib/posts.ts. Un fetch crudo a "/" con curl (o
 * GPTBot/ClaudeBot/PerplexityBot, que no ejecutan JS) veia el hueco vacio de
 * #projects-grid: ni titulo, ni stack, ni enlace a un repo, justo lo que un
 * reclutador o un par tecnico necesita para juzgar el perfil en menos de un
 * minuto.
 *
 * Esta funcion solo trae lo minimo para un PRIMER PINTADO real en el HTML
 * servido -- Projects.astro la usa para rellenar #projects-grid de entrada.
 * En cuanto carga initProjects() (src/scripts/projects.ts), esa funcion hace
 * `grid.innerHTML = ''` y reconstruye la cuadricula completa (filtros, modal,
 * badges) desde una llamada fresca a la API: esto NUNCA sustituye a esa
 * logica, solo evita que la primera pintura este vacia.
 *
 * Fallo en build = array vacio, nunca build roto: a diferencia del blog
 * (src/lib/posts.ts), esto es una mejora de la primera pintura, no la fuente
 * de verdad de una pagina que no existiria sin ella.
 */
import { SITE } from '../config';
import type { Lang } from '../i18n/ui';
import { fetchJsonSoft } from './buildFetch';

export interface ProjectSummary {
  title?: string;
  description?: string;
  summary?: string;
  demo_url?: string;
  repo_url?: string;
  stack?: string[];
}

export async function fetchProjectSummaries(lang: Lang): Promise<ProjectSummary[]> {
  return fetchJsonSoft<ProjectSummary[]>(`${SITE.domain}/api/projects.php?lang=${lang}`);
}
