<div align="center">

# eduolihez.com

**Wiki i Portfolio Professional de Eduardo Olivares Hernández** — Analista SOC / Blue Team

[![Web](https://img.shields.io/badge/web-eduolihez.com-4ade80?style=flat-square)](https://eduolihez.com)
[![Astro](https://img.shields.io/badge/Astro-7-BC52EE?style=flat-square&logo=astro&logoColor=white)](https://astro.build)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com)
[![PHP](https://img.shields.io/badge/PHP-8-777BB4?style=flat-square&logo=php&logoColor=white)](https://www.php.net)
[![CodeQL](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml)
[![Tests](https://github.com/eduolihez/eduolihez.com/actions/workflows/test.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

---

### [🌐 English version](README.en.md) · **[🌐 Versió en Català](README.ca.md)** · [🌐 Versión en Español](README.md)

</div>

---

Benvingut al repositori i wiki tècnica de **eduolihez.com**. Aquest és el codi font del lloc web personal i portfolio professional de Eduardo Olivares, disponible completament en **català, espanyol i anglès**.

El lloc s'ha dissenyat seguint el principi de **defensa en profunditat** i serveix com a demostració de competències tècniques en seguretat ofensiva, enduriment de servidors (hardening) i desenvolupament web segur. Tots els detalls tècnics sobre el seu disseny es descriuen a [eduolihez.com/ca/sobre-aquesta-web](https://eduolihez.com/ca/sobre-aquesta-web/).

---

## 📖 Índex
1. [Arquitectura i Flux de Treball](#-arquitectura-i-flux-de-treball)
2. [Estructura del Projecte](#-estructura-del-projecte)
3. [Seguretat Avançada (Hardening)](#-seguretat-avançada-hardening)
4. [Administració i Base de Dades](#-administració-i-base-de-dades)
5. [SEO Tècnic i IA-Friendliness](#-seo-tècnic-i-ia-friendliness)
6. [Instal·lació i Desplegament](#-instal·lació-i-desplegament)
7. [Més Documentació](#-més-documentació)
8. [Llicència](#-llicència)

---

## 🏗️ Arquitectura i Flux de Treball

El projecte combina un generador de llocs estàtics (SSG) modern amb una infraestructura backend robusta per a la gestió del contingut dinàmic:

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

* **Frontend**: Astro compila les pàgines estàtiques. En producció, la càrrega de Node és inexistent; només se serveixen fitxers plans des de la carpeta `dist/`.
* **Backend**: Una API REST pròpia i independent en PHP 8 interactua amb la base de dades MySQL/MariaDB per gestionar la bústia de contacte, visites, articles de blog, certificacions i projectes.
* **Integració**: Ambdós resideixen en el mateix allotjament sota el mateix domini. Això elimina la necessitat de configurar regles de CORS creuades.

---

## 📂 Estructura del Projecte

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

## 🛡️ Seguretat Avançada (Hardening)

Com a portfolio d'un professional de ciberseguretat, s'han implementat rigurosos controls per tancar vectors d'atac comuns:

### Frontend
* **Content Security Policy (CSP)**: `script-src` configurat únicament amb hashos SHA-256 calculats automàticament a cada compilació (evita `'unsafe-inline'`). Si un atacant injecta una etiqueta `<script>`, el navegador es negarà a executar-la.
* **Capçaleres d'Aïllament**: HSTS actiu (1 any amb subdominis), `X-Frame-Options: DENY` contra clickjacking, i directives COOP/CORP restrictives.
* **Privadesa per Disseny (Do Not Track)**: Respecte estricte a les peticions `DNT` (si el navegador l'envia, l'analítica local s'inhabilita per complet). Les adreces IP de les estadístiques s'hashegen immediatament amb `SHA-256` i una sal d'un sol ús; mai s'emmagatzemen en text pla.

### Backend i Injeccions
* **Consultes Preparades Reals**: Deshabilitada l'emulació de PDO (`ATTR_EMULATE_PREPARES = false`) per evitar desbordaments o fallades de codificació de caràcters.
* **Seguretat en Formularis**: CSRF implementat amb tokens de sessió verificats en temps constant (`hash_equals`).
* **Protecció del Bàner superior amb Markdown**: El camp del bàner d'administració admet Markdown i es renderitza al client de forma segura. L'HTML s'escapa per complet *abans* del parseig per evitar injeccions XSS persistents (Stored XSS).
* **Sanejament de Pujades**: Les imatges s'analitzen amb `finfo` (MIME real) i `getimagesize()` (estructura interna). La carpeta de pujades inhabilita l'execució de scripts (handlers PHP apagats via `.htaccess`) i assigna noms aleatoris als fitxers desats.

---

## 🗄️ Administració i Base de Dades

* **Manteniment Preventiu**: El sistema inclou un validador a [bootstrap.php](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/server/lib/bootstrap.php) que comprova les taules i columnes necessàries en iniciar la consola d'administració. Si detecta la manca de camps (ex. després del desplegament d'una columna com `badges`), redirigeu a una pantalla d'avís amb instruccions guiades en comptes de llançar un error crític al client.
* **Esquema Idempotent**: El fitxer [schema.sql](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/database/schema.sql) es pot importar repetidament a phpMyAdmin sobre bases de dades existents sense esborrar la informació prèvia de l'usuari.

---

## 🔍 SEO Tècnic i IA-Friendliness

* **Graf Únic JSON-LD**: Dades estructurades (`Person`, `WebSite`, `FAQPage`, `BreadcrumbList`) unificades mitjançant identificadors `@id` creuats en comptes de blocs dispersos.
* **hreflang Recíproc**: La distribució multilingüe inclou referències creuades i `x-default` únicament en pàgines amb traducció activa.
* **IA Rastreabilitat**: Compleix amb l'especificació de [llmstxt.org](https://llmstxt.org/) generant un fitxer pla [`/llms.txt`](https://eduolihez.com/llms.txt) a cada build, ideal perquè els models de llenguatge (LLM) indexin el portfolio sense HTML residual.
* **Control de Bots**: Filtre selectiu a `robots.txt` que permet indexar a més de 20 rastrejadors legítims d'IA i cercadors (GPTBot, ClaudeBot, PerplexityBot, Google-Extended, Amazonbot, entre altres), bloqueja `/admin/` i `/api/` a tots ells, i bloqueja del tot els rastrejadors agressius de SEO de pagament (Semrush, Ahrefs, MJ12 i altres).
* **Blog citable sense JavaScript**: Els articles viuen a MySQL i es publiquen sense recompilar, així que un rastrejador que no executa JS els veuria buits. [`/llms-blog.txt`](https://eduolihez.com/llms-blog.txt) en serveix el text íntegre i `/sitemap-posts.xml` els enumera, tots dos generats a cada petició.

---

## 🚀 Instal·lació i Desplegament

### Requisits
* Node.js v20+
* PHP 8.0+ amb PDO habilitat
* Base de dades MySQL / MariaDB

### Instal·lació Local (Entorn Frontend)
```bash
# Instal·lar dependències
npm install

# Iniciar servidor de desenvolupament (Astro)
npm run dev
```

> [!NOTE]
> Com que la base de dades dinàmica i PHP no corren directament sota el servidor de desenvolupament d'Astro (`localhost:4321`), és normal veure missatges d'error a les seccions dinàmiques locals. Per provar la integració completa, utilitza una pila local tipus XAMPP, Laragon o Docker.

### Comandes Útils
* `npm run build`: Compila el frontend estàtic a la carpeta `dist/`.
* `npm run preview`: Llança una vista prèvia local del directori compilat.
* `npm run icons`: Regenera la pila de favicons i gràfics del web.
* `npm test`: Executa la suite de tests (Vitest) sobre el frontend a `src/`.

### Instruccions de Desplegament en Servidor (CDMON / CPanel)
1. Compila el lloc localment amb `npm run build`.
2. Puja per FTP el contingut de `dist/` a la arrel del teu servidor (ex. `public_html/`).
3. Puja la carpeta `server/` al mateix nivell del teu servidor per mapejar `/api/` i `/admin/`.
4. Còpia `server/config.example.php` a `server/config.php` i configura les teves variables de connexió. **Important**: No pugis aquest fitxer al control de versions.
5. Accedeix a phpMyAdmin i importa [schema.sql](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/database/schema.sql).
6. Entra a `tudomini.com/admin/setup.php` per crear el teu primer compte d'administració. **Un cop creat l'usuari, esborra el fitxer `setup.php` del servidor.**

---

## 📚 Més Documentació

Aquest repositori té més documentació de la que cap en aquest README. La major
part està en castellà (és el web personal de l'autor, no una llibreria pensada
per a col·laboradors internacionals) — `SECURITY.md` és l'excepció, en anglès:

* [Wiki](https://github.com/eduolihez/eduolihez.com/wiki) — punt d'entrada
  a tota la documentació, incloent el pla de visibilitat IA/SEO.
* [TESTING.md](TESTING.md) — framework de tests, cobertura i convencions.
* [CONTRIBUTING.md](CONTRIBUTING.md) — com reportar un error o proposar un canvi.
* [SECURITY.md](SECURITY.md) — política de divulgació de vulnerabilitats.
* [CHANGELOG.md](CHANGELOG.md) — historial de versions.
* [PRODUCT.md](PRODUCT.md) — per a qui és aquest web i quin problema resol.
* [DESIGN.md](DESIGN.md) — sistema de disseny (tipografia, color, espaiat, motion).
* [TODOS.md](TODOS.md) — treball pendent conegut, amb context de per què no s'ha fet encara.

---

## 📄 Llicència

Aquest projecte està sota la [Llicència MIT](LICENSE). 

* Queden exclosos de la llicència MIT i reservats tots els drets sobre el contingut personal (imatges de marca, fotografies, fitxers PDF de certificacions i textos biogràfics de l'autor). Pots emprar la lògica i arquitectura del projecte per al teu propi desenvolupament; es prohibeix el clonatge directe de la identitat visual i informació de l'autor.
