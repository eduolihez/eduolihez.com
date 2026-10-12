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
  /** Fecha de inicio en ISO 8601 (YYYY-MM-DD), para OrganizationRole.startDate
   * en el schema JSON-LD (ver Seo.astro). `period` es el texto que se
   * muestra; esto es lo que exige Schema.org y valida Rich Results Test. */
  startDateISO: string;
  /** Igual que startDateISO pero de fin. Se omite (no `current: true`) para
   * el puesto en curso: Schema.org no lleva endDate cuando no ha terminado. */
  endDateISO?: string;
  current?: boolean;
  description: Localized;
  tech: string[];
  /** Enlace opcional a un proyecto/repo que respalda esta entrada (ej. el
   * generador de informes mencionado en la descripcion). */
  link?: { url: string; label: Localized };
}

export const experiences: Experience[] = [
  {
    company: 'Dagram',
    // Mismo titulo que en LinkedIn, traducido en cada idioma.
    role: {
      es: 'Analista de Ciberseguridad',
      en: 'Cybersecurity Analyst',
      ca: 'Analista de Ciberseguretat',
    },
    period: { es: 'Abr 2026 - Presente', en: 'Apr 2026 - Present', ca: 'Abr 2026 - Actualitat' },
    startDateISO: '2026-04-01',
    current: true,
    // La cifra (semanas -> menos de 1 hora) la ha dado Eduardo: es el dato
    // que mas pesa para un reclutador. No la cambies sin preguntarle.
    description: {
      es: 'Triaje diario de alertas de Trend Micro Vision One (TrendAI), con IA para acelerar la investigación. Automaticé con Python los informes de amenazas, vulnerabilidades y el informe mensual: lo que antes llevaba semanas de trabajo manual se genera ahora en menos de 1 hora. Diseño y ejecuto las campañas de phishing simulado y el programa de concienciación (SAT), doy soporte en gestión de identidades y accesos (altas, bajas y revisiones de permisos) y mantengo los SOPs y la documentación de cumplimiento para auditorías.',
      en: 'Daily triage of Trend Micro Vision One (TrendAI) alerts, using AI to speed up investigations. I automated the threat, vulnerability and monthly reports in Python: work that used to take weeks by hand now runs in under 1 hour. I design and run the phishing simulation campaigns and the security awareness training (SAT) program, support identity and access management (onboarding, offboarding and access reviews), and keep SOPs and compliance documentation ready for audits.',
      ca: "Triatge diari d'alertes de Trend Micro Vision One (TrendAI), amb IA per accelerar la investigació. Vaig automatitzar amb Python els informes d'amenaces, de vulnerabilitats i l'informe mensual: el que abans portava setmanes de feina manual ara es genera en menys d'1 hora. Dissenyo i executo les campanyes de phishing simulat i el programa de conscienciació (SAT), dono suport en gestió d'identitats i accessos (altes, baixes i revisions de permisos) i mantinc els SOPs i la documentació de compliment per a auditories.",
    },
    tech: [
      'Trend Micro Vision One',
      'XDR/SIEM',
      'Python',
      'IAM',
      'Email Security',
      'Phishing Simulation / SAT',
      'Threat Intelligence',
    ],
    link: {
      url: 'https://github.com/eduolihez/vision-one-crem-report-generator',
      label: {
        es: 'Ver el generador de informes en GitHub',
        en: 'View the report generator on GitHub',
        ca: 'Veure el generador d’informes a GitHub',
      },
    },
  },
  {
    company: 'Dagram',
    role: {
      es: 'Técnico de Ciberseguridad (N1/N2)',
      en: 'Cybersecurity Technician (L1/L2)',
      ca: 'Tècnic de Ciberseguretat (N1/N2)',
    },
    period: { es: 'Ene 2026 - Abr 2026', en: 'Jan 2026 - Apr 2026', ca: 'Gen 2026 - Abr 2026' },
    startDateISO: '2026-01-01',
    endDateISO: '2026-04-01',
    description: {
      es: 'Configuración y gestión de firewalls FortiGate y FortiAnalyzer en distintos entornos de cliente, respuesta a incidentes de nivel 1 y 2 y scripts en Python para informes de seguridad y análisis de logs. Este trabajo me llevó al puesto de Analista de Ciberseguridad cuatro meses después.',
      en: 'Configured and managed FortiGate firewalls and FortiAnalyzer across client environments, handled L1/L2 incident response and wrote Python scripts for security reporting and log analysis. This work led to my promotion to Cybersecurity Analyst four months later.',
      ca: "Configuració i gestió de tallafocs FortiGate i FortiAnalyzer en diferents entorns de client, resposta a incidents de nivell 1 i 2 i scripts en Python per a informes de seguretat i anàlisi de logs. Aquesta feina em va portar al lloc d'Analista de Ciberseguretat quatre mesos després.",
    },
    tech: ['FortiGate', 'FortiAnalyzer', 'Python', 'Incident Response', 'Log Analysis'],
  },
  {
    company: 'Institució Cultural Laietània',
    role: { es: 'Técnico IT', en: 'IT Technician', ca: 'Tècnic IT' },
    period: { es: 'Oct 2024 - Abr 2025', en: 'Oct 2024 - Apr 2025', ca: 'Oct 2024 - Abr 2025' },
    startDateISO: '2024-10-01',
    endDateISO: '2025-04-01',
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
    startDateISO: '2024-05-01',
    endDateISO: '2024-09-01',
    description: {
      es: 'Liderazgo de grupos, comunicación y gestión de personas: habilidades transferibles clave para el trabajo en equipo y la comunicación de un SOC.',
      en: 'Group leadership, communication and people management: key transferable skills for teamwork and communication within a SOC.',
      ca: "Lideratge de grups, comunicació i gestió de persones: habilitats transferibles clau per al treball en equip i la comunicació d'un SOC.",
    },
    tech: ['Liderazgo', 'Comunicación', 'Gestión de personas'],
  },
];
