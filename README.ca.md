<div align="center">

# eduolihez.com

**Wiki i portfolio professional d'Eduardo Olivares Hernández**, analista SOC / Blue Team

[![Web](https://img.shields.io/badge/web-eduolihez.com-4ade80?style=flat-square)](https://eduolihez.com)
[![Astro](https://img.shields.io/badge/Astro-7-BC52EE?style=flat-square&logo=astro&logoColor=white)](https://astro.build)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com)
[![PHP](https://img.shields.io/badge/PHP-8-777BB4?style=flat-square&logo=php&logoColor=white)](https://www.php.net)
[![CodeQL](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml)
[![Tests](https://github.com/eduolihez/eduolihez.com/actions/workflows/test.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

---

### [English version](README.en.md) · **[Versió en Català](README.ca.md)** · [Versión en Español](README.md)

</div>

---

Aquest és el codi font d'**eduolihez.com**, el lloc web personal i portfolio d'Eduardo
Olivares, disponible en català, espanyol i anglès.

El lloc està dissenyat seguint el principi de defensa en profunditat, i serveix també
com a demostració de seguretat ofensiva, hardening de servidors i desenvolupament web
segur. Els detalls tècnics del disseny es descriuen a
[eduolihez.com/ca/sobre-aquesta-web](https://eduolihez.com/ca/sobre-aquesta-web/).

---

## Índex
1. [Arquitectura i flux de treball](#arquitectura-i-flux-de-treball)
2. [Estructura del projecte](#estructura-del-projecte)
3. [Hardening](#hardening)
4. [Administració i base de dades](#administració-i-base-de-dades)
5. [SEO tècnic i rastreig per IA](#seo-tècnic-i-rastreig-per-ia)
6. [Instal·lació i desplegament](#installació-i-desplegament)
7. [Més documentació](#més-documentació)
8. [Llicència](#llicència)

---

## Arquitectura i flux de treball

El projecte combina un generador de llocs estàtics amb un backend propi per al
contingut dinàmic:

```
┌─ src/          Astro (Frontend) · Compila a HTML estàtic ─► dist/ ──► Servidor Apache ─┐
│                                                                                         │
│                                                                               ┌─────────▼────────┐
│  fetch /api/*.php  ◄──────────────────────────────────────────────────────────┤  CDMON / Allotja │
│                                                                               │  Cloudflare / TLS│
└─ server/       PHP 8 + MySQL (Backend) · API Pública + Admin Panel ──────────►└─────────┬────────┘
                                                                                          │
                                                                                ┌─────────▼────────┐
                                                                                │ MySQL / MariaDB  │
                                                                                └──────────────────┘
```

* Frontend: Astro compila les pàgines estàtiques. En producció no hi ha càrrega de Node;
  només se serveixen fitxers plans des de `dist/`.
* Backend: una API REST pròpia en PHP 8 parla amb MySQL/MariaDB per gestionar la bústia
  de contacte, les visites, els articles del blog, les certificacions i els projectes.
* Integració: tots dos viuen al mateix allotjament i sota el mateix domini, així que no
  cal configurar regles de CORS creuades.

---

## Estructura del projecte

El repositori està organitzat de forma modular per aïllar responsabilitats:

```
├── .github/workflows/   # CI/CD: Anàlisi estàtica (CodeQL i Semgrep) i tests (Vitest)
├── database/            # Esquema MySQL idempotent i migració de base de dades
│   ├── schema.sql       # Taules, índexs, procediments de migració i llavor inicial
│   └── clean.sql        # Utilitat per buidar les taules
├── public/              # Recursos estàtics servits tal qual (PDFs, robots.txt, security.txt)
├── scripts/             # Eines auxiliars de compilació i generació d'icones
├── server/              # Backend en PHP
│   ├── admin/           # Consola d'administració (Autenticació, formularis d'edició)
│   ├── api/             # Endpoints públics de l'API de només lectura i telemetria
│   ├── lib/             # Nucli backend (bootstrap, pujada de fitxers, base de dades, utilitats HTTP)
│   └── config.example.php # Plantilla de configuració (BD, límits de pujada)
└── src/                 # Frontend en Astro (Pàgines, Layouts, Components, I18n)
```

---

## Hardening

Els controls implementats per tancar els vectors d'atac habituals:

### Frontend
* Content Security Policy: `script-src` es configura únicament amb hashos SHA-256
  calculats a cada compilació, sense `'unsafe-inline'`. Si un atacant injecta una
  etiqueta `<script>`, el navegador es nega a executar-la.
* Capçaleres d'aïllament: HSTS actiu (1 any, amb subdominis),
  `X-Frame-Options: DENY` contra clickjacking i directives COOP/CORP restrictives.
* Do Not Track: si el navegador envia la capçalera `DNT`, l'analítica local s'inhabilita
  per complet. Les IP de les estadístiques s'hashegen a l'instant amb SHA-256 i una sal
  d'un sol ús; mai s'emmagatzemen en text pla.

### Backend i injeccions
* Consultes preparades de debò: l'emulació de PDO està desactivada
  (`ATTR_EMULATE_PREPARES = false`) per evitar desbordaments i fallades de codificació
  de caràcters.
* CSRF amb tokens de sessió verificats en temps constant (`hash_equals`).
* El bàner superior admet Markdown i es renderitza al client. L'HTML s'escapa per
  complet *abans* del parseig, per evitar XSS persistent.
* Sanejament de pujades: les imatges passen per `finfo` (MIME real) i `getimagesize()`
  (estructura interna). La carpeta de pujades té els handlers PHP apagats via
  `.htaccess`, així que no executa scripts, i els fitxers desats reben noms aleatoris.

---

## Administració i base de dades

* Manteniment preventiu: [bootstrap.php](server/lib/bootstrap.php)
  comprova les taules i columnes necessàries en iniciar la consola d'administració. Si
  falta algun camp, per exemple després de desplegar una columna com `badges`,
  redirigeix a una pantalla d'avís amb instruccions en comptes de petar amb un error al
  client.
* Esquema idempotent: [schema.sql](database/schema.sql)
  es pot importar repetidament a phpMyAdmin sobre bases de dades existents sense
  esborrar la informació prèvia.

---

## SEO tècnic i rastreig per IA

* Graf únic JSON-LD: les dades estructurades (`Person`, `WebSite`, `FAQPage`,
  `BreadcrumbList`) s'unifiquen amb identificadors `@id` creuats en comptes de quedar en
  blocs dispersos.
* hreflang recíproc: la distribució multilingüe inclou referències creuades i
  `x-default` només a les pàgines amb traducció activa.
* Rastreig per IA: compleix l'especificació de [llmstxt.org](https://llmstxt.org/)
  generant un fitxer pla [`/llms.txt`](https://eduolihez.com/llms.txt) a cada build,
  perquè els models de llenguatge indexin el portfolio sense HTML residual.
* Control de bots: `robots.txt` permet indexar a més de 20 rastrejadors legítims d'IA i
  cercadors (GPTBot, ClaudeBot, PerplexityBot, Google-Extended, Amazonbot i altres), els
  bloqueja `/admin/` i `/api/` a tots, i bloqueja del tot els rastrejadors agressius de
  SEO de pagament (Semrush, Ahrefs, MJ12 i companyia).
* Blog citable sense JavaScript: els articles viuen a MySQL i es publiquen sense
  recompilar, així que un rastrejador que no executa JS els veuria buits.
  [`/llms-blog.txt`](https://eduolihez.com/llms-blog.txt) en serveix el text íntegre i
  `/sitemap-posts.xml` els enumera, tots dos generats a cada petició.

---

## Instal·lació i desplegament

### Requisits
* Node.js v20+
* PHP 8.0+ amb PDO habilitat
* Base de dades MySQL / MariaDB

### Instal·lació local (frontend)
```bash
# Instal·lar dependències
npm install

# Iniciar servidor de desenvolupament (Astro)
npm run dev
```

> [!NOTE]
> La base de dades i PHP no corren sota el servidor de desenvolupament d'Astro
> (`localhost:4321`), així que és normal veure errors a les seccions dinàmiques quan
> treballes en local. Per provar la integració completa, fes servir una pila local tipus
> XAMPP, Laragon o Docker.

### Comandes útils
* `npm run build`: compila el frontend estàtic a `dist/`.
* `npm run preview`: llança una vista prèvia local del directori compilat.
* `npm run icons`: regenera la pila de favicons i gràfics del web.
* `npm test`: executa la suite de tests (Vitest) sobre el frontend a `src/`.

### Desplegament al servidor (CDMON / cPanel)
1. Compila el lloc localment amb `npm run build`.
2. Puja per FTP el contingut de `dist/` a l'arrel del teu servidor, per exemple
   `public_html/`.
3. Puja la carpeta `server/` al mateix nivell, per mapejar `/api/` i `/admin/`.
4. Copia `server/config.example.php` a `server/config.php` i configura les teves
   variables de connexió. No pugis aquest fitxer al control de versions.
5. Entra a phpMyAdmin i importa [schema.sql](database/schema.sql).
6. Obre `tudomini.com/admin/setup.php` per crear el teu primer compte d'administració.
   **Un cop creat l'usuari, esborra `setup.php` del servidor.**

---

## Més documentació

Aquest repositori té més documentació de la que cap en aquest README. La major part està
en castellà, perquè és el web personal de l'autor i no una llibreria pensada per a
col·laboradors internacionals. `SECURITY.md` és l'excepció, en anglès:

* [Wiki](https://github.com/eduolihez/eduolihez.com/wiki), punt d'entrada a tota la
  documentació, incloent el pla de visibilitat IA/SEO.
* [TESTING.md](TESTING.md), framework de tests, cobertura i convencions.
* [CONTRIBUTING.md](CONTRIBUTING.md), com reportar un error o proposar un canvi.
* [SECURITY.md](SECURITY.md), política de divulgació de vulnerabilitats.
* [CHANGELOG.md](CHANGELOG.md), historial de versions.
* [PRODUCT.md](PRODUCT.md), per a qui és aquest web i quin problema resol.
* [DESIGN.md](DESIGN.md), sistema de disseny (tipografia, color, espaiat, motion).
* [TODOS.md](TODOS.md), treball pendent conegut, amb context de per què no s'ha fet
  encara.

---

## Llicència

Aquest projecte està sota la [Llicència MIT](LICENSE).

El contingut personal queda exclòs de la llicència MIT i amb tots els drets reservats:
imatges de marca, fotografies, PDF de certificacions i textos biogràfics de l'autor. Pots
fer servir la lògica i l'arquitectura del projecte per al teu propi desenvolupament; el
que no es permet és clonar directament la identitat visual i la informació de l'autor.
