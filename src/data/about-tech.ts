/**
 * Contenido de "Sobre esta web".
 * ---------------------------------------------------------------------------
 * La pagina existe en tres idiomas. Antes cada uno llevaba su propio marcado,
 * asi que cualquier cambio habia que hacerlo tres veces y era cuestion de
 * tiempo que se descompasaran. Aqui esta el contenido una sola vez y las tres
 * paginas lo recorren.
 *
 * REGLA AL EDITAR: cada afirmacion de este archivo describe algo que esta
 * REALMENTE implementado en el repositorio, con el archivo donde vive. Es una
 * pagina que lee gente que sabe leer codigo: una linea de marketing que no se
 * sostenga al abrir el repositorio hace mas dano que no decir nada.
 */
import type { Localized } from '../i18n/utils';

export interface TechItem {
  /** Titulo corto del control (se muestra en negrita). */
  term: Localized;
  /** El "por que": que ataque o problema concreto evita. */
  detail: Localized;
  /** Archivo del repositorio donde esta implementado. */
  source?: string;
}

export interface TechSection {
  num: string;
  icon: string;
  /** Color de acento del bloque. */
  tone: 'accent' | 'cyan' | 'violet';
  title: Localized;
  intro: Localized;
  items: TechItem[];
}

export const techSections: TechSection[] = [
  // -------------------------------------------------------------------------
  {
    num: '01',
    icon: 'shield',
    tone: 'accent',
    title: {
      es: 'Superficie de ataque del frontend',
      en: 'Frontend attack surface',
      ca: "Superfície d'atac del frontend",
    },
    intro: {
      es: 'El sitio se compila a HTML plano, así que la mayor parte del riesgo clásico de servidor desaparece. Lo que queda se cierra por cabecera.',
      en: 'The site compiles to plain HTML, so most classic server-side risk disappears. What remains is closed off at the header level.',
      ca: "El lloc es compila a HTML pla, de manera que la major part del risc clàssic de servidor desapareix. El que queda es tanca per capçalera.",
    },
    items: [
      {
        term: {
          es: 'CSP con hashes recalculados en cada compilación',
          en: 'CSP with hashes recalculated on every build',
          ca: 'CSP amb hash recalculats a cada compilació',
        },
        detail: {
          es: 'script-src lleva el SHA-256 de cada script del sitio y no incluye ‘unsafe-inline’. Un <script> inyectado no se ejecuta: no puede llevar un hash que la política no conozca. Los hashes se generan solos al compilar, no se mantienen a mano.',
          en: 'script-src carries the SHA-256 of every script on the site and does not include ‘unsafe-inline’. An injected <script> will not run: it cannot carry a hash the policy does not already know. The hashes are generated at build time, not maintained by hand.',
          ca: "script-src porta el SHA-256 de cada script del lloc i no inclou ‘unsafe-inline’. Un <script> injectat no s'executa: no pot portar un hash que la política no conegui. Els hash es generen sols en compilar, no es mantenen a mà.",
        },
        source: 'astro.config.mjs',
      },
      {
        term: {
          es: 'HSTS a un año, deliberadamente sin preload',
          en: 'One-year HSTS, deliberately without preload',
          ca: 'HSTS a un any, deliberadament sense preload',
        },
        detail: {
          es: 'includeSubDomains activo. Se deja fuera de la lista de precarga a proposito: entrar es fácil y salir tarda meses, y para un portfolio ese compromiso no compensa.',
          en: 'includeSubDomains is on. It is deliberately kept out of the preload list: getting in is easy and getting out takes months, and for a portfolio that trade-off is not worth it.',
          ca: "includeSubDomains actiu. Es deixa fora de la llista de precàrrega expressament: entrar-hi és fàcil i sortir-ne triga mesos, i per a un portfolio aquest compromís no compensa.",
        },
        source: 'server/.htaccess',
      },
      {
        term: {
          es: 'Aislamiento del documento',
          en: 'Document isolation',
          ca: 'Aïllament del document',
        },
        detail: {
          es: 'X-Frame-Options DENY contra clickjacking, Cross-Origin-Opener-Policy y Cross-Origin-Resource-Policy en same-origin, y Permissions-Policy que apaga geolocalización, micrófono y cámara aunque nada las pida.',
          en: 'X-Frame-Options DENY against clickjacking, Cross-Origin-Opener-Policy and Cross-Origin-Resource-Policy set to same-origin, and a Permissions-Policy that switches off geolocation, microphone and camera even though nothing requests them.',
          ca: "X-Frame-Options DENY contra el clickjacking, Cross-Origin-Opener-Policy i Cross-Origin-Resource-Policy en same-origin, i Permissions-Policy que apaga geolocalització, micròfon i càmera encara que res no les demani.",
        },
        source: 'server/.htaccess',
      },
      {
        term: {
          es: 'Nada de terceros',
          en: 'No third parties',
          ca: 'Res de tercers',
        },
        detail: {
          es: 'Sin CDN, sin Google Fonts, sin etiquetas de analítica externa. Las tipografías van autoalojadas con subset latino. Cada dominio que se quita es un tercero menos que puede caerse, cambiar el archivo que sirve o registrar la IP del visitante.',
          en: 'No CDN, no Google Fonts, no external analytics tags. Typefaces are self-hosted with a Latin subset. Every domain removed is one less third party that can go down, swap the file it serves, or log the visitor IP.',
          ca: "Sense CDN, sense Google Fonts, sense etiquetes d'analítica externa. Les tipografies van autoallotjades amb subset llatí. Cada domini que es treu és un tercer menys que pot caure, canviar el fitxer que serveix o registrar la IP del visitant.",
        },
      },
      {
        term: {
          es: 'Filtrado de proyectos interactivo en cliente sin estado',
          en: 'Stateless client-side project filtering',
          ca: 'Filtratge de projectes interactiu en client sense estat',
        },
        detail: {
          es: 'El filtrado de proyectos por etiquetas se ejecuta íntegramente en el navegador mediante manipulación de clases CSS. Evita guardar estados en sesión o realizar consultas HTTP adicionales para re-renderizar, minimizando la transferencia de datos y la carga del servidor.',
          en: 'Project filtering by tags runs entirely in the browser using CSS class manipulation. This avoids storing session states or making additional HTTP requests to re-render, minimizing data transfer and server load.',
          ca: 'El filtratge de projectes per etiquetes s’executa íntegrament al navegador mitjançant manipulació de classes CSS. Evita desar estats en sessió o fer consultes HTTP addicionals per re-renderitzar, minimitzant la transferència de dades i la càrrega del servidor.',
        },
        source: 'src/components/Projects.astro',
      },
    ],
  },

  // -------------------------------------------------------------------------
  {
    num: '02',
    icon: 'lock',
    tone: 'cyan',
    title: {
      es: 'Panel de administración',
      en: 'Admin panel',
      ca: "Consola d'administració",
    },
    intro: {
      es: 'La parte con acceso a la base de datos y a las subidas. Aquí es donde de verdad importa el detalle.',
      en: 'The part with access to the database and to uploads. This is where the details actually matter.',
      ca: "La part amb accés a la base de dades i a les pujades. Aquí és on el detall importa de debò.",
    },
    items: [
      {
        term: {
          es: 'Consultas preparadas reales, no emuladas',
          en: 'Real prepared statements, not emulated',
          ca: 'Consultes preparades reals, no emulades',
        },
        detail: {
          es: 'PDO con ATTR_EMULATE_PREPARES a false. Con la emulacion activada el driver interpola los valores en el cliente antes de enviarlos, y esa interpolación es justo donde han vivido históricamente los saltos de entrecomillado en ciertos juegos de caracteres.',
          en: 'PDO with ATTR_EMULATE_PREPARES set to false. With emulation on, the driver interpolates values client-side before sending them, and that interpolation is exactly where quote-escaping breakouts have historically lived in certain character sets.',
          ca: "PDO amb ATTR_EMULATE_PREPARES a false. Amb l'emulació activada el driver interpola els valors al client abans d'enviar-los, i aquesta interpolació és justament on han viscut històricament els salts d'entrecometat en certs jocs de caràcters.",
        },
        source: 'server/db.php',
      },
      {
        term: {
          es: 'Login que no revela si el usuario existe',
          en: 'Login that does not reveal whether a user exists',
          ca: 'Login que no revela si l’usuari existeix',
        },
        detail: {
          es: 'Contra un usuario inexistente se verifica igualmente un hash ficticio. Sin ese paso, la respuesta vuelve antes cuando el usuario no existe y el tiempo permite enumerar cuentas validas. Las contraseñas van con bcrypt y se rehashean solas si sube el coste.',
          en: 'For a non-existent user, a dummy hash is verified anyway. Without that step the response comes back sooner when the user does not exist, and the timing lets you enumerate valid accounts. Passwords use bcrypt and are transparently rehashed if the cost goes up.',
          ca: "Contra un usuari inexistent es verifica igualment un hash fictici. Sense aquest pas, la resposta torna abans quan l'usuari no existeix i el temps permet enumerar comptes vàlids. Les contrasenyes van amb bcrypt i es rehashegen soles si puja el cost.",
        },
        source: 'server/admin/auth.php',
      },
      {
        term: {
          es: 'CSRF en tiempo constante, con el caso vacío cubierto',
          en: 'Constant-time CSRF, with the empty case covered',
          ca: 'CSRF en temps constant, amb el cas buit cobert',
        },
        detail: {
          es: 'El token se compara con hash_equals. Además se exige que el de la sesión exista y no esté vacío: sin esa condición, una petición sin cookie creaba una sesión nueva con el token a cadena vacía y la comparación de dos cadenas vacías devolvía cierto, dejando pasar la petición.',
          en: 'The token is compared with hash_equals. It also requires the session token to exist and be non-empty: without that condition, a request with no cookie created a fresh session with an empty token, and comparing two empty strings returned true, letting the request through.',
          ca: "El token es compara amb hash_equals. A més s'exigeix que el de la sessió existeixi i no estigui buit: sense aquesta condició, una petició sense galeta creava una sessió nova amb el token a cadena buida i la comparació de dues cadenes buides retornava cert, deixant passar la petició.",
        },
        source: 'server/admin/auth.php',
      },
      {
        term: {
          es: 'Sesiones endurecidas y con caducidad doble',
          en: 'Hardened sessions with a double expiry',
          ca: 'Sessions endurides i amb caducitat doble',
        },
        detail: {
          es: 'Regeneración del identificador tras el login (fijación de sesión), cookies HttpOnly, Secure y SameSite=Lax, use_strict_mode para que nadie imponga un identificador propio, y cierre tanto por inactividad como por duración máxima absoluta.',
          en: 'Session ID regenerated after login (session fixation), HttpOnly, Secure and SameSite=Lax cookies, use_strict_mode so nobody can impose their own ID, and expiry both on idle time and on absolute maximum duration.',
          ca: "Regeneració de l'identificador després del login (fixació de sessió), galetes HttpOnly, Secure i SameSite=Lax, use_strict_mode perquè ningú no imposi un identificador propi, i tancament tant per inactivitat com per durada màxima absoluta.",
        },
        source: 'server/admin/auth.php',
      },
      {
        term: {
          es: 'Bloqueo de fuerza bruta por IP',
          en: 'Per-IP brute-force lockout',
          ca: 'Bloqueig de força bruta per IP',
        },
        detail: {
          es: 'Los intentos fallidos se cuentan en una ventana temporal y bloquean la IP al superar el umbral. La IP se toma de REMOTE_ADDR salvo que se declare explicitamente un proxy de confianza: fiarse de X-Forwarded-For sin proxy delante permite falsear la IP y saltarse el límite entero.',
          en: 'Failed attempts are counted within a time window and lock the IP once the threshold is passed. The IP comes from REMOTE_ADDR unless a trusted proxy is explicitly declared: trusting X-Forwarded-For with no proxy in front lets anyone spoof their IP and skip the limit entirely.',
          ca: "Els intents fallits es compten en una finestra temporal i bloquegen la IP en superar el llindar. La IP es pren de REMOTE_ADDR llevat que es declari explícitament un proxy de confiança: fiar-se de X-Forwarded-For sense proxy al davant permet falsejar la IP i saltar-se el límit sencer.",
        },
        source: 'server/lib/http.php',
      },
      {
        term: {
          es: 'Markdown seguro en el banner superior',
          en: 'Secure Markdown in the announcement banner',
          ca: 'Markdown segur al bàner superior',
        },
        detail: {
          es: 'El texto del banner superior se edita en Markdown y se parsea en el navegador. Antes de la conversión a HTML (enlaces, negritas, código), la cadena se escapa completamente contra XSS, impidiendo que una potencial inyección en base de datos ejecute código script.',
          en: 'The top banner text is edited in Markdown and parsed in the browser. Before converting to HTML (links, bold, code), the string is fully escaped against XSS, preventing any potential database injection from executing script code.',
          ca: 'El text del bàner superior s’edita en Markdown i es parseja al navegador. Abans de la conversió a HTML (enllaços, negretes, codi), la cadena s’escapa completament contra XSS, impedint que una potencial injecció en base de dades executi codi script.',
        },
        source: 'src/components/Announcement.astro',
      },
      {
        term: {
          es: 'Controlador preventivo de migraciones de base de datos',
          en: 'Preventative database migration handler',
          ca: 'Controlador preventiu de migracions de base de dades',
        },
        detail: {
          es: 'El script de inicialización verifica las tablas y columnas necesarias al cargar el panel de administración. Si falta alguna columna (por ejemplo, tras desplegar cambios del esquema), muestra una pantalla de mantenimiento con instrucciones de migración seguras en vez de un fallo fatal de SQL.',
          en: 'The bootstrap script verifies all required tables and columns when loading the admin panel. If any column is missing (e.g. after deploying schema updates), it displays a maintenance notice with safe migration instructions instead of a fatal SQL failure.',
          ca: 'El script d’inicialització verifica les taules i columnes necessàries en carregar la consola d’administració. Si falta alguna columna (per exemple, després de desplegar canvis de l’esquema), mostra una pantalla de manteniment amb instruccions de migració segures en comptes d’una fallada fatal de SQL.',
        },
        source: 'server/lib/bootstrap.php',
      },
    ],
  },

  // -------------------------------------------------------------------------
  {
    num: '03',
    icon: 'database',
    tone: 'violet',
    title: {
      es: 'Contenido que no me pertenece',
      en: 'Content I do not control',
      ca: 'Contingut que no em pertany',
    },
    intro: {
      es: 'Imágenes subidas al panel y mensajes escritos por desconocidos: todo lo que entra desde fuera se trata como hostil hasta que se demuestre lo contrario.',
      en: 'Images uploaded through the panel and messages written by strangers: anything arriving from outside is treated as hostile until proven otherwise.',
      ca: "Imatges pujades a la consola i missatges escrits per desconeguts: tot el que entra de fora es tracta com a hostil fins que es demostri el contrari.",
    },
    items: [
      {
        term: {
          es: 'Las imágenes se validan por contenido, no por extension',
          en: 'Images are validated by content, not by extension',
          ca: 'Les imatges es validen per contingut, no per extensió',
        },
        detail: {
          es: 'Primero el tipo MIME real con finfo, y después getimagesize(), que solo reconoce imágenes de verdad. Un polyglot con cabecera GIF falsificada pasa el primer filtro pero no el segundo. Hay además un tope de dimensiones para que nadie tumbe el servidor con una imagen de 30000 px de lado.',
          en: 'First the real MIME type via finfo, then getimagesize(), which only recognises genuine images. A polyglot with a forged GIF header passes the first check but not the second. There is also a dimension cap so nobody can take the server down with a 30000 px image.',
          ca: "Primer el tipus MIME real amb finfo, i després getimagesize(), que només reconeix imatges de debò. Un polyglot amb capçalera GIF falsificada passa el primer filtre però no el segon. Hi ha a mes un topall de dimensions perquè ningú no tombi el servidor amb una imatge de 30000 px de costat.",
        },
        source: 'server/lib/upload.php',
      },
      {
        term: {
          es: 'La carpeta de subidas no ejecuta código',
          en: 'The uploads folder does not execute code',
          ca: 'La carpeta de pujades no executa codi',
        },
        detail: {
          es: 'Defensa en profundidad: aunque la validación fallara y se colara un .php, el .htaccess de esa carpeta retira los handlers y apaga el motor, así que se serviría como texto plano. Los archivos se guardan con nombre aleatorio, nunca con el que envia el cliente.',
          en: 'Defence in depth: even if validation failed and a .php slipped through, that folder’s .htaccess strips the handlers and switches the engine off, so it would be served as plain text. Files are stored under a random name, never the one the client sent.',
          ca: "Defensa en profunditat: encara que la validació fallés i s'hi colés un .php, el .htaccess d'aquella carpeta retira els handlers i apaga el motor, de manera que es serviria com a text pla. Els fitxers es desen amb nom aleatori, mai amb el que envia el client.",
        },
        source: 'server/uploads/.htaccess',
      },
      {
        term: {
          es: 'El formulario no puede convertirse en un relay de spam',
          en: 'The contact form cannot become a spam relay',
          ca: 'El formulari no pot convertir-se en un relay de spam',
        },
        detail: {
          es: 'Se eliminan saltos de línea y caracteres de control antes de que ningún valor toque una cabecera de correo. Sin ese saneado, un nombre con CRLF permite inyectar cabeceras (un Bcc:, por ejemplo) y usar el formulario para enviar correo a terceros.',
          en: 'Line breaks and control characters are stripped before any value touches an email header. Without that, a name containing CRLF lets you inject headers (a Bcc:, for instance) and use the form to send mail to third parties.',
          ca: "S'eliminen salts de línia i caràcters de control abans que cap valor toqui una capçalera de correu. Sense aquest sanejament, un nom amb CRLF permet injectar capçaleres (un Bcc:, per exemple) i fer servir el formulari per enviar correu a tercers.",
        },
        source: 'server/api/contact.php',
      },
      {
        term: {
          es: 'Exportaciones CSV sin inyección de fórmulas',
          en: 'CSV exports without formula injection',
          ca: 'Exportacions CSV sense injecció de formules',
        },
        detail: {
          es: 'Excel y LibreOffice ejecutan como fórmula cualquier celda que empiece por =, +, - o @. Como el buzón exporta texto escrito por desconocidos, esas celdas se prefijan para que se traten como texto y no como código al abrir el archivo.',
          en: 'Excel and LibreOffice execute any cell starting with =, +, - or @ as a formula. Since the inbox exports text written by strangers, those cells are prefixed so they are treated as text rather than code when the file is opened.',
          ca: "Excel i LibreOffice executen com a formula qualsevol cel·la que comenci per =, +, - o @. Com que la safata exporta text escrit per desconeguts, aquestes cel·les es prefixen perquè es tractin com a text i no com a codi en obrir el fitxer.",
        },
        source: 'server/admin/partials/layout.php',
      },
    ],
  },

  // -------------------------------------------------------------------------
  {
    num: '04',
    icon: 'award',
    tone: 'accent',
    title: {
      es: 'Analítica propia y privacidad',
      en: 'First-party analytics and privacy',
      ca: 'Analítica pròpia i privacitat',
    },
    intro: {
      es: 'Saber cuanta gente entra no exige montar un perfil de nadie. La analítica es propia y guarda lo mínimo.',
      en: 'Knowing how many people visit does not require profiling anyone. Analytics are first-party and store the bare minimum.',
      ca: "Saber quanta gent hi entra no exigeix muntar el perfil de ningú. L'analítica és pròpia i desa el mínim.",
    },
    items: [
      {
        term: {
          es: 'La dirección IP no se almacena',
          en: 'The IP address is never stored',
          ca: "L'adreça IP no s'emmagatzema",
        },
        detail: {
          es: 'Se guarda un SHA-256 de la IP con una sal del servidor. Sirve para contar visitantes únicos aproximados y para frenar floods, pero no permite reconstruir la dirección ni cruzarla con otra base de datos.',
          en: 'A SHA-256 of the IP with a server-side salt is stored instead. It is enough to count approximate unique visitors and to throttle floods, but it cannot be reversed to the address or cross-referenced against another database.',
          ca: "Es desa un SHA-256 de la IP amb una sal del servidor. Serveix per comptar visitants únics aproximats i per frenar floods, però no permet reconstruir l'adreça ni creuar-la amb cap altra base de dades.",
        },
        source: 'server/api/visit.php',
      },
      {
        term: {
          es: 'Sin cookies de seguimiento y con Do Not Track respetado',
          en: 'No tracking cookies, and Do Not Track honoured',
          ca: 'Sense galetes de seguiment i amb Do Not Track respectat',
        },
        detail: {
          es: 'No hay banner de consentimiento porque no hay nada que consentir. Si el navegador envia la señal Do Not Track, la visita ni siquiera se registra.',
          en: 'There is no consent banner because there is nothing to consent to. If the browser sends the Do Not Track signal, the visit is not recorded at all.',
          ca: "No hi ha bàner de consentiment perquè no hi ha res a consentir. Si el navegador envia el senyal Do Not Track, la visita ni tan sols es registra.",
        },
      },
      {
        term: {
          es: 'La sesión vive y muere con la pestaña',
          en: 'The session lives and dies with the tab',
          ca: 'La sessió viu i mor amb la pestanya',
        },
        detail: {
          es: 'Para saber si dos páginas vistas son la misma visita, el navegador guarda un identificador aleatorio en sessionStorage (no localStorage, no una cookie). Técnicamente sigue siendo "almacenamiento en el equipo" bajo la ePrivacy, pero al morir al cerrar la pestaña y no combinarse nunca con otra visita, encaja en la excepción de medición de audiencia que reconocen la mayoría de autoridades de protección de datos de la UE: por eso no cambia la respuesta de arriba.',
          en: 'To know whether two pageviews belong to the same visit, the browser keeps a random id in sessionStorage (not localStorage, not a cookie). That is technically still "storage on the device" under ePrivacy, but since it dies when the tab closes and is never combined with another visit, it fits the audience-measurement exemption most EU data protection authorities recognise — which is why the answer above still holds.',
          ca: 'Per saber si dues pàgines vistes són la mateixa visita, el navegador desa un identificador aleatori a sessionStorage (no localStorage, no una galeta). Tècnicament segueix sent "emmagatzematge a l\'equip" sota l\'ePrivacy, però en morir en tancar la pestanya i no combinar-se mai amb una altra visita, encaixa en l\'excepció de mesura d\'audiència que reconeixen la majoria d\'autoritats de protecció de dades de la UE: per això no canvia la resposta d\'aquí dalt.',
        },
        source: 'src/scripts/analytics.ts',
      },
      {
        term: {
          es: 'Del referrer se descarta la query',
          en: 'Query strings are dropped from the referrer',
          ca: 'Del referrer es descarta la query',
        },
        detail: {
          es: 'Solo se conserva esquema, host y ruta. Los parámetros de una URL ajena suelen llevar identificadores de sesión o de campaña, y no hay ninguna razón para que acaben en mi base de datos.',
          en: 'Only scheme, host and path are kept. Query parameters from someone else’s URL often carry session or campaign identifiers, and there is no reason for those to end up in my database.',
          ca: "Només es conserva esquema, host i ruta. Els paràmetres d'una URL aliena solen portar identificadors de sessió o de campanya, i no hi ha cap raó perquè acabin a la meva base de dades.",
        },
        source: 'server/api/visit.php',
      },
      {
        term: {
          es: 'Retención acotada y purga automática',
          en: 'Bounded retention with automatic purging',
          ca: 'Retenció acotada i purga automàtica',
        },
        detail: {
          es: 'Las visitas se borran a los 400 días, los intentos de login a los 90 y el registro de auditoría al año. La purga va incorporada en el propio flujo, sin depender de un cron que nadie recuerda revisar.',
          en: 'Visits are deleted after 400 days, login attempts after 90, and the audit log after a year. Purging is built into the request flow itself, with no cron job that nobody remembers to check.',
          ca: "Les visites s'esborren als 400 dies, els intents de login als 90 i el registre d'auditoria a l'any. La purga va incorporada al mateix flux, sense dependre d'un cron que ningú no recorda revisar.",
        },
        source: 'server/api/visit.php',
      },
    ],
  },

  // -------------------------------------------------------------------------
  {
    num: '05',
    icon: 'search',
    tone: 'cyan',
    title: {
      es: 'SEO técnico',
      en: 'Technical SEO',
      ca: 'SEO tècnic',
    },
    intro: {
      es: 'Un portfolio que no aparece no sirve de nada. El posicionamiento aquí es una cuestión de estructura, no de repetir palabras clave.',
      en: 'A portfolio nobody finds is useless. Ranking here is a question of structure, not of repeating keywords.',
      ca: "Un portfolio que no apareix no serveix de res. El posicionament aquí és una qüestió d'estructura, no de repetir paraules clau.",
    },
    items: [
      {
        term: {
          es: 'Un único grafo de datos estructurados',
          en: 'A single structured-data graph',
          ca: 'Un únic graf de dades estructurades',
        },
        detail: {
          es: 'Person, WebSite, ProfilePage, BreadcrumbList y FAQPage viajan en un solo bloque JSON-LD enlazado por @id, en vez de en bloques sueltos que pueden contradecirse entre si. Cada artículo del blog anade además su propio BlogPosting.',
          en: 'Person, WebSite, ProfilePage, BreadcrumbList and FAQPage travel in one JSON-LD block linked by @id, rather than as separate blocks that can contradict each other. Each blog article additionally emits its own BlogPosting.',
          ca: "Person, WebSite, ProfilePage, BreadcrumbList i FAQPage viatgen en un sol bloc JSON-LD enllaçat per @id, en comptes de blocs solts que poden contradir-se entre ells. Cada article del blog hi afegeix el seu propi BlogPosting.",
        },
        source: 'src/components/Seo.astro',
      },
      {
        term: {
          es: '410 Gone en lugar de 404 para lo retirado',
          en: '410 Gone instead of 404 for withdrawn pages',
          ca: '410 Gone en lloc de 404 per al que s’ha retirat',
        },
        detail: {
          es: 'Dos proyectos se retiraron del sitio con sus URLs ya indexadas. Un 404 le dice al buscador que la página podría volver, así que la reintenta durante semanas; un 410 le dice que la retirada és deliberada y definitiva, y la saca del índice bastante antes.',
          en: 'Two projects were withdrawn with their URLs already indexed. A 404 tells the crawler the page might come back, so it keeps retrying for weeks; a 410 says the removal is deliberate and permanent, and gets it out of the index far sooner.',
          ca: "Dos projectes es van retirar del lloc amb les URL ja indexades. Un 404 diu al cercador que la pàgina podria tornar, i la reintenta durant setmanes; un 410 li diu que la retirada és deliberada i definitiva, i la treu de l'índex força abans.",
        },
        source: 'server/.htaccess',
      },
      {
        term: {
          es: 'hreflang reciproco, y solo donde existe traducción',
          en: 'Reciprocal hreflang, and only where a translation exists',
          ca: 'hreflang reciproc, i només on hi ha traducció',
        },
        detail: {
          es: 'Cada página traducida declara a todas sus hermanas y un x-default. Las que existen en un solo idioma no declaran ninguna: anunciar un alterno que no existe rompe el grupo entero, y Google entonces lo descarta completo.',
          en: 'Every translated page declares all its siblings plus an x-default. Pages that exist in one language only declare none: announcing an alternate that does not exist breaks the whole group, and Google then discards all of it.',
          ca: "Cada pàgina traduïda declara totes les seves germanes i un x-default. Les que existeixen en un sol idioma no en declaren cap: anunciar un alternatiu que no existeix trenca el grup sencer, i Google llavors el descarta del tot.",
        },
        source: 'src/pages/sitemap.xml.ts',
      },
      {
        term: {
          es: 'SEO local con señales coherentes',
          en: 'Local SEO with consistent signals',
          ca: 'SEO local amb senyals coherents',
        },
        detail: {
          es: 'Badalona y Barcelona aparecen en el titulo, en la descripción, en las etiquetas geo y dentro del bloque Person con address, homeLocation y areaServed. La señal importa cuando es la misma en todos los sitios, no cuando se repite en uno.',
          en: 'Badalona and Barcelona appear in the title, the description, the geo tags and inside the Person block via address, homeLocation and areaServed. The signal counts when it is consistent everywhere, not when it is repeated in one place.',
          ca: "Badalona i Barcelona apareixen al títol, a la descripció, a les etiquetes geo i dins del bloc Person amb address, homeLocation i areaServed. El senyal importa quan és el mateix a tot arreu, no quan es repeteix en un sol lloc.",
        },
        source: 'src/config.ts',
      },
    ],
  },

  // -------------------------------------------------------------------------
  {
    num: '06',
    icon: 'robot',
    tone: 'violet',
    title: {
      es: 'Legible para modelos de lenguaje',
      en: 'Readable by language models',
      ca: 'Llegible per a models de llenguatge',
    },
    intro: {
      es: 'Cada vez se pregunta más a un asistente y menos a un buscador. Si la respuesta sobre mi la va a dar una IA, prefiero que lea datos ordenados y no que improvise.',
      en: 'People increasingly ask an assistant instead of a search engine. If an AI is going to answer questions about me, I would rather it read structured facts than improvise.',
      ca: "Cada cop es pregunta més a un assistent i menys a un cercador. Si la resposta sobre mi l'ha de donar una IA, prefereixo que llegeixi dades ordenades i no que improvisi.",
    },
    items: [
      {
        term: {
          es: 'llms.txt generado en cada compilación',
          en: 'llms.txt generated on every build',
          ca: 'llms.txt generat a cada compilació',
        },
        detail: {
          es: 'Un resumen en texto plano siguiendo la convencion de llmstxt.org, sin HTML ni ruido. Sale de las mismas fuentes que alimentan la web, así que no puede quedarse desfasado respecto a lo que se ve en pantalla.',
          en: 'A plain-text summary following the llmstxt.org convention, with no HTML or noise. It is generated from the same sources that feed the site, so it cannot drift out of sync with what is on screen.',
          ca: "Un resum en text pla seguint la convenció de llmstxt.org, sense HTML ni soroll. Surt de les mateixes fonts que alimenten el web, així que no pot quedar desfasat respecte del que es veu a la pantalla.",
        },
        source: 'src/pages/llms.txt.ts',
      },
      {
        term: {
          es: 'Política explicita para rastreadores de IA',
          en: 'An explicit policy for AI crawlers',
          ca: 'Política explicita per a rastrejadors d’IA',
        },
        detail: {
          es: 'GPTBot, ClaudeBot, PerplexityBot, Google-Extended y Applebot tienen permiso escrito. Los rastreadores de SEO comercial, que solo consumen ancho de banda del hosting compartido, están bloqueados. Es una decisión tomada, no el resultado de no haber tocado el archivo.',
          en: 'GPTBot, ClaudeBot, PerplexityBot, Google-Extended and Applebot are explicitly allowed. Commercial SEO crawlers, which only burn shared-hosting bandwidth, are blocked. It is a decision taken, not the result of never touching the file.',
          ca: "GPTBot, ClaudeBot, PerplexityBot, Google-Extended i Applebot tenen permís escrit. Els rastrejadors de SEO comercial, que només consumeixen amplada de banda de l'allotjament compartit, estan bloquejats. És una decisió presa, no el resultat de no haver tocat el fitxer.",
        },
        source: 'public/robots.txt',
      },
      {
        term: {
          es: 'Divulgación de vulnerabilidades por RFC 9116',
          en: 'Vulnerability disclosure via RFC 9116',
          ca: 'Divulgació de vulnerabilitats per RFC 9116',
        },
        detail: {
          es: 'Un /.well-known/security.txt con contacto, idiomas y fecha de caducidad. Es lo primero que busca quien encuentra un fallo y quiere reportarlo bien; no tenerlo es la razón habitual de que un aviso acabe en un formulario genérico o en ninguna parte.',
          en: 'A /.well-known/security.txt with contact, languages and an expiry date. It is the first thing someone looks for when they find a flaw and want to report it properly; not having one is the usual reason a report ends up in a generic form or nowhere at all.',
          ca: "Un /.well-known/security.txt amb contacte, idiomes i data de caducitat. És el primer que busca qui troba una fallada i la vol reportar bé; no tenir-lo és la raó habitual que un avis acabi en un formulari generic o enlloc.",
        },
        source: 'public/.well-known/security.txt',
      },
      {
        term: {
          es: 'Análisis estático en cada push',
          en: 'Static analysis on every push',
          ca: 'Anàlisi estàtica a cada push',
        },
        detail: {
          es: 'CodeQL cubre el frontend en TypeScript y JavaScript. Como CodeQL no analiza PHP, el backend lo revisa Semgrep con reglas de inyección, XSS y secretos, y ambos resultados llegan en formato SARIF a la misma pestaña. Dependabot vigila las dependencias cada semana.',
          en: 'CodeQL covers the TypeScript and JavaScript frontend. Since CodeQL has no PHP analyser, the backend is reviewed by Semgrep with injection, XSS and secret-detection rules, and both sets of findings land in the same tab as SARIF. Dependabot watches dependencies weekly.',
          ca: "CodeQL cobreix el frontend en TypeScript i JavaScript. Com que CodeQL no analitza PHP, el backend el revisa Semgrep amb regles d'injecció, XSS i secrets, i tots dos resultats arriben en format SARIF a la mateixa pestanya. Dependabot vigila les dependencies cada setmana.",
        },
        source: '.github/workflows/codeql.yml',
      },
    ],
  },
];

