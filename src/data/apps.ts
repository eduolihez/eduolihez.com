/**
 * DATOS DE LAS EXTENSIONES DE NAVEGADOR (apps.ts)
 * ---------------------------------------------------------------------------
 * Fuente unica de contenido para /apps/<id>/ (ES) y /en/apps/<id>/ (EN).
 * Antes cada extension vivia como HTML suelto en public/projects/<nombre>/;
 * ahora son paginas Astro reales que leen de aqui, con el mismo patron
 * `Record<'es'|'en', string>` que src/data/faq.ts usa para todo texto.
 *
 * COMO ANADIR UNA APP NUEVA: copia un objeto entero, cambia `id`, y crea
 * src/pages/apps/<id>.astro + src/pages/en/apps/<id>.astro.
 *
 * `links.chromeWebStore` / `links.firefoxAddons` se dejan `undefined` (no se
 * incluyen) mientras la ficha no este publicada de verdad -- inventar una URL
 * de tienda que da 404 es peor que no ponerla; la pagina muestra el badge de
 * estado en su lugar (ver src/pages/apps/*.astro).
 */
import type { Localized } from '../i18n/utils';

export type AppStatus = 'oss' | 'wip' | 'closed';

export interface AppPermission {
  name: string;
  reason: Localized;
}

export interface AppFaqItem {
  question: Localized;
  answer: Localized;
}

export interface AppFeature {
  title: Localized;
  description: Localized;
  /** Nombre de icono de src/components/Icon.astro. */
  icon: string;
}

export interface AppStep {
  title: Localized;
  description: Localized;
}

export interface AppData {
  id: string;
  name: string;
  tagline: Localized;
  description: Localized;
  features: AppFeature[];
  /** 3 pasos para la seccion "Como funciona" en el hero. */
  howItWorks: AppStep[];
  privacy: {
    intro: Localized;
    points: Localized[];
  };
  permissions: AppPermission[];
  faq: AppFaqItem[];
  status: AppStatus;
  iconPath: string;
  /** Rutas de capturas reales; vacio si la seccion usa un mockup HTML/CSS inline. */
  screenshots: string[];
  links: {
    chromeWebStore?: string;
    firefoxAddons?: string;
  };
  /** Tecnologias/base para el chip de stack (coherencia con /projects/). */
  stack: string[];
}

