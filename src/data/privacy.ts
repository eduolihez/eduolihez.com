/**
 * Politica de privacidad: contenido en es/en/ca.
 *
 * Todo lo que se afirma aqui sale del codigo real (server/api/visit.php,
 * contact.php, src/scripts/consent.ts). Si cambia algo de lo que se recoge o
 * de cuanto se guarda, hay que actualizar este fichero Y `PRIVACY_UPDATED`.
 * La retencion de 400 dias coincide con los DELETE de visit.php.
 */
import type { Lang } from '../i18n/ui';

export type Localized = Record<Lang, string>;

/** Fecha ISO de la ultima revision del texto. */
export const PRIVACY_UPDATED = '2026-11-25';

/** Rutas de la politica en cada idioma (hreflang, footer, banner). */
export const privacyPaths: Record<Lang, string> = {
  es: '/privacy/',
  en: '/en/privacy/',
  ca: '/ca/privacitat/',
};

export interface PrivacySection {
  id: string;
  title: Localized;
  /** Parrafos sueltos. */
  body?: Localized[];
  /** Lista con vinetas, tras los parrafos. */
  list?: Localized[];
}

export const privacyMeta = {
  title: {
    es: 'Política de privacidad | Eduardo Olivares',
    en: 'Privacy policy | Eduardo Olivares',
    ca: 'Política de privacitat | Eduardo Olivares',
  } as Localized,
  description: {
    es: 'Qué datos recoge eduolihez.com, para qué, cuánto tiempo se guardan y cómo ejercer tus derechos. Analítica propia, cookie solo con tu permiso y sin terceros de publicidad.',
    en: 'What data eduolihez.com collects, why, how long it is kept and how to exercise your rights. First-party analytics, a cookie only with your consent and no ad third parties.',
    ca: "Quines dades recull eduolihez.com, per a què, quant de temps es guarden i com exercir els teus drets. Analítica pròpia, galeta només amb el teu permís i sense tercers de publicitat.",
  } as Localized,
  h1: {
    es: 'Política de privacidad',
    en: 'Privacy policy',
    ca: 'Política de privacitat',
  } as Localized,
  lede: {
    es: 'Esta web es un portfolio personal. Recoge lo mínimo para funcionar, medir cuántas personas la visitan y poder contestarte si me escribes. No hay publicidad, ni perfiles, ni venta de datos.',
    en: 'This site is a personal portfolio. It collects the minimum needed to work, to measure how many people visit and to be able to reply if you write to me. There is no advertising, no profiling and no selling of data.',
    ca: "Aquest web és un portfolio personal. Recull el mínim per funcionar, mesurar quantes persones el visiten i poder contestar-te si m'escrius. No hi ha publicitat, ni perfils, ni venda de dades.",
  } as Localized,
  updatedLabel: {
    es: 'Última actualización',
    en: 'Last updated',
    ca: 'Última actualització',
  } as Localized,
  back: {
    es: 'Volver al inicio',
    en: 'Back to home',
    ca: "Tornar a l'inici",
  } as Localized,
  breadcrumb: {
    es: 'Privacidad',
    en: 'Privacy',
    ca: 'Privacitat',
  } as Localized,
  /** Texto del enlace del pie. */
  footerLabel: {
    es: 'Privacidad',
    en: 'Privacy',
    ca: 'Privacitat',
  } as Localized,
};

const email = 'hola@eduolihez.com';

