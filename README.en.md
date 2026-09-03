<div align="center">

# eduolihez.com

**Eduardo Olivares Hernández's professional wiki and portfolio**, SOC Analyst / Blue Team

[![Web](https://img.shields.io/badge/web-eduolihez.com-4ade80?style=flat-square)](https://eduolihez.com)
[![Astro](https://img.shields.io/badge/Astro-7-BC52EE?style=flat-square&logo=astro&logoColor=white)](https://astro.build)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com)
[![PHP](https://img.shields.io/badge/PHP-8-777BB4?style=flat-square&logo=php&logoColor=white)](https://www.php.net)
[![CodeQL](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml)
[![Tests](https://github.com/eduolihez/eduolihez.com/actions/workflows/test.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

---

### **[English version](README.en.md)** · [Versió en Català](README.ca.md) · [Versión en Español](README.md)

</div>

---

This is the source code for **eduolihez.com**, Eduardo Olivares' personal website and
portfolio, available in English, Spanish and Catalan.

The site is designed around defense in depth, and doubles as a practical demonstration
of offensive security, server hardening and secure web development. The technical
decisions behind the architecture are described at
[eduolihez.com/en/about-this-website](https://eduolihez.com/en/about-this-website/).

---

## Index
1. [Architecture and workflow](#architecture-and-workflow)
2. [Project structure](#project-structure)
3. [Hardening](#hardening)
4. [Admin console and database](#admin-console-and-database)
5. [Technical SEO and AI crawling](#technical-seo-and-ai-crawling)
6. [Installation and deployment](#installation-and-deployment)
7. [More documentation](#more-documentation)
8. [License](#license)

---

## Architecture and workflow

The project pairs a static site generator with a custom backend for dynamic content:

```
┌─ src/          Astro (Frontend) · Compiles to static HTML ─► dist/ ──► Apache Web Server ┐
│                                                                                          │
│                                                                               ┌──────────▼───────┐
│  fetch /api/*.php  ◄──────────────────────────────────────────────────────────┤  CDMON / Hosting │
│                                                                               │  Cloudflare / TLS│
└─ server/       PHP 8 + MySQL (Backend) · Public API + Admin Panel ───────────►└──────────┬───────┘
                                                                                           │
                                                                                ┌──────────▼───────┐
                                                                                │ MySQL / MariaDB  │
                                                                                └──────────────────┘
```

* Frontend: Astro compiles the static pages. In production there is no Node.js runtime
  overhead; only flat files are served from `dist/`.
* Backend: a custom, framework-free REST API in PHP 8 talks to MySQL/MariaDB to manage
  the contact inbox, visit telemetry, blog entries, the certifications list and the
  projects.
* Integration: both components are hosted under the same domain, which removes the need
  for cross-origin CORS rules.

---

## Project structure

The repository is modularly structured to enforce separation of concerns:

```
├── .github/workflows/   # CI/CD: Static analysis (CodeQL and Semgrep) and tests (Vitest)
├── database/            # Idempotent MySQL schema and migrations
│   ├── schema.sql       # Tables, indexes, migration procedures, and initial seed
│   └── clean.sql        # Table-emptying utility script
├── public/              # Static assets served directly (PDFs, robots.txt, security.txt)
├── scripts/             # Auxiliary compilation tools and icon generators
├── server/              # Backend codebase (PHP)
│   ├── admin/           # Admin panel (Authentication, edit forms)
│   ├── api/             # Read-only public API endpoints and telemetry
│   ├── lib/             # Backend core (bootstrap, upload managers, database client, HTTP helpers)
│   └── config.example.php # Configuration template (DB, upload limits)
└── src/                 # Frontend codebase (Astro templates, layouts, components, i18n)
```

---

## Hardening

The controls in place to close common attack vectors:

### Frontend
* Content Security Policy: `script-src` relies exclusively on SHA-256 hashes generated
  on every build, with no `'unsafe-inline'`. If an attacker injects a `<script>` tag,
  the browser refuses to run it.
* Isolation headers: HSTS active (1 year, with subdomains), `X-Frame-Options: DENY`
  against clickjacking, and restrictive COOP/CORP directives.
* Do Not Track: if the browser sends `DNT`, local telemetry is skipped entirely.
  Statistics IP addresses are salted and hashed with SHA-256 on arrival, and never
  stored in plain text.

### Backend and injection defenses
* Real prepared statements: PDO statement emulation is disabled
  (`ATTR_EMULATE_PREPARES = false`) to prevent charset-based SQL injection breakouts.
* CSRF protection using session tokens verified in constant time with `hash_equals`.
* The admin-configured announcement banner accepts Markdown. Strings are fully escaped
  *before* markdown compilation, which blocks stored XSS.
* Upload sanitization: uploaded files are validated with `finfo` (real MIME type) and
  `getimagesize()` (internal structure). The uploads directory has the PHP engine
  disabled via `.htaccess`, so it cannot execute scripts, and saved files get random
  alphanumeric names.

---

## Admin console and database

* Preventative maintenance: the schema validator in [bootstrap.php](server/lib/bootstrap.php)
  checks tables and columns when the admin dashboard starts. If a column is missing, for
  example after deploying a new database property like `badges`, it shows a warning page
  with guided migration steps instead of failing cryptically.
* Idempotent schema: [schema.sql](database/schema.sql)
  can be imported repeatedly on top of active tables without wiping existing records.

---

## Technical SEO and AI crawling

* Unified JSON-LD graph: the structured data entities (`Person`, `WebSite`, `FAQPage`,
  `BreadcrumbList`) are unified through interconnected `@id` properties instead of
  sitting in scattered blocks.
* Reciprocal hreflang: the multi-language distribution specifies localized alternatives
  and `x-default` strictly for pages with active translations.
* AI machine-readable profile: implements the [llmstxt.org](https://llmstxt.org/)
  specification, generating a plain-text
  [`/llms.txt`](https://eduolihez.com/llms.txt) summary on each build so AI assistants
  can index the portfolio cleanly.
* Crawler control: a custom `robots.txt` explicitly permits indexation by 20+ legitimate
  AI and search crawlers (GPTBot, ClaudeBot, PerplexityBot, Google-Extended, Amazonbot,
  among others), blocks `/admin/` and `/api/` for all of them, and blocks aggressive SEO
  scrapers outright (Semrush, Ahrefs, MJ12 and others).
* Blog citability without JavaScript: blog entries live in MySQL and publish without a
  rebuild, so a crawler that doesn't run JS would see them empty.
  [`/llms-blog.txt`](https://eduolihez.com/llms-blog.txt) serves their full text and
  `/sitemap-posts.xml` lists them, both generated on each request.

---

## Installation and deployment

### Prerequisites
* Node.js v20+
* PHP 8.0+ with PDO enabled
* MySQL / MariaDB database instance

### Local installation (frontend only)
```bash
# Install dependencies
npm install

# Run Astro dev server
npm run dev
```

> [!NOTE]
> The dynamic PHP backend does not run under Astro's dev server (`localhost:4321`), so
> dynamic sections will show load warnings when you work locally. To test the full
> integration, use a local stack like XAMPP, Laragon or Docker.

### Useful commands
* `npm run build`: compiles the static frontend to `dist/`.
* `npm run preview`: launches a local preview server for the compiled site.
* `npm run icons`: regenerates the site icon set.
* `npm test`: runs the test suite (Vitest) for the `src/` frontend.

### Production deployment (CDMON / cPanel)
1. Build the site locally with `npm run build`.
2. Upload the **contents** of `dist/` to your server's document root, for example
   `public_html/`.
3. Upload the `server/` directory to the same level, so `/api/` and `/admin/` map
   correctly.
4. Copy `server/config.example.php` to `server/config.php` and configure your
   credentials. Keep this file out of Git.
5. Import [schema.sql](database/schema.sql)
   into your database using phpMyAdmin.
6. Open `yourdomain.com/admin/setup.php` to register the primary admin account.
   **Delete `setup.php` from your server immediately after.**

---

## More documentation

This repository has more documentation than fits in this README. Most of it is written
in Spanish, since this is the author's personal site rather than a library aimed at
international contributors. `SECURITY.md` is the exception, in English:

* [Wiki](https://github.com/eduolihez/eduolihez.com/wiki), the entry point to all the
  documentation, including the AI/SEO visibility plan.
* [TESTING.md](TESTING.md), test framework, coverage and conventions.
* [CONTRIBUTING.md](CONTRIBUTING.md), how to report a bug or propose a change.
* [SECURITY.md](SECURITY.md), vulnerability disclosure policy.
* [CHANGELOG.md](CHANGELOG.md), version history.
* [PRODUCT.md](PRODUCT.md), who this site is for and what problem it solves.
* [DESIGN.md](DESIGN.md), design system (typography, color, spacing, motion).
* [TODOS.md](TODOS.md), known pending work, with context on why it wasn't done yet.

---

## License

This repository is licensed under the [MIT License](LICENSE).

All rights are reserved for personal bio texts, brand logos, photography assets and
certification PDF files. You are welcome to adapt the architectural patterns, code
layout and styling configurations for your own use; cloning the visual identity or
author details is not allowed.