export const apps: AppData[] = [
  {
    id: 'nowait',
    name: 'NoWait',
    tagline: {
      es: 'Salta automáticamente acortadores de enlaces y páginas de espera',
      en: 'Automatically skips link shorteners and waiting pages',
    },
    description: {
      es: 'NoWait evita automáticamente acortadores de enlaces, "link-lockers" y páginas de espera artificiales — Linkvertise, ouo.io, adf.ly y otros 90+ sitios — para llegar directo al destino final, sin captchas, temporizadores ni anuncios intermedios. Es un fork mantenido de FastForward (dominio público), con una diferencia clave: el content script solo se inyecta en los dominios con una bypass registrada, no en cualquier página que visitas.',
      en: 'NoWait automatically bypasses link shorteners, "link-lockers" and artificial waiting pages — Linkvertise, ouo.io, adf.ly and 90+ other sites — so you land directly on the final destination, with no captchas, timers or interstitial ads. It is a maintained fork of FastForward (public domain), with one key difference: the content script only runs on domains with a registered bypass, not on every page you visit.',
    },
    features: [
      {
        title: { es: '90+ bypasses por sitio', en: '90+ site-specific bypasses' },
        description: {
          es: 'Cada acortador tiene su propio mecanismo de espera o captcha resuelto de forma específica: Linkvertise, ouo.io, adf.ly, sh.st, work.ink y muchos más.',
          en: 'Each shortener has its own waiting or captcha mechanism, resolved with a dedicated bypass: Linkvertise, ouo.io, adf.ly, sh.st, work.ink and many more.',
        },
        icon: 'bolt',
      },
      {
        title: { es: 'Bloqueo de IP loggers', en: 'IP logger blocking' },
        description: {
          es: 'Si un enlace no se puede evadir y además registra tu dirección IP, NoWait lo bloquea en vez de dejarte navegar a él.',
          en: 'If a link cannot be bypassed and also logs your IP address, NoWait blocks it instead of letting you navigate there.',
        },
        icon: 'shield',
      },
      {
        title: { es: 'Evasión de rastreadores de enlaces', en: 'Link tracker evasion' },
        description: {
          es: 'bit.ly, t.co, goo.gl y similares se resuelven sin pasar por la página intermedia.',
          en: 'bit.ly, t.co, goo.gl and similar are resolved without ever loading the intermediate page.',
        },
        icon: 'search',
      },
      {
        title: { es: 'Crowd bypass (opcional, desactivado por defecto)', en: 'Crowd bypass (optional, off by default)' },
        description: {
          es: 'Para acortadores sin bypass automática todavía, consulta y comparte destinos ya descubiertos por la comunidad de FastForward.',
          en: 'For shorteners without an automatic bypass yet, it looks up and shares destinations already discovered by the FastForward community.',
        },
        icon: 'refresh',
      },
      {
        title: { es: 'Lista blanca configurable', en: 'Configurable whitelist' },
        description: {
          es: 'Excluye dominios propios por wildcard para que NoWait nunca actúe sobre ellos.',
          en: 'Exclude your own domains by wildcard so NoWait never acts on them.',
        },
        icon: 'check',
      },
      {
        title: { es: 'Manifest V3 nativo en ambos navegadores', en: 'Native Manifest V3 on both browsers' },
        description: {
          es: 'Build independiente para Chrome/Chromium y Firefox, cada uno con su propio manifest — no es un empaquetado genérico adaptado a posteriori.',
          en: 'Independent build for Chrome/Chromium and Firefox, each with its own manifest — not a generic package retrofitted after the fact.',
        },
        icon: 'code',
      },
    ],
    howItWorks: [
      {
        title: { es: 'Detecta el enlace', en: 'Detects the link' },
        description: {
          es: 'El content script identifica si el dominio tiene un bypass registrado antes de hacer nada.',
          en: 'The content script checks whether the domain has a registered bypass before doing anything.',
        },
      },
      {
        title: { es: 'Resuelve el bypass', en: 'Resolves the bypass' },
        description: {
          es: 'Aplica el módulo específico de ese acortador, sin llegar a cargar su página intermedia.',
          en: 'It runs that shortener’s dedicated module, without ever loading its intermediate page.',
        },
      },
      {
        title: { es: 'Llegas al destino', en: 'You land on the destination' },
        description: {
          es: 'Te redirige directo a la URL final, sin captchas, anuncios ni temporizadores.',
          en: 'You get redirected straight to the final URL — no captchas, ads or timers.',
        },
      },
    ],
    privacy: {
      intro: {
        es: 'NoWait no recopila información personal identificable. Todo el procesamiento de la URL que se está evadiendo ocurre localmente en tu navegador.',
        en: 'NoWait does not collect personally identifiable information. All processing of the URL being bypassed happens locally in your browser.',
      },
      points: [
        {
          es: 'La URL de destino nunca sale de tu equipo por el mecanismo de evasión principal.',
          en: 'The destination URL never leaves your device through the main bypass mechanism.',
        },
        {
          es: 'La única telemetría enviada (a un servidor propio) es el dominio del acortador evadido y qué módulo de bypass se activó — nunca la URL completa de destino, su ruta ni sus parámetros.',
          en: 'The only telemetry sent (to a first-party server) is the domain of the bypassed shortener and which bypass module ran — never the full destination URL, its path or its parameters.',
        },
        {
          es: 'El "crowd bypass" es opcional y está desactivado por defecto; cuando se activa, usa el servicio comunitario de FastForward bajo su propia política de privacidad.',
          en: 'Crowd bypass is optional and off by default; when enabled, it uses the FastForward community service under its own privacy policy.',
        },
        {
          es: 'Las definiciones de bypass se empaquetan en cada build de la extensión: no hay descarga de definiciones en tiempo real.',
          en: 'Bypass definitions are bundled at extension build time: there is no live definitions download.',
        },
      ],
    },
    permissions: [
      {
        name: 'storage',
        reason: {
          es: 'Guarda localmente tus preferencias (lista blanca, activación de crowd bypass) — nunca se sincroniza con terceros.',
          en: 'Stores your preferences locally (whitelist, crowd bypass toggle) — never synced to third parties.',
        },
      },
      {
        name: 'tabs',
        reason: {
          es: 'Detecta y redirige la pestaña activa al destino final una vez resuelto el bypass.',
          en: 'Detects and redirects the active tab to the final destination once the bypass is resolved.',
        },
      },
      {
        name: 'declarativeNetRequestWithHostAccess',
        reason: {
          es: 'Aplica las reglas de bloqueo de IP loggers y evasión de rastreadores sin interceptar manualmente cada petición.',
          en: 'Applies IP logger blocking and tracker evasion rules without manually intercepting every request.',
        },
      },
      {
        name: 'host_permissions: <all_urls>',
        reason: {
          es: 'El bloqueo de IP loggers y rastreadores debe poder aplicarse en cualquier sitio; el content script que ejecuta las bypasses solo se inyecta en dominios con bypass registrada.',
          en: 'IP logger and tracker blocking must be able to apply on any site; the content script that runs bypasses only injects on domains with a registered bypass.',
        },
      },
    ],
    faq: [
      {
        question: { es: '¿Es de pago?', en: 'Is it paid?' },
        answer: {
          es: 'No. NoWait es completamente gratuito, sin plan de pago ni versión PRO.',
          en: 'No. NoWait is completely free, with no paid plan or PRO tier.',
        },
      },
      {
        question: { es: '¿Funciona en Firefox?', en: 'Does it work on Firefox?' },
        answer: {
          es: 'Sí, funciona en Chrome, Chromium y Firefox.',
          en: 'Yes, it works on Chrome, Chromium and Firefox.',
        },
      },
      {
        question: { es: '¿Qué datos recopila?', en: 'What data does it collect?' },
        answer: {
          es: 'Ninguno personal. Solo telemetría mínima y anónima (dominio del acortador y módulo de bypass activado), nunca la URL de destino completa.',
          en: 'No personal data. Only minimal, anonymous telemetry (shortener domain and bypass module used), never the full destination URL.',
        },
      },
      {
        question: { es: '¿Puedo excluir mis propios enlaces?', en: 'Can I exclude my own links?' },
        answer: {
          es: 'Sí, mediante la lista blanca configurable por wildcard en las opciones de la extensión.',
          en: 'Yes, using the configurable wildcard whitelist in the extension options.',
        },
      },
    ],
    status: 'closed',
    iconPath: '/img/apps/nowait/icon.png',
    screenshots: [],
    links: {
      // TODO: publicar en Chrome Web Store / addons.mozilla.org y anadir aqui.
    },
    stack: ['JavaScript', 'Chrome API', 'WebExtensions'],
  },

  {
    id: 'password-centinel',
    name: 'Password Centinel',
    tagline: {
      es: 'Gestor de contraseñas 100% local: cifrado, TOTP y comprobación de filtraciones',
      en: 'A fully local password manager: encryption, TOTP and breach checking',
    },
    description: {
      es: 'Password Centinel es un gestor de contraseñas que vive enteramente en tu navegador: sin cuenta, sin nube, sin backend propio. Vault cifrado con AES-256-GCM, TOTP/2FA integrado, comprobación de filtraciones vía Have I Been Pwned con k-anonimato, análisis de fortaleza, generador de passphrases e importación CSV desde otros gestores.',
      en: 'Password Centinel is a password manager that lives entirely in your browser: no account, no cloud, no first-party backend. AES-256-GCM encrypted vault, built-in TOTP/2FA, breach checking via Have I Been Pwned using k-anonymity, strength analysis, a passphrase generator, and CSV import from other password managers.',
    },
    features: [
      {
        title: { es: 'Vault cifrado AES-256-GCM', en: 'AES-256-GCM encrypted vault' },
        description: {
          es: 'Clave derivada de tu clave maestra vía PBKDF2 (100.000 iteraciones, SHA-256). La clave maestra nunca sale de la memoria del navegador.',
          en: 'Key derived from your master password via PBKDF2 (100,000 iterations, SHA-256). The master password never leaves browser memory.',
        },
        icon: 'lock',
      },
      {
        title: { es: 'TOTP / 2FA integrado', en: 'Built-in TOTP / 2FA' },
        description: {
          es: 'Genera códigos de un solo uso directamente desde el vault, sin depender de una app externa.',
          en: 'Generate one-time codes directly from the vault, with no external app required.',
        },
        icon: 'shield',
      },
      {
        title: { es: 'Comprobación de filtraciones (HIBP)', en: 'Breach checking (HIBP)' },
        description: {
          es: 'Usa el modelo de k-anonimato de Have I Been Pwned: solo se envían 5 caracteres de un hash SHA-1, nunca tu contraseña.',
          en: 'Uses the Have I Been Pwned k-anonymity model: only 5 characters of a SHA-1 hash are sent, never your password.',
        },
        icon: 'search',
      },
      {
        title: { es: 'Análisis de fortaleza', en: 'Strength analysis' },
        description: {
          es: 'Detecta patrones débiles y contraseñas reutilizadas en tu vault.',
          en: 'Detects weak patterns and reused passwords across your vault.',
        },
        icon: 'bolt',
      },
      {
        title: { es: 'Generador de passphrases', en: 'Passphrase generator' },
        description: {
          es: 'Genera passphrases y contraseñas aleatorias seguras, configurables.',
          en: 'Generates secure passphrases and random passwords, fully configurable.',
        },
        icon: 'refresh',
      },
      {
        title: { es: 'Importación CSV', en: 'CSV import' },
        description: {
          es: 'Importa credenciales desde otros gestores de contraseñas sin salir del navegador.',
          en: 'Import credentials from other password managers without leaving the browser.',
        },
        icon: 'database',
      },
    ],
    howItWorks: [
      {
        title: { es: 'Crea tu vault', en: 'Create your vault' },
        description: {
          es: 'Defines una clave maestra; el vault se cifra en local con AES-256-GCM desde el primer segundo.',
          en: 'Set a master password; your vault is encrypted locally with AES-256-GCM from the very first second.',
        },
      },
      {
        title: { es: 'Guarda y genera', en: 'Save and generate' },
        description: {
          es: 'Añade credenciales existentes o genera contraseñas y passphrases seguras al vuelo.',
          en: 'Add existing credentials or generate secure passwords and passphrases on the fly.',
        },
      },
      {
        title: { es: 'Comprueba y protege', en: 'Check and protect' },
        description: {
          es: 'Analiza la fortaleza y consulta filtraciones (HIBP) sin que tu contraseña salga nunca del navegador.',
          en: 'Analyze strength and check for breaches (HIBP) without your password ever leaving the browser.',
        },
      },
    ],
    privacy: {
      intro: {
        es: 'Password Centinel es 100% local. No envía tus contraseñas, tu vault ni ningún dato personal a ningún sitio. Solo reporta un evento anónimo de instalación/actualización (versión y navegador) a un endpoint propio para saber cuánta gente usa la extensión.',
        en: 'Password Centinel is 100% local. It never sends your passwords, vault or personal data anywhere. It only reports a single anonymous install/update event (version and browser) to a first-party endpoint to gauge usage.',
      },
      points: [
        {
          es: 'El vault completo se guarda cifrado en el almacenamiento local del navegador (chrome.storage.local); no hay sincronización en la nube ni cuenta de usuario.',
          en: 'The full vault is stored encrypted in browser-local storage (chrome.storage.local); there is no cloud sync or user account.',
        },
        {
          es: 'La única llamada de red es la consulta k-anonimato a api.pwnedpasswords.com: se calcula el SHA-1 localmente y solo se envían los primeros 5 caracteres del hash.',
          en: 'The only network call is the k-anonymity lookup to api.pwnedpasswords.com: SHA-1 is computed locally and only the first 5 characters of the hash are sent.',
        },
        {
          es: 'No usa herramientas de tracking de terceros (sin Google Analytics, sin Sentry, sin cookies). El único evento reportado es la instalación/actualización, y nunca incluye datos de uso, dominios visitados ni nada del vault.',
          en: 'It uses no third-party tracking tools (no Google Analytics, no Sentry, no cookies). The only event reported is install/update, and it never includes usage data, visited domains or anything from the vault.',
        },
        {
          es: 'La importación de CSV y el manejo de claves se procesan enteramente en el navegador; los archivos que subes no se envían a ningún servidor.',
          en: 'CSV import and key handling are processed entirely in the browser; files you upload are never sent to a server.',
        },
      ],
    },
    permissions: [
      {
        name: 'storage',
        reason: {
          es: 'Guarda el vault cifrado, la configuración y el historial localmente en el navegador.',
          en: 'Stores the encrypted vault, settings and history locally in the browser.',
        },
      },
      {
        name: 'tabs',
        reason: {
          es: 'Identifica la pestaña activa para enviar/recibir mensajes de autocompletado y detección de formularios.',
          en: 'Identifies the active tab to send/receive autofill and form-detection messages.',
        },
      },
      {
        name: 'contextMenus',
        reason: {
          es: 'Añade las entradas "Generar y rellenar" / "Analizar contraseña" al menú contextual sobre campos editables.',
          en: 'Adds "Generate and fill" / "Analyze password" entries to the right-click menu on editable fields.',
        },
      },
      {
        name: 'activeTab',
        reason: {
          es: 'Permite que el popup interactúe con la página visible cuando el usuario lo invoca.',
          en: 'Lets the popup interact with the visible page when the user invokes it.',
        },
      },
      {
        name: 'host_permissions: <all_urls>',
        reason: {
          es: 'El content script necesita detectar campos de contraseña y formularios de login en cualquier sitio para ofrecer autocompletado.',
          en: 'The content script needs to detect password fields and login forms on any site to offer autofill.',
        },
      },
      {
        name: 'host_permissions: api.pwnedpasswords.com',
        reason: {
          es: 'Única petición de red de la extensión: consulta k-anonimato para comprobar filtraciones.',
          en: 'The extension\'s only network request: k-anonymity lookup to check for breaches.',
        },
      },
    ],
    faq: [
      {
        question: { es: '¿Es de pago?', en: 'Is it paid?' },
        answer: {
          es: 'No. Password Centinel es completamente gratuito.',
          en: 'No. Password Centinel is completely free.',
        },
      },
      {
        question: { es: '¿Funciona en Firefox?', en: 'Does it work on Firefox?' },
        answer: {
          es: 'Está desarrollado para Chrome y navegadores basados en Chromium (Edge, Brave, Opera).',
          en: 'It is built for Chrome and Chromium-based browsers (Edge, Brave, Opera).',
        },
      },
      {
        question: { es: '¿Qué datos recopila?', en: 'What data does it collect?' },
        answer: {
          es: 'Ninguno de tu vault: se guarda cifrado en local, y la única llamada de red es la consulta k-anonimato a Have I Been Pwned, que nunca revela tu contraseña completa. La extensión reporta además un evento anónimo de instalación/actualización (versión y navegador) para saber cuánta gente la usa.',
          en: 'None from your vault: it is stored encrypted locally, and the only network call is the k-anonymity lookup to Have I Been Pwned, which never reveals your full password. The extension also reports a single anonymous install/update event (version and browser) to gauge usage.',
        },
      },
      {
        question: { es: '¿Qué pasa si pierdo mi clave maestra?', en: 'What happens if I lose my master password?' },
        answer: {
          es: 'Al no existir cuenta ni servidor, no hay recuperación posible: la clave maestra es la única forma de descifrar el vault local.',
          en: 'Since there is no account or server, there is no recovery path: the master password is the only way to decrypt the local vault.',
        },
      },
    ],
    status: 'closed',
    iconPath: '/img/apps/password-centinel/icon.png',
    screenshots: [],
    links: {
      // Ficha ya publicada (aun bajo el nombre antiguo "Password Sentinel -
      // Mejorado"); se actualizara el nombre mostrado al subir la v1.0.0.
      chromeWebStore: 'https://chromewebstore.google.com/detail/fiephcocbhccfidlfnklglonoplmggcl',
    },
    stack: ['JavaScript', 'Chrome API', 'HIBP', 'AES-256-GCM'],
  },

  {
    id: 'prompt-master',
    name: 'PromptMaster',
    tagline: {
      es: 'Mejora tus prompts de IA con un solo atajo, en ChatGPT, Claude, Gemini y más',
      en: 'Enhance your AI prompts with one shortcut, on ChatGPT, Claude, Gemini and more',
    },
    description: {
      es: 'PromptMaster añade un sidebar y un botón "Enhance" a ChatGPT, Claude, Gemini, Copilot, Grok, DeepSeek, Perplexity y Mistral para transformar instrucciones básicas en prompts de nivel experto, con el atajo Ctrl+M. El plan Free ya es útil por sí solo; PRO (20€, pago único) añade mejoras y prompts guardados ilimitados, 20 prompts de alta conversión y 20 roles de IA de élite.',
      en: 'PromptMaster adds a sidebar and an "Enhance" button to ChatGPT, Claude, Gemini, Copilot, Grok, DeepSeek, Perplexity and Mistral to turn basic instructions into expert-level prompts, with the Ctrl+M shortcut. The Free plan is already useful on its own; PRO (€20, one-time) adds unlimited enhancements and saved prompts, 20 high-converting prompts and 20 elite AI roles.',
    },
    features: [
      {
        title: { es: 'Mejora instantánea con Ctrl + M', en: 'Instant enhancement with Ctrl + M' },
        description: {
          es: 'Pulsa el atajo en cualquier campo de texto de una plataforma de IA compatible y tu prompt se transforma en una instrucción de nivel experto en segundos.',
          en: 'Press the shortcut in any text field on a supported AI platform and your prompt is transformed into an expert-level instruction in seconds.',
        },
        icon: 'bolt',
      },
      {
        title: { es: 'Biblioteca de prompts guardados', en: 'Saved prompt library' },
        description: {
          es: 'Todos tus prompts mejorados se guardan automáticamente en el panel lateral. Cópialos, reúsalos o expórtalos como JSON con un clic.',
          en: 'All your enhanced prompts are automatically saved in the side panel. Copy, reuse, or export them as JSON with one click.',
        },
        icon: 'database',
      },
      {
        title: { es: '20 prompts PRO de alta conversión', en: '20 high-converting PRO prompts' },
        description: {
          es: 'Prompts probados para copywriting, SEO, email marketing, ventas y análisis de datos, listos para usar.',
          en: 'Battle-tested prompts for copywriting, SEO, email marketing, sales and data analysis, ready to use.',
        },
        icon: 'award',
      },
      {
        title: { es: '20 roles de IA de élite', en: '20 elite AI roles' },
        description: {
          es: 'Convierte a Claude o ChatGPT en un Tech Lead de Google, un CFO Partner de McKinsey o un Director Creativo de Apple.',
          en: 'Turn Claude or ChatGPT into a Google Tech Lead, a McKinsey CFO Partner, or an Apple Creative Director.',
        },
        icon: 'robot',
      },
      {
        title: { es: 'Compatible con 8 plataformas', en: 'Works on 8 platforms' },
        description: {
          es: 'ChatGPT, Claude, Gemini, Copilot, Grok, DeepSeek, Perplexity y Mistral, sin perder tu flujo de trabajo al cambiar.',
          en: 'ChatGPT, Claude, Gemini, Copilot, Grok, DeepSeek, Perplexity and Mistral, without losing your workflow when switching.',
        },
        icon: 'external',
      },
      {
        title: { es: '100% privado y local', en: '100% private and local' },
        description: {
          es: 'Sin cuenta obligatoria, sin rastreo de tus conversaciones. Tus prompts guardados viven en tu navegador, no en un servidor externo.',
          en: 'No mandatory account, no tracking of your conversations. Your saved prompts live in your browser, not on an external server.',
        },
        icon: 'lock',
      },
    ],
    howItWorks: [
      {
        title: { es: 'Escribe tu idea', en: 'Write your idea' },
        description: {
          es: 'Una instrucción básica en el campo de texto de tu plataforma de IA favorita.',
          en: 'A basic instruction in the text field of your favorite AI platform.',
        },
      },
      {
        title: { es: 'Pulsa Ctrl + M', en: 'Press Ctrl + M' },
        description: {
          es: 'El atajo transforma el texto en un prompt de nivel experto al instante.',
          en: 'The shortcut turns the text into an expert-level prompt instantly.',
        },
      },
      {
        title: { es: 'Guarda y reutiliza', en: 'Save and reuse' },
        description: {
          es: 'El resultado se guarda en tu biblioteca para usarlo cuando quieras.',
          en: 'The result is saved to your library for whenever you need it again.',
        },
      },
    ],
    privacy: {
      intro: {
        es: 'PromptMaster solo envía el texto del prompt que decides mejorar a su API de mejora; nunca lee ni almacena el resto de tu conversación.',
        en: 'PromptMaster only sends the prompt text you choose to enhance to its enhancement API; it never reads or stores the rest of your conversation.',
      },
      points: [
        {
          es: 'El texto enviado a la API de mejora se usa solo para procesar esa petición y no se almacena en los servidores.',
          en: 'The text sent to the enhancement API is used only to process that request and is not stored on the servers.',
        },
        {
          es: 'La activación PRO envía tu clave de licencia a la API de Gumroad solo para verificarla; no se guarda en ningún servidor propio.',
          en: 'PRO activation sends your license key to the Gumroad API only for verification; it is not stored on any first-party server.',
        },
        {
          es: 'No recopila nombre, email ni ningún dato de identificación personal, ni usa analítica de terceros (sin Google Analytics, sin Mixpanel).',
          en: 'It does not collect your name, email or any personal identifier, and uses no third-party analytics (no Google Analytics, no Mixpanel).',
        },
        {
          es: 'Los prompts guardados, el estado PRO y el contador de uso se guardan exclusivamente en el almacenamiento local del navegador.',
          en: 'Saved prompts, PRO status and the usage counter are stored exclusively in browser-local storage.',
        },
        {
          es: 'Reporta a un endpoint propio (api.eduolihez.com) eventos anónimos de instalación/actualización y de uso categorizado (p. ej. "se usó mejorar", "se guardó un prompt") para saber cómo se usa la extensión — nunca el texto de tus prompts ni las respuestas de la IA.',
          en: 'It reports anonymous install/update and categorized usage events (e.g. "enhance used", "prompt saved") to a first-party endpoint (api.eduolihez.com) to understand how the extension is used — never your prompt text or AI responses.',
        },
      ],
    },
    permissions: [
      {
        name: 'activeTab',
        reason: {
          es: 'Lee el texto del prompt en la pestaña activa e inyecta la versión mejorada en el campo de entrada.',
          en: 'Reads the prompt text on the active tab and injects the enhanced version back into the input field.',
        },
      },
      {
        name: 'sidePanel',
        reason: {
          es: 'Muestra la biblioteca de prompts guardados y el contenido PRO junto a la plataforma de IA.',
          en: 'Displays the saved prompt library and PRO content alongside the AI platform.',
        },
      },
      {
        name: 'storage',
        reason: {
          es: 'Guarda prompts, estado de licencia y contador de uso localmente en el navegador.',
          en: 'Saves prompts, license status and usage count locally in the browser.',
        },
      },
      {
        name: 'contextMenus',
        reason: {
          es: 'Añade la opción "Enhance Prompt" al menú contextual en las plataformas de IA compatibles.',
          en: 'Adds an "Enhance Prompt" option to the right-click menu on supported AI platforms.',
        },
      },
      {
        name: 'clipboardWrite',
        reason: {
          es: 'Copia un prompt guardado al portapapeles al pulsar el botón "Copiar".',
          en: 'Copies a saved prompt to the clipboard when clicking the "Copy" button.',
        },
      },
    ],
    faq: [
      {
        question: { es: '¿Es de pago?', en: 'Is it paid?' },
        answer: {
          es: 'Tiene un plan Free gratuito (5 mejoras/día, 3 prompts guardados) y un plan PRO de pago único de 20€, sin suscripción.',
          en: 'It has a free Free plan (5 enhancements/day, 3 saved prompts) and a one-time PRO plan for €20, no subscription.',
        },
      },
      {
        question: { es: '¿Funciona en Firefox?', en: 'Does it work on Firefox?' },
        answer: {
          es: 'Sí, hay versión para Chrome y para Firefox (addons.mozilla.org).',
          en: 'Yes, there is a version for Chrome and for Firefox (addons.mozilla.org).',
        },
      },
      {
        question: { es: '¿Qué datos recopila?', en: 'What data does it collect?' },
        answer: {
          es: 'Solo el texto del prompt que envías a mejorar (no se almacena) y, si activas PRO, tu clave de licencia para verificarla con Gumroad. No rastrea tus conversaciones.',
          en: 'Only the prompt text you send to enhance (not stored) and, if you activate PRO, your license key for Gumroad verification. It does not track your conversations.',
        },
      },
      {
        question: { es: '¿El pago de PRO es una suscripción?', en: 'Is the PRO payment a subscription?' },
        answer: {
          es: 'No, es un pago único de 20€ que incluye actualizaciones futuras.',
          en: 'No, it is a one-time €20 payment that includes future updates.',
        },
      },
    ],
    status: 'closed',
    iconPath: '/img/apps/prompt-master/icon.png',
    screenshots: [
      '/img/apps/prompt-master/screenshot-1.png',
      '/img/apps/prompt-master/screenshot-2.png',
      '/img/apps/prompt-master/screenshot-3.png',
      '/img/apps/prompt-master/screenshot-4.png',
    ],
    links: {
      firefoxAddons: 'https://addons.mozilla.org/es-ES/firefox/addon/promptmaster/',
    },
    stack: ['JavaScript', 'Chrome API', 'Tailwind'],
  },
];

export function getApp(id: string): AppData | undefined {
  return apps.find((a) => a.id === id);
}
