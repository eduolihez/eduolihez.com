/**
 * Catalogo de software publicado (repositorios y apps). Alimenta dos cosas:
 *   - el JSON-LD `SoftwareSourceCode` / `SoftwareApplication` de las portadas
 *     (src/lib/softwareSchema.ts), para que buscadores e IAs lo asocien a la
 *     persona como autora;
 *   - el indice de enlaces al principio de /llms.txt.
 *
 * Los textos son los mismos que ya publica llms.txt.ts. Si anades un
 * proyecto, anadelo tambien alli (la descripcion larga) y aqui (la corta).
 * Solo `es` y `en` son obligatorios; el catalan cae a espanol.
 */
import type { Localized } from '../i18n/utils';

export interface SoftwareEntry {
  id: string;
  name: string;
  kind: 'code' | 'app';
  /** Ruta dentro de eduolihez.com (p. ej. '/apps/nowait/'). */
  path?: string;
  /** URL fuera de eduolihez.com. */
  externalUrl?: string;
  /** Repositorio de GitHub (solo codigo abierto). */
  repo?: string;
  /** Solo para apps: categoria de schema.org. */
  category?: 'BrowserApplication' | 'SecurityApplication' | 'DesktopEnhancementApplication';
  inDevelopment?: boolean;
  description: Localized;
}

const GH = 'https://github.com/eduolihez';

