/**
 * Datos de HABILIDADES (skills), agrupadas por categoria.
 * ---------------------------------------------------------------------------
 * Estatico: para anadir/editar una skill, edita este archivo y recompila.
 * Los nombres de las tecnologias no se traducen; solo el titulo de la categoria.
 */
import type { Localized } from '../i18n/utils';

export interface SkillGroup {
  category: Localized;
  items: string[];
}

export const skillGroups: SkillGroup[] = [
  {
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
      'Web Application Security',
      'Criptografia',
      'Análisis de Phishing',
    ],
  },
  {
    category: {
      es: 'Lenguajes & Desarrollo',
      en: 'Languages & Development',
      ca: 'Llenguatges & Desenvolupament',
    },
    items: ['Python', 'JavaScript', 'TypeScript', 'Rust', 'SQL', 'Bash'],
  },
  {
    category: {
      es: 'IA & Datos',
      en: 'AI & Data',
      ca: 'IA & Dades',
    },
    items: ['Machine Learning', 'Prompt Engineering', 'ONNX', 'Azure AI'],
  },
  {
    category: {
      es: 'Sistemas & Redes',
      en: 'Systems & Networking',
      ca: 'Sistemes & Xarxes',
    },
    items: ['Active Directory', 'Windows Server', 'Linux', 'Redes', 'Firewalls'],
  },
  {
    category: {
      es: 'Web & Herramientas',
      en: 'Web & Tooling',
      ca: 'Web & Eines',
    },
    items: ['Next.js', 'Tailwind CSS', 'SQLite', 'Git', 'Chrome Extensions'],
  },
];
