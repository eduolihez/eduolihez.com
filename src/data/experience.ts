/**
 * Datos de EXPERIENCIA (timeline).
 * ---------------------------------------------------------------------------
 * Esta seccion es estatica (se compila con el sitio). Para anadir/editar un
 * puesto, edita este array y recompila (npm run build). El orden del array
 * es el orden de aparicion (mas reciente arriba).
 *
 * Nota: los PROYECTOS y CERTIFICACIONES SI son dinamicos (base de datos +
 * panel admin), no se editan aqui.
 */
import type { Localized } from '../i18n/utils';

export interface Experience {
  company: string;
  role: Localized;
  period: Localized;
  current?: boolean;
  description: Localized;
  tech: string[];
}

export const experiences: Experience[] = [
  {
    company: 'Dagram',
    role: {
      es: 'SOC / Cybersecurity Analyst',
      en: 'SOC / Cybersecurity Analyst',
      ca: 'SOC / Cybersecurity Analyst',
    },
    period: { es: 'Abr 2026 - Presente', en: 'Apr 2026 - Present', ca: 'Abr 2026 - Actualitat' },
    current: true,
    description: {
      es: 'Triage de alertas con Trend Micro Vision One (TrendAI), investigación de amenazas asistida por IA, automatización de informes en Python y diseño de campañas de phishing y concienciación.',
      en: 'Alert triage with Trend Micro Vision One (TrendAI), AI-assisted threat investigation, Python report automation, and design of phishing and awareness campaigns.',
      ca: "Triatge d'alertes amb Trend Micro Vision One (TrendAI), investigació d'amenaces assistida per IA, automatització d'informes en Python i disseny de campanyes de phishing i conscienciació.",
    },
    tech: [
      'Trend Micro Vision One',
      'XDR/SIEM',
      'Python',
      'Threat Intelligence',
      'IA / TrendAI',
      'Phishing',
    ],
  },
  {
    company: 'Dagram',
    role: {
      es: 'Cybersecurity Technician L1/L2',
      en: 'Cybersecurity Technician L1/L2',
      ca: 'Cybersecurity Technician L1/L2',
    },
    period: { es: 'Ene 2026 - Abr 2026', en: 'Jan 2026 - Apr 2026', ca: 'Gen 2026 - Abr 2026' },
    description: {
      es: 'Administración y monitorización de FortiGate y FortiAnalyzer, respuesta a incidentes de nivel 1 y 2, y desarrollo de scripts de seguridad en Python.',
      en: 'Administration and monitoring of FortiGate and FortiAnalyzer, L1/L2 incident response, and development of Python security scripts.',
      ca: 'Administració i monitorització de FortiGate i FortiAnalyzer, resposta a incidents de nivell 1 i 2, i desenvolupament de scripts de seguretat en Python.',
    },
    tech: ['FortiGate', 'FortiAnalyzer', 'Python', 'Incident Response', 'Firewall'],
  },
  {
    company: 'Institucio Cultural Laietania',
    role: { es: 'Tecnico IT', en: 'IT Technician', ca: 'Tècnic IT' },
    period: { es: 'Oct 2024 - Abr 2025', en: 'Oct 2024 - Apr 2025', ca: 'Oct 2024 - Abr 2025' },
    description: {
      es: 'Soporte técnico a más de 100 usuarios, administración de Active Directory y automatización de tareas con scripts en Python.',
      en: 'Technical support for 100+ users, Active Directory administration, and task automation with Python scripts.',
      ca: "Suport tècnic a més de 100 usuaris, administració d'Active Directory i automatització de tasques amb scripts en Python.",
    },
    tech: ['Active Directory', 'Python', 'Windows Server', 'Help Desk'],
  },
  {
    company: 'Escola del Vent',
    role: { es: 'Instructor de Fitness', en: 'Fitness Instructor', ca: 'Instructor de Fitness' },
    period: { es: 'May 2024 - Sep 2024', en: 'May 2024 - Sep 2024', ca: 'Maig 2024 - Set 2024' },
    description: {
      es: 'Liderazgo de grupos, comunicación y gestión de personas: habilidades transferibles clave para el trabajo en equipo y la comunicación de un SOC.',
      en: 'Group leadership, communication and people management: key transferable skills for teamwork and communication within a SOC.',
      ca: "Lideratge de grups, comunicació i gestió de persones: habilitats transferibles clau per al treball en equipo i la comunicació d'un SOC.",
    },
    tech: ['Liderazgo', 'Comunicacion', 'Gestion de personas'],
  },
];
