<div align="center">

# eduolihez.com

**Eduardo Olivares Hernández's Professional Wiki & Portfolio** — SOC Analyst / Blue Team

[![Web](https://img.shields.io/badge/web-eduolihez.com-4ade80?style=flat-square)](https://eduolihez.com)
[![Astro](https://img.shields.io/badge/Astro-7-BC52EE?style=flat-square&logo=astro&logoColor=white)](https://astro.build)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com)
[![PHP](https://img.shields.io/badge/PHP-8-777BB4?style=flat-square&logo=php&logoColor=white)](https://www.php.net)
[![CodeQL](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

---

### **[🌐 English version](README.en.md)** · [🌐 Versió en Català](README.ca.md) · [🌐 Versión en Español](README.md)

</div>

---

Welcome to the technical wiki and repository of **eduolihez.com**. This is the source code for Eduardo Olivares' personal website and professional portfolio, available in **English, Spanish, and Catalan**.

The site has been designed following the principle of **defense in depth** and serves as a practical demonstration of technical skills in offensive security, server hardening, and secure web development. All technical decisions regarding its architecture are described at [eduolihez.com/en/about-this-website](https://eduolihez.com/en/about-this-website/).

---

## 📖 Wiki Index
1. [Architecture & Workflow](#-architecture--workflow)
2. [Project Structure](#-project-structure)
3. [Advanced Hardening (Security)](#-advanced-hardening-security)
4. [Admin Console & Database](#-admin-console--database)
5. [Technical SEO & AI-Friendliness](#-technical-seo--ai-friendliness)
6. [Installation & Deployment](#-installation--deployment)
7. [License](#-license)

---

## 🏗️ Architecture & Workflow

The project combines a modern Static Site Generator (SSG) with a robust backend infrastructure for dynamic content management:

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

* **Frontend**: Astro compiles the static pages. In production, there is no Node.js runtime overhead; only flat files are served from the `dist/` directory.
* **Backend**: A custom, framework-free REST API in PHP 8 interacts with the MySQL/MariaDB database to manage the contact inbox, visits telemetry, blog entries, certifications list, and projects.
* **Integration**: Both components are hosted under the same domain. This eliminates the need for cross-origin CORS rules.

---

## 📂 Project Structure

The repository is modularly structured to enforce separation of concerns:

```
├── .github/workflows/   # CI/CD: Static analysis (CodeQL and Semgrep)
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

## 🛡️ Advanced Hardening (Security)

As the portfolio of a cybersecurity professional, strict controls have been implemented to close common attack vectors:

### Frontend
* **Content Security Policy (CSP)**: `script-src` relies exclusively on SHA-256 hashes generated automatically on every build (no `'unsafe-inline'`). If an attacker injects a `<script>` tag, the browser will refuse to run it.
* **Isolation Headers**: HSTS active (1 year with subdomains), `X-Frame-Options: DENY` against clickjacking, and restrictive COOP/CORP directives.
* **Privacy by Design (Do Not Track)**: Strict compliance with `DNT` headers (if the browser requests no tracking, local telemetry is skipped entirely). Statistics IP addresses are instantly salted and hashed with `SHA-256`; they are never stored in plain text.

### Backend & Injection Defenses
* **Real Prepared Statements**: Emulation of PDO statements is disabled (`ATTR_EMULATE_PREPARES = false`) to prevent charset-based SQL injection breakouts.
* **Form Security**: CSRF protection implemented with session tokens verified in constant-time using `hash_equals`.
* **Stored XSS Prevention in Banner**: The admin-configured announcement banner accepts Markdown. Strings are fully escaped *before* markdown compilation to block script execution.
* **Secure Uploads**: Uploaded files are validated via `finfo` (real MIME type) and `getimagesize()` (internal structure). The uploads directory has script execution disabled (PHP engine disabled via `.htaccess`) and saves files with random alphanumeric names.

---

## 🗄️ Admin Console & Database

* **Preventative Maintenance**: The system includes a schema validator in [bootstrap.php](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/server/lib/bootstrap.php) that checks tables and columns on admin dashboard initialization. If any column is missing (e.g. after deploying new database properties like `badges`), it displays a warning page with guided migration steps instead of failing cryptically.
* **Idempotent Schema**: The [schema.sql](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/database/schema.sql) file can be imported repeatedly on top of active tables without wiping existing user records.

---

## 🔍 Technical SEO & AI-Friendliness

* **Unified JSON-LD Graph**: Structured data entities (`Person`, `WebSite`, `FAQPage`, `BreadcrumbList`) are unified using interconnected `@id` properties rather than scattered blocks.
* **Reciprocal hreflang**: Multi-language distribution specifies localized alternatives and `x-default` strictly for pages with active translations.
* **AI Machine-Readable Profile**: Implements the [llmstxt.org](https://llmstxt.org/) specification by generating a plain-text [`/llms.txt`](https://eduolihez.com/llms.txt) summary file on each build, enabling AI assistants to index the portfolio cleanly.
* **Crawler Control**: A custom `robots.txt` configuration explicitly permits indexation by legitimate AI agents (GPTBot, ClaudeBot) while blocking aggressive, non-beneficial SEO scrapers.

---

## 🚀 Installation & Deployment

### Prerequisites
* Node.js v20+
* PHP 8.0+ with PDO enabled
* MySQL / MariaDB database instance

### Local Installation (Frontend Only)
```bash
# Install dependencies
npm install

# Run Astro dev server
npm run dev
```

> [!NOTE]
> Since the dynamic PHP backend is not running under Astro's dev server (`localhost:4321`), it is expected for dynamic sections to display load warning labels locally. To test the full integration, use a local server stack like XAMPP, Laragon, or Docker.

### Useful Commands
* `npm run build`: Compiles the static frontend to `dist/`.
* `npm run preview`: Launches a local preview server for the compiled site.
* `npm run icons`: Regenerates the site icon set.

### Production Deployment Instructions (CDMON / CPanel)
1. Build the site locally using `npm run build`.
2. Upload the **contents** of `dist/` to your server's document root (e.g., `public_html/`).
3. Upload the `server/` directory to the same level so that `/api/` and `/admin/` are mapped correctly.
4. Copy `server/config.example.php` to `server/config.php` and configure your credentials. **Important**: Keep this file out of Git.
5. Import [schema.sql](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/database/schema.sql) into your database using phpMyAdmin.
6. Access `yourdomain.com/admin/setup.php` to register the primary admin account. **Delete `setup.php` from your server immediately after.**

---

## 📄 License

This repository is licensed under the [MIT License](LICENSE).

* All rights are reserved for personal bio texts, brand logos, photography assets, and certification PDF files. You are welcome to adapt the architectural patterns, code layout, and styling configurations for your own usage; cloning the visual identity or author details is prohibited.