export const privacySections: PrivacySection[] = [
  {
    id: 'responsable',
    title: { es: 'Quién es el responsable', en: 'Who is responsible', ca: 'Qui és el responsable' },
    body: [
      {
        es: `El responsable del tratamiento es Eduardo Olivares Hernández (Badalona, España), a título personal. Puedes escribirme a ${email}.`,
        en: `The data controller is Eduardo Olivares Hernández (Badalona, Spain), acting as an individual. You can write to me at ${email}.`,
        ca: `El responsable del tractament és Eduardo Olivares Hernández (Badalona, Espanya), a títol personal. Em pots escriure a ${email}.`,
      },
    ],
  },
  {
    id: 'datos',
    title: { es: 'Qué datos trato y para qué', en: 'What data I process and why', ca: 'Quines dades tracto i per a què' },
    body: [
      {
        es: 'Hay dos tratamientos, y el segundo solo ocurre si me escribes.',
        en: 'There are two processing activities, and the second only happens if you write to me.',
        ca: 'Hi ha dos tractaments, i el segon només passa si m’escrius.',
      },
    ],
    list: [
      {
        es: 'Analítica propia (sin terceros). Al cargar una página guardo: la ruta visitada, de dónde vienes (solo dominio y ruta, sin parámetros), país (lo indica Cloudflare), tipo de dispositivo, un tramo aproximado del ancho de pantalla, idioma del navegador, parámetros UTM si los hay, tiempo en la página y hasta dónde has hecho scroll. Tu IP no se guarda: se convierte en un hash SHA-256 con una sal secreta y el user-agent, y ese hash solo sirve para contar visitas únicas y limitar abusos. Base jurídica: interés legítimo en saber si la web funciona y qué se lee (art. 6.1.f RGPD).',
        en: 'First-party analytics (no third parties). When a page loads I store: the path visited, where you came from (domain and path only, no query string), country (provided by Cloudflare), device type, a rough screen-width bracket, browser language, UTM parameters if present, time on page and how far you scrolled. Your IP is not stored: it is turned into a SHA-256 hash with a secret salt and the user-agent, and that hash is only used to count unique visits and limit abuse. Legal basis: legitimate interest in knowing whether the site works and what gets read (GDPR art. 6.1.f).',
        ca: "Analítica pròpia (sense tercers). En carregar una pàgina guardo: la ruta visitada, d'on véns (només domini i ruta, sense paràmetres), país (ho indica Cloudflare), tipus de dispositiu, un tram aproximat de l'amplada de pantalla, idioma del navegador, paràmetres UTM si n'hi ha, temps a la pàgina i fins on has fet scroll. La teva IP no es guarda: es converteix en un hash SHA-256 amb una sal secreta i el user-agent, i aquest hash només serveix per comptar visites úniques i limitar abusos. Base jurídica: interès legítim a saber si el web funciona i què es llegeix (art. 6.1.f RGPD).",
      },
      {
        es: `Formulario de contacto. Si me escribes guardo tu nombre, tu email, el asunto, el mensaje, tu IP y tu user-agent (estos dos últimos, para frenar el spam) y recibo el mensaje por correo en ${email}. Los uso solo para contestarte. Base jurídica: tu petición de contacto y mi interés legítimo en responder y evitar abusos (art. 6.1.b y 6.1.f RGPD). El formulario usa Cloudflare Turnstile, un captcha invisible que envía a Cloudflare datos técnicos de tu navegador para distinguir personas de bots.`,
        en: `Contact form. If you write to me I store your name, email, subject, message, IP and user-agent (the last two to stop spam) and I receive the message by email at ${email}. I use them only to reply to you. Legal basis: your contact request and my legitimate interest in replying and preventing abuse (GDPR art. 6.1.b and 6.1.f). The form uses Cloudflare Turnstile, an invisible captcha that sends technical browser data to Cloudflare to tell people from bots.`,
        ca: `Formulari de contacte. Si m'escrius guardo el teu nom, el teu email, l'assumpte, el missatge, la teva IP i el teu user-agent (aquests dos últims, per frenar l'spam) i rebo el missatge per correu a ${email}. Els faig servir només per contestar-te. Base jurídica: la teva petició de contacte i el meu interès legítim a respondre i evitar abusos (art. 6.1.b i 6.1.f RGPD). El formulari fa servir Cloudflare Turnstile, un captcha invisible que envia a Cloudflare dades tècniques del teu navegador per distingir persones de bots.`,
      },
    ],
  },
  {
    id: 'cookies',
    title: { es: 'Cookies y almacenamiento local', en: 'Cookies and local storage', ca: 'Galetes i emmagatzematge local' },
    body: [
      {
        es: 'Por defecto la web no instala ninguna cookie. Esto es lo único que puede guardar en tu navegador:',
        en: 'By default the site sets no cookies. This is all it can store in your browser:',
        ca: 'Per defecte el web no instal·la cap galeta. Això és tot el que pot guardar al teu navegador:',
      },
    ],
    list: [
      {
        es: 'eo_vid (cookie propia, solo si pulsas «Aceptar» en el aviso). Un número aleatorio de 16 caracteres, 180 días. Sirve para distinguir visitantes nuevos de recurrentes. No contiene datos personales, no se cruza con nada y no sale de este sitio.',
        en: 'eo_vid (first-party cookie, only if you press “Accept” on the notice). A random 16-character number, 180 days. It tells new visitors from returning ones. It holds no personal data, is not cross-referenced with anything and never leaves this site.',
        ca: "eo_vid (galeta pròpia, només si prems «Acceptar» a l'avís). Un número aleatori de 16 caràcters, 180 dies. Serveix per distingir visitants nous de recurrents. No conté dades personals, no es creua amb res i no surt d'aquest lloc.",
      },
      {
        es: 'eo_consent (localStorage). Recuerda si aceptaste o rechazaste la cookie anterior y caduca a los 6 meses, cuando se vuelve a preguntar.',
        en: 'eo_consent (localStorage). Remembers whether you accepted or declined the cookie above and expires after 6 months, when the question is asked again.',
        ca: 'eo_consent (localStorage). Recorda si has acceptat o rebutjat la galeta anterior i caduca als 6 mesos, quan es torna a preguntar.',
      },
      {
        es: 'Un identificador de sesión en sessionStorage (se borra al cerrar la pestaña) para agrupar las páginas de una misma visita, y la preferencia de tema claro u oscuro.',
        en: 'A session identifier in sessionStorage (deleted when you close the tab) to group the pages of one visit, and your light or dark theme preference.',
        ca: "Un identificador de sessió a sessionStorage (s'esborra en tancar la pestanya) per agrupar les pàgines d'una mateixa visita, i la preferència de tema clar o fosc.",
      },
      {
        es: 'Si tu navegador envía la señal «No rastrear» (DNT) o Global Privacy Control, lo trato como un rechazo: no se muestra el aviso ni se crea la cookie. Puedes cambiar de opinión en cualquier momento desde el enlace «Cookies» del pie de página.',
        en: 'If your browser sends the Do Not Track (DNT) or Global Privacy Control signal, I treat it as a refusal: the notice is not shown and the cookie is not created. You can change your mind at any time from the “Cookies” link in the footer.',
        ca: "Si el teu navegador envia el senyal «No em rastregis» (DNT) o Global Privacy Control, ho tracto com un rebuig: no es mostra l'avís ni es crea la galeta. Pots canviar d'opinió en qualsevol moment des de l'enllaç «Galetes» del peu de pàgina.",
      },
    ],
  },
  {
    id: 'conservacion',
    title: { es: 'Cuánto tiempo los guardo', en: 'How long I keep it', ca: 'Quant de temps ho guardo' },
    list: [
      {
        es: 'Analítica (visitas y eventos): 400 días; pasado ese plazo se borran automáticamente.',
        en: 'Analytics (visits and events): 400 days; after that they are deleted automatically.',
        ca: 'Analítica (visites i esdeveniments): 400 dies; passat aquest termini s’esborren automàticament.',
      },
      {
        es: 'Mensajes de contacto: el tiempo necesario para atender tu consulta y su seguimiento. Puedes pedirme que los borre cuando quieras.',
        en: 'Contact messages: as long as needed to handle your enquiry and follow-up. You can ask me to delete them at any time.',
        ca: 'Missatges de contacte: el temps necessari per atendre la teva consulta i el seu seguiment. Em pots demanar que els esborri quan vulguis.',
      },
    ],
  },
  {
    id: 'terceros',
    title: { es: 'Con quién se comparten', en: 'Who it is shared with', ca: 'Amb qui es comparteixen' },
    body: [
      {
        es: 'No vendo ni cedo datos. Solo intervienen proveedores técnicos que los tratan por mi cuenta para que la web funcione:',
        en: 'I do not sell or hand over data. Only technical providers take part, processing it on my behalf so the site works:',
        ca: 'No venc ni cedeixo dades. Només intervenen proveïdors tècnics que les tracten per compte meu perquè el web funcioni:',
      },
    ],
    list: [
      {
        es: 'Cloudflare: red de distribución (CDN), protección frente a ataques y captcha Turnstile. Ve tu IP al servir la web. Puede tratar datos fuera del Espacio Económico Europeo con las garantías contractuales habituales (cláusulas contractuales tipo).',
        en: 'Cloudflare: content delivery network (CDN), attack protection and the Turnstile captcha. It sees your IP when serving the site. It may process data outside the European Economic Area under the usual contractual safeguards (standard contractual clauses).',
        ca: "Cloudflare: xarxa de distribució (CDN), protecció davant d'atacs i captcha Turnstile. Veu la teva IP en servir el web. Pot tractar dades fora de l'Espai Econòmic Europeu amb les garanties contractuals habituals (clàusules contractuals tipus).",
      },
      {
        es: 'CDmon: alojamiento del sitio y de la base de datos.',
        en: 'CDmon: hosting for the site and the database.',
        ca: 'CDmon: allotjament del lloc i de la base de dades.',
      },
      {
        es: 'Proveedor de correo: si me escribes, el mensaje pasa por el correo del dominio y se reenvía a mi bandeja personal.',
        en: 'Email provider: if you write to me, the message goes through the domain mailbox and is forwarded to my personal inbox.',
        ca: "Proveïdor de correu: si m'escrius, el missatge passa pel correu del domini i es reenvia a la meva safata personal.",
      },
    ],
  },
  {
    id: 'noes',
    title: { es: 'Lo que no hago', en: 'What I do not do', ca: 'El que no faig' },
    list: [
      {
        es: 'No hay publicidad, píxeles de seguimiento ni analítica de terceros en el código de la web.',
        en: 'There is no advertising, tracking pixels or third-party analytics in the site code.',
        ca: 'No hi ha publicitat, píxels de seguiment ni analítica de tercers al codi del web.',
      },
      {
        es: 'Las tipografías van alojadas en el propio sitio: no se piden a Google Fonts ni a ningún CDN externo.',
        en: 'Fonts are hosted on the site itself: they are not requested from Google Fonts or any external CDN.',
        ca: 'Les tipografies són allotjades al propi lloc: no es demanen a Google Fonts ni a cap CDN extern.',
      },
      {
        es: 'No tomo decisiones automatizadas ni elaboro perfiles sobre ti.',
        en: 'I make no automated decisions and build no profiles about you.',
        ca: 'No prenc decisions automatitzades ni elaboro perfils sobre tu.',
      },
    ],
  },
  {
    id: 'derechos',
    title: { es: 'Tus derechos', en: 'Your rights', ca: 'Els teus drets' },
    body: [
      {
        es: `Puedes pedirme acceso, rectificación, supresión, limitación u oposición al tratamiento, y la portabilidad de tus datos, escribiendo a ${email}. Contesto en el plazo de un mes. Como la analítica no guarda tu IP real, para localizar tus visitas tendrías que darme el dato que lo permita (por ejemplo el valor de tu cookie eo_vid). Si crees que no he tratado tus datos bien, puedes reclamar ante la Agencia Española de Protección de Datos (aepd.es).`,
        en: `You can ask me for access, rectification, erasure, restriction or objection, and for portability of your data, by writing to ${email}. I reply within one month. Because analytics does not store your real IP, to locate your visits you would need to give me something that makes it possible (for example the value of your eo_vid cookie). If you think I have not handled your data properly, you can complain to the Spanish Data Protection Agency (aepd.es).`,
        ca: `Em pots demanar accés, rectificació, supressió, limitació o oposició al tractament, i la portabilitat de les teves dades, escrivint a ${email}. Contesto en el termini d'un mes. Com que l'analítica no guarda la teva IP real, per localitzar les teves visites m'hauries de donar la dada que ho permeti (per exemple el valor de la teva galeta eo_vid). Si creus que no he tractat bé les teves dades, pots reclamar davant l'Agència Espanyola de Protecció de Dades (aepd.es).`,
      },
    ],
  },
  {
    id: 'cambios',
    title: { es: 'Cambios en esta política', en: 'Changes to this policy', ca: 'Canvis en aquesta política' },
    body: [
      {
        es: 'Si cambia lo que recoge la web, actualizo esta página y la fecha de arriba. El historial completo está en el repositorio público del sitio.',
        en: 'If what the site collects changes, I update this page and the date above. The full history is in the site’s public repository.',
        ca: 'Si canvia el que recull el web, actualitzo aquesta pàgina i la data de dalt. L’historial complet és al repositori públic del lloc.',
      },
    ],
  },
];
