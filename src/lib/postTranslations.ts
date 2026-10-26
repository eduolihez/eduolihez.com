/**
 * Mapa articulo ES -> articulo CA (el mismo contenido, traducido).
 * ---------------------------------------------------------------------------
 * Los articulos viven en MySQL y cada idioma tiene sus propias filas con su
 * propio slug, asi que nada en la base de datos dice que dos filas son el
 * mismo articulo. Este mapa lo declara, y de el salen los hreflang de los
 * articulos (sin hreflang, Google puede tomar la version catalana por una
 * copia de la castellana en vez de por su traduccion).
 *
 * Las filas se crean en database/schema.sql (bloque "Blog: SEO local y
 * catalan"). Si cambias un slug alli, cambialo aqui: postTranslations.test.ts
 * vigila que la relacion siga siendo 1 a 1.
 */
import type { Lang } from '../i18n/ui';

export const POST_TRANSLATIONS_CA: Readonly<Record<string, string>> = {
  'nis2-en-espana-estado-octubre-2026': 'nis2-a-espanya-estat-octubre-2026',
  'joiner-mover-leaver-cuentas-huerfanas': 'joiner-mover-leaver-comptes-orfes',
  'acceso-condicional-microsoft-365-politicas-base': 'acces-condicional-microsoft-365-politiques-base',
  'business-email-compromise-senales-en-microsoft-365': 'business-email-compromise-senyals-a-microsoft-365',
  'secretos-en-repositorios-como-se-filtran-y-como-evitarlo': 'secrets-en-repositoris-com-es-filtren-i-com-evitar-ho',
  'errores-de-configuracion-cloud-mas-comunes': 'errors-de-configuracio-al-cloud-mes-repetits',
  'xdr-vs-siem-vs-edr-diferencias-en-un-soc': 'xdr-siem-i-edr-diferencies-en-un-soc',
  'minimo-privilegio-en-microsoft-entra-id': 'minim-privilegi-a-microsoft-entra-id',
  'spf-dkim-dmarc-de-p-none-a-p-reject': 'spf-dkim-i-dmarc-de-p-none-a-p-reject',
  'mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta': 'mfa-resistent-al-phishing-per-que-sms-ja-no-basta',
  'el-desacuerdo-entre-clasificadores-pierde-contra-algo-mas-simple': 'el-desacord-entre-classificadors-perd-contra-alguna-cosa-mes-simple',
  'lo-que-da-tiempo-a-aprender-en-24-horas-de-hackathon': 'el-que-dona-temps-a-aprendre-en-24-hores-de-hackathon',
  'revocar-un-token-sin-derribar-la-sesion-entera': 'revocar-un-token-sense-enderrocar-la-sessio-sencera',
  'blue-team-hub-por-que-quite-el-cristal-esmerilado': 'blue-team-hub-per-que-vaig-treure-el-vidre-esmerilat',
  'vigilar-el-catalogo-kev-de-cisa-sin-servidor': 'vigilar-el-cataleg-kev-de-cisa-sense-servidor',
  'active-directory-los-primeros-diez-cambios-en-cualquier-dominio-nuevo': 'active-directory-els-deu-primers-canvis-en-qualsevol-domini-nou',
  'de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto': 'de-suport-tecnic-a-soc-el-que-va-canviar-no-va-ser-el-lloc',
  'hardening-fortigate-antes-de-dar-un-despliegue-por-bueno': 'hardening-de-fortigate-abans-de-donar-un-desplegament-per-bo',
  'priorizar-cves-sin-fiarse-solo-del-cvss': 'prioritzar-cve-sense-refiar-se-nomes-del-cvss',
  'automatizar-el-informe-semanal-del-soc-con-python': 'automatitzar-informe-setmanal-del-soc-amb-python',
  'clasificar-phishing-en-el-navegador-sin-mandar-la-url': 'classificar-phishing-al-navegador-sense-enviar-la-url',
  'triaje-de-alertas-en-un-soc-en-que-orden-mirar': 'triatge-alertes-en-un-soc-en-quin-ordre-mirar',
  'comprobar-si-una-contrasena-esta-filtrada-sin-enviarsela-a-nadie': 'comprovar-si-una-contrasenya-esta-filtrada-sense-enviar-la-a-ningu',
  'que-hace-un-analista-soc-un-dia-de-trabajo-real': 'que-fa-un-analista-soc-un-dia-de-feina-real',
  'ciberseguridad-para-pymes-en-barcelona-diez-medidas': 'ciberseguretat-per-a-pimes-a-barcelona-i-badalona-deu-mesures',
  'he-hecho-clic-en-un-phishing-que-hacer-ahora': 'he-fet-clic-a-un-phishing-que-fer-ara-mateix',
  'ransomware-que-hacer-en-las-primeras-24-horas': 'ransomware-que-fer-en-les-primeres-24-hores',
  'certificaciones-para-empezar-como-analista-soc': 'certificacions-per-comencar-com-a-analista-soc-quines-valen-la-pena',
  'auditar-permisos-de-microsoft-365-en-una-tarde': 'auditar-els-permisos-de-microsoft-365-en-una-tarda',
};

const ES_BY_CA: Readonly<Record<string, string>> = Object.fromEntries(
  Object.entries(POST_TRANSLATIONS_CA).map(([es, ca]) => [ca, es]),
);

export function caSlugFor(esSlug: string): string | undefined {
  return POST_TRANSLATIONS_CA[esSlug];
}

export function esSlugFor(caSlug: string): string | undefined {
  return ES_BY_CA[caSlug];
}

/**
 * Alternos hreflang de un articulo, o undefined si no tiene traduccion
 * publicada. `publishedCa` son los slugs catalanes que la API devuelve de
 * verdad en este build: si el mapa dice que existe una version catalana pero
 * todavia no se ha importado a la base de datos, no se anuncia (un hreflang a
 * una pagina que no existe es peor que no ponerlo).
 */
export function postAlternates(
  lang: 'es' | 'ca',
  slug: string,
  publishedCa: ReadonlySet<string>,
): Partial<Record<Lang, string>> | undefined {
  const es = lang === 'es' ? slug : esSlugFor(slug);
  const ca = lang === 'ca' ? slug : caSlugFor(slug);
  if (!es || !ca || !publishedCa.has(ca)) return undefined;
  return { es: `/blog/post/${es}/`, ca: `/ca/blog/post/${ca}/` };
}
