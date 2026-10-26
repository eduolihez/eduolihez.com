/**
 * Datos de HABILIDADES (skills), agrupadas por categoria.
 * ---------------------------------------------------------------------------
 * Estatico: para anadir/editar una skill, edita este archivo y recompila.
 * Los nombres de las tecnologias no se traducen; solo el titulo de la categoria.
 */
import type { Localized } from '../i18n/utils';

export interface SkillGroup {
  category: Localized;
  /** Nombre de icono de src/components/Icon.astro. */
  icon: string;
  items: string[];
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
      'Web Application Security',
      'Criptografía',
      'Análisis de Phishing',
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
  },
  {
    icon: 'robot',
    category: {
      es: 'IA & Datos',
      en: 'AI & Data',
      ca: 'IA & Dades',
    },
    items: ['Machine Learning', 'Prompt Engineering', 'ONNX', 'Azure AI'],
  },
  {
    icon: 'server',
    category: {
      es: 'Sistemas & Redes',
      en: 'Systems & Networking',
      ca: 'Sistemes & Xarxes',
    },
    items: ['Active Directory', 'Windows Server', 'Linux', 'Redes', 'Firewalls'],
  },
  {
    icon: 'globe',
    category: {
      es: 'Web & Herramientas',
      en: 'Web & Tooling',
      ca: 'Web & Eines',
    },
    items: ['Next.js', 'Tailwind CSS', 'SQLite', 'Git', 'Chrome Extensions'],
  },
];
