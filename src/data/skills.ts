/**
 * Datos de HABILIDADES (skills), agrupadas por categoria.
 * ---------------------------------------------------------------------------
 * Estatico: para anadir/editar una skill, edita este archivo y recompila.
 * Los nombres de las tecnologias no se traducen; solo el titulo de la categoria.
 */
import type { Localized } from '../i18n/utils';
import type { Lang } from '../i18n/ui';
import { evidencePaths } from '../lib/evidencePage';
import { evidenceAnchor } from '../scripts/evidence';

export interface SkillGroup {
  category: Localized;
  /** Nombre de icono de src/components/Icon.astro. */
  icon: string;
  items: string[];
  /** Respaldo real del grupo: evidencia E-nn, repo publicado o app/proyecto de esta web. */
  refs?: SkillRef[];
  /** Habilidades del grupo SIN respaldo en datos existentes (se muestran sin enlace). */
  unbacked?: string[];
}

export type SkillRef =
  | { kind: 'evidence'; id: string; label: string }
  | { kind: 'repo'; repo: string; label: string }
  | { kind: 'page'; path: string; enPath?: string; label: string };

/** Enlace final de un respaldo, segun el idioma (las paginas sin version CA caen a ES). */
export function skillRefHref(ref: SkillRef, lang: Lang): string {
  if (ref.kind === 'evidence') return `${evidencePaths[lang]}#${evidenceAnchor(ref.id)}`;
  if (ref.kind === 'repo') return `https://github.com/eduolihez/${ref.repo}`;
  return lang === 'en' && ref.enPath ? ref.enPath : ref.path;
}

export const skillGroups: SkillGroup[] = [
  // Primero el foco profesional (mismo orden que las "Top skills" de LinkedIn).
  {
    icon: 'cloud',
    category: {
      es: 'Cloud, Identidad & Correo',
      en: 'Cloud, Identity & Email',
      ca: 'Cloud, Identitat & Correu',
    },
    items: [
      'Cloud Security',
      'Identity & Access Management (IAM)',
      'Email & Collaboration Security',
      'Security Awareness (SAT)',
      'Phishing Simulation',
    ],
    refs: [
      { kind: 'evidence', id: 'E-03', label: 'E-03 Trend Vision One Advanced' },
      { kind: 'page', path: '/projects/phishlab/', label: 'PhishLab' },
    ],
  },
  {
    icon: 'robot',
    category: {
      es: 'Seguridad de la IA & Red Teaming',
      en: 'AI Security & Red Teaming',
      ca: 'Seguretat de la IA & Red Teaming',
    },
    items: [
      'AI Security',
      'LLM Red Teaming',
      'Prompt Injection',
      'OWASP Top 10 for LLM Apps',
      'MITRE ATLAS',
      'NIST AI RMF',
      'OWASP',
      'Penetration Testing',
      'Red Teaming',
      'Web Application Security',
    ],
    refs: [{ kind: 'repo', repo: 'llm-chatbot-pentest', label: 'llm-chatbot-pentest' }],
    unbacked: ['Penetration Testing', 'Red Teaming'],
  },
  {
    icon: 'shield',
    category: {
      es: 'Seguridad & Blue Team',
      en: 'Security & Blue Team',
      ca: 'Seguretat & Blue Team',
    },
    items: [
      'Threat Detection',
      'Incident Response',
      'XDR / SIEM',
      'Threat Intelligence',
      'Trend Micro Vision One',
      'Fortinet (FortiGate/FortiAnalyzer)',
      'Vulnerability Management',
      'Criptografía',
      'Análisis de Phishing',
    ],
    refs: [
      { kind: 'evidence', id: 'E-03', label: 'E-03 Trend Vision One Advanced' },
      { kind: 'repo', repo: 'vigia', label: 'Vigia' },
    ],
  },
  {
    icon: 'code',
    category: {
      es: 'Lenguajes & Desarrollo',
      en: 'Languages & Development',
      ca: 'Llenguatges & Desenvolupament',
    },
    items: ['Python', 'JavaScript', 'TypeScript', 'Rust', 'SQL', 'Bash'],
    refs: [{ kind: 'page', path: '/projects/followguard/', label: 'FollowGuard' }],
  },
  {
    icon: 'database',
    category: {
      es: 'IA & Datos',
      en: 'AI & Data',
      ca: 'IA & Dades',
    },
    items: ['Machine Learning', 'Prompt Engineering', 'ONNX', 'Azure AI'],
    refs: [{ kind: 'evidence', id: 'E-01', label: 'E-01 Azure AI Fundamentals' }],
  },
  {
    icon: 'server',
    category: {
      es: 'Sistemas & Redes',
      en: 'Systems & Networking',
      ca: 'Sistemes & Xarxes',
    },
    items: ['Active Directory', 'Windows Server', 'Linux', 'Redes', 'Firewalls'],
    refs: [{ kind: 'evidence', id: 'E-02', label: 'E-02 Fortinet NSE' }],
  },
  {
    icon: 'globe',
    category: {
      es: 'Web & Herramientas',
      en: 'Web & Tooling',
      ca: 'Web & Eines',
    },
    items: ['Next.js', 'Tailwind CSS', 'SQLite', 'Git', 'Chrome Extensions'],
    refs: [{ kind: 'page', path: '/apps/nowait/', enPath: '/en/apps/nowait/', label: 'NoWait' }],
    unbacked: ['Next.js'],
  },
];