export const softwareEntries: SoftwareEntry[] = [
  {
    id: 'blue-team-hub',
    name: 'Blue Team Hub',
    kind: 'code',
    externalUrl: 'https://eduolihez.github.io/',
    repo: `${GH}/eduolihez.github.io`,
    description: {
      es: 'Herramientas gratuitas y 100% client-side para analistas SOC: IOC Defanger, analizador de cabeceras de correo (SPF/DKIM/DMARC), reglas YARA y playbooks de respuesta a incidentes.',
      en: 'Free, 100% client-side tools for SOC analysts: IOC defanger, email header analyser (SPF/DKIM/DMARC), YARA rule generator and incident response playbooks.',
    },
  },
  {
    id: 'phishlab',
    name: 'PhishLab',
    kind: 'code',
    path: '/projects/phishlab/',
    repo: `${GH}/phishlab`,
    description: {
      es: 'Plantillas para simulaciones de phishing autorizadas por contrato, con exportacion para GoPhish y checklist de autorizacion.',
      en: 'Templates for contract-authorised phishing simulations, with GoPhish export and an authorisation checklist.',
    },
  },
  {
    id: 'phishing-triage',
    name: 'Phishing triage by classifier disagreement',
    kind: 'code',
    repo: `${GH}/phishing-triage`,
    description: {
      es: 'Investigacion sobre 7.822 correos reales: la incertidumbre del propio ensemble prioriza mejor que el desacuerdo entre clasificadores.',
      en: "Research on 7,822 real emails: the ensemble's own uncertainty prioritises better than classifier disagreement.",
    },
  },
  {
    id: 'kev-digest',
    name: 'KEV Digest',
    kind: 'code',
    repo: `${GH}/kev-digest`,
    description: {
      es: 'Vigilancia automatizada del catalogo CISA KEV cada tres horas sobre GitHub Actions, con las vulnerabilidades usadas en ransomware marcadas aparte.',
      en: 'Automated CISA KEV catalogue monitoring every three hours on GitHub Actions, with ransomware-linked vulnerabilities flagged separately.',
    },
  },
  {
    id: 'crem-report-generator',
    name: 'CREM Report Generator',
    kind: 'code',
    repo: `${GH}/vision-one-crem-report-generator`,
    description: {
      es: 'Generador no oficial de informes de riesgo y exposicion para Trend Micro Vision One, con enriquecimiento de CVEs (NVD, CISA KEV, EPSS).',
      en: 'Unofficial risk and exposure report generator for Trend Micro Vision One, with CVE enrichment (NVD, CISA KEV, EPSS).',
    },
  },
  {
    id: 'llm-chatbot-pentest',
    name: 'llm-chatbot-pentest',
    kind: 'code',
    repo: `${GH}/llm-chatbot-pentest`,
    description: {
      es: 'Red-teaming autonomo de chatbots LLM segun el OWASP Top 10 para aplicaciones LLM, con juez LLM e informe reproducible. Solo uso autorizado.',
      en: 'Autonomous red-teaming of LLM chatbots against the OWASP Top 10 for LLM applications, with an LLM judge and a reproducible report. Authorised use only.',
    },
  },
  {
    id: 'vigia',
    name: 'Vigia',
    kind: 'code',
    repo: `${GH}/vigia`,
    description: {
      es: 'Agente OSINT de superficie de ataque externa (EASM) con un LLM local; hallazgos con evidencia, priorizados con CISA KEV y FIRST EPSS.',
      en: 'External attack surface (EASM) OSINT agent with a local LLM; evidence-backed findings prioritised with CISA KEV and FIRST EPSS.',
    },
  },
  {
    id: 'northgate-browser',
    name: 'NorthGate Browser',
    kind: 'code',
    repo: `${GH}/northgate-browser`,
    inDevelopment: true,
    description: {
      es: 'Navegador centrado en la privacidad (fork de Mullvad Browser / Firefox) con clasificador de phishing en el dispositivo.',
      en: 'Privacy-focused browser (Mullvad Browser / Firefox fork) with an on-device phishing classifier.',
    },
  },
  {
    id: 'bincat',
    name: 'BinCat',
    kind: 'code',
    repo: `${GH}/BinCat`,
    description: {
      es: 'SDK en Python y panel Flask para emitir, validar y revocar tokens Fernet y JWT con registro de auditoria.',
      en: 'Python SDK and Flask dashboard to issue, validate and revoke Fernet and JWT tokens with an audit log.',
    },
  },
  {
    id: 'password-centinel',
    name: 'Password Centinel',
    kind: 'app',
    path: '/apps/password-centinel/',
    category: 'BrowserApplication',
    description: {
      es: 'Gestor de contrasenas 100% local (AES-256-GCM, TOTP/2FA, comprobacion de filtraciones con Have I Been Pwned).',
      en: '100% local password manager (AES-256-GCM, TOTP/2FA, breach checks via Have I Been Pwned).',
    },
  },
  {
    id: 'prompt-master',
    name: 'PromptMaster',
    kind: 'app',
    path: '/apps/prompt-master/',
    category: 'BrowserApplication',
    description: {
      es: 'Extension de navegador que mejora prompts para ChatGPT, Claude, Gemini y otras plataformas de IA.',
      en: 'Browser extension that improves prompts for ChatGPT, Claude, Gemini and other AI platforms.',
    },
  },
  {
    id: 'nowait',
    name: 'NoWait',
    kind: 'app',
    path: '/apps/nowait/',
    category: 'BrowserApplication',
    description: {
      es: 'Extension que evita acortadores de enlaces y paginas de espera (Linkvertise, ouo.io, adf.ly y 90+ sitios mas).',
      en: 'Extension that skips link shorteners and wait pages (Linkvertise, ouo.io, adf.ly and 90+ more sites).',
    },
  },
  {
    id: 'followguard',
    name: 'FollowGuard',
    kind: 'app',
    path: '/projects/followguard/',
    category: 'SecurityApplication',
    description: {
      es: 'Herramienta de ciberinteligencia que analiza interacciones en redes sociales para detectar perfiles falsos y automatizados.',
      en: 'Cyber-intelligence tool that analyses social media interactions to detect fake and automated profiles.',
    },
  },
  {
    id: 'fluence',
    name: 'Fluence',
    kind: 'app',
    path: '/projects/fluence/',
    category: 'DesktopEnhancementApplication',
    description: {
      es: 'Asistente de escritorio para el crecimiento organico en Instagram; procesado local, sin servidores propios.',
      en: 'Desktop assistant for organic Instagram growth; local processing, no servers of its own.',
    },
  },
];