/** Resumen del stack, para la tabla de cabecera. */
export const stackRows: { label: Localized; value: string }[] = [
  {
    label: { es: 'Frontend', en: 'Frontend', ca: 'Frontend' },
    value: 'Astro 7 (SSG) · Tailwind CSS 4 · TypeScript',
  },
  {
    label: { es: 'Backend', en: 'Backend', ca: 'Backend' },
    value: 'PHP 8 (PDO) · MySQL / MariaDB · sin framework',
  },
  {
    label: { es: 'Infraestructura', en: 'Infrastructure', ca: 'Infraestructura' },
    value: 'CDMON · Apache · Cloudflare · TLS',
  },
  {
    label: { es: 'Idiomas', en: 'Languages', ca: 'Idiomes' },
    value: 'Español · English · Català',
  },
];

/**
 * Puntuaciones reales de Lighthouse contra la produccion (https://eduolihez.com/),
 * vista Movil -- la API de PageSpeed Insights sin clave da 429 (cuota diaria a
 * 0), asi que se midio con `npx lighthouse` contra Chrome, que es el mismo
 * motor y la misma escala 0-100 que ensena PageSpeed Insights.
 *
 * Orden fijo: Rendimiento, Accesibilidad, Buenas practicas, SEO -- coincide
 * con el orden de `labels.metrics` en cada pagina que consume este archivo.
 * No se recalculan en cada build: son una foto de un momento, tal como avisa
 * metricsNote. Actualizar a mano si se vuelve a medir.
 */
export const pagespeedScores = {
  measuredAt: '2026-08-23',
  strategy: 'mobile' as const,
  values: [66, 96, 92, 100],
};
