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
    icon: 'database',
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

export interface SkillChip {
  label: string;
  icon: string;
}

/**
 * Reparte todas las habilidades en dos filas para el doble carrusel de
 * <Skills />. Se intercalan los grupos (uno de cada, por turnos) para que en
 * una fila no se junten diez chips del mismo tema, y las filas quedan
 * equilibradas (difieren como mucho en uno).
 */
export function skillRows(): [SkillChip[], SkillChip[]] {
  const queues = skillGroups.map((g) => g.items.map((label) => ({ label, icon: g.icon })));
  const rows: [SkillChip[], SkillChip[]] = [[], []];
  let turn = 0;
  while (queues.some((q) => q.length > 0)) {
    for (const queue of queues) {
      const chip = queue.shift();
      if (!chip) continue;
      rows[turn % 2].push(chip);
      turn += 1;
    }
  }
  return rows;
}
