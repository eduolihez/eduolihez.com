/**
 * Utilidades i18n.
 * - useTranslations(lang): devuelve t(clave) para los textos fijos de la UI.
 * - localeBase(lang): ruta base del idioma ("/", "/en/", "/ca/").
 * - pick(obj, lang): elige el texto localizado de un objeto {es,en,ca?} con
 *   respaldo a espanol (util para datos estaticos como experiencia/skills).
 */
import { ui, defaultLang, type Lang, type UIKey } from './ui';

/** Devuelve la funcion de traduccion para un idioma dado. */
export function useTranslations(lang: Lang) {
  return function t(key: UIKey): string {
    return ui[lang][key] ?? ui[defaultLang][key];
  };
}

/** Ruta base del idioma: "/" (es), "/en/" (en), "/ca/" (ca). */
export function localeBase(lang: Lang): string {
  if (lang === 'en') return '/en/';
  if (lang === 'ca') return '/ca/';
  return '/';
}

/** Texto localizado de un objeto {es, en?, ca?} con respaldo a espanol. */
export interface Localized {
  es: string;
  en?: string;
  ca?: string;
}
export function pick(obj: Localized, lang: Lang): string {
  return obj[lang] ?? obj.es;
}
