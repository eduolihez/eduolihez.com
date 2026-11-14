/**
 * Contenido de la pagina "Analista SOC en Barcelona" (ES / EN / CA).
 *
 * Es una pagina de perfil, no de servicios: Edu trabaja en Dagram. Responde a
 * la busqueda "analista SOC Barcelona / Badalona" con una respuesta directa al
 * principio (lo que citan los asistentes de IA) y datos que ya estan en el
 * resto del sitio. No se inventan cifras: solo lo que consta en config.ts.
 */
import type { Lang } from '../i18n/ui';

export interface SocProfile {
  path: string;
  title: string;
  description: string;
  breadcrumb: string;
  kicker: string;
  h1: string;
  /** Respuesta directa, 2-3 frases. */
  answer: string;
  sections: { h: string; items: string[] }[];
  faqTitle: string;
  faq: { q: string; a: string }[];
  ctaContact: string;
  ctaHome: string;
  back: string;
}

export const socAlternates: Record<Lang, string> = {
  es: '/analista-soc-barcelona/',
  en: '/en/soc-analyst-barcelona/',
  ca: '/ca/analista-soc-barcelona/',
};

export const socProfile: Record<Lang, SocProfile> = {
  es: {
    path: socAlternates.es,
    title: 'Analista SOC en Barcelona y Badalona | Eduardo Olivares',
    description:
      'Analista SOC en Barcelona y Badalona: triaje de alertas en Trend Micro Vision One, detección de amenazas, respuesta a incidentes y automatización con Python.',
    breadcrumb: 'Analista SOC en Barcelona',
    kicker: 'Perfil / SOC',
    h1: 'Analista SOC en Barcelona y Badalona',
    answer:
      'Soy Eduardo Olivares, analista de ciberseguridad en un SOC de Barcelona (Dagram) y vivo en Badalona. Hago triaje de alertas en Trend Micro Vision One, investigo incidentes de correo, identidad y endpoint, y automatizo los informes de seguridad con Python. Estoy certificado por Trend Micro, Fortinet y Microsoft.',
    sections: [
      {
        h: 'Qué hago en el SOC',
        items: [
          'Triaje y priorización de alertas en Trend Micro Vision One (XDR).',
          'Investigación de incidentes de correo, identidad y endpoint: qué pasó, a quién afecta y qué se contiene primero.',
          'Soporte de IAM: cuentas, accesos y revisión de privilegios.',
          'Informes de seguridad automatizados con Python, para que no dependan de copiar datos a mano.',
        ],
      },
      {
        h: 'Con qué herramientas',
        items: [
          'Trend Micro Vision One: Security Operations, Cloud Security, Identity Security, Email & Collaboration Security, Threat Intelligence y AI Security.',
          'Fortinet: FortiGate y FortiAnalyzer.',
          'Python para automatización y análisis; Active Directory y Windows Server.',
        ],
      },
      {
        h: 'Certificaciones',
        items: [
          'Siete certificaciones Trend Micro Vision One (Cloud, Identity, Email & Collaboration, SecOps, Threat Intelligence, AI Security y Platform Advanced).',
          'Fortinet NSE 3, Fortinet Certified Associate Cybersecurity y FortiGate 7.6 Operator.',
          'Microsoft Azure AI Fundamentals.',
          'La lista completa y verificable está en la sección de certificaciones de la portada.',
        ],
      },
    ],
    faqTitle: 'Preguntas frecuentes',
    faq: [
      {
        q: '¿Qué hace un analista SOC?',
        a: 'Vigila las alertas de seguridad de una organización, decide cuáles son incidentes reales, los investiga y propone cómo contenerlos. Trabaja con herramientas como XDR y SIEM y deja constancia de cada caso.',
      },
      {
        q: '¿Dónde trabajas?',
        a: 'En el SOC de Dagram, en Barcelona. Vivo en Badalona.',
      },
      {
        q: '¿Qué formación tienes?',
        a: 'Estudio el ciclo superior de Administración de Sistemas Informáticos en Red (itinerario Ciberseguridad) en el Col·legi Cultural, y tengo las certificaciones de Trend Micro, Fortinet y Microsoft que se listan arriba.',
      },
      {
        q: '¿Cómo contacto contigo?',
        a: 'Por LinkedIn o por el formulario de contacto de la portada.',
      },
    ],
    ctaContact: 'Contactar',
    ctaHome: 'Ver el portfolio completo',
    back: 'Volver al inicio',
  },
  en: {
    path: socAlternates.en,
    title: 'SOC Analyst in Barcelona & Badalona | Eduardo Olivares',
    description:
      'SOC analyst in Barcelona and Badalona, Spain: alert triage in Trend Micro Vision One, threat detection, incident response and Python automation.',
    breadcrumb: 'SOC analyst in Barcelona',
    kicker: 'Profile / SOC',
    h1: 'SOC Analyst in Barcelona and Badalona',
    answer:
      'I am Eduardo Olivares, a cybersecurity analyst in a SOC in Barcelona (Dagram), and I live in Badalona. I triage alerts in Trend Micro Vision One, investigate email, identity and endpoint incidents, and automate security reporting with Python. I hold certifications from Trend Micro, Fortinet and Microsoft.',
    sections: [
      {
        h: 'What I do in the SOC',
        items: [
          'Alert triage and prioritisation in Trend Micro Vision One (XDR).',
          'Investigating email, identity and endpoint incidents: what happened, who is affected and what to contain first.',
          'IAM support: accounts, access and privilege reviews.',
          'Security reports automated with Python, so they do not rely on copying data by hand.',
        ],
      },
      {
        h: 'Tools',
        items: [
          'Trend Micro Vision One: Security Operations, Cloud Security, Identity Security, Email & Collaboration Security, Threat Intelligence and AI Security.',
          'Fortinet: FortiGate and FortiAnalyzer.',
          'Python for automation and analysis; Active Directory and Windows Server.',
        ],
      },
      {
        h: 'Certifications',
        items: [
          'Seven Trend Micro Vision One certifications (Cloud, Identity, Email & Collaboration, SecOps, Threat Intelligence, AI Security and Platform Advanced).',
          'Fortinet NSE 3, Fortinet Certified Associate Cybersecurity and FortiGate 7.6 Operator.',
          'Microsoft Azure AI Fundamentals.',
          'The full, verifiable list is in the certifications section of the home page.',
        ],
      },
    ],
    faqTitle: 'Frequently asked questions',
    faq: [
      {
        q: 'What does a SOC analyst do?',
        a: 'They watch an organisation\'s security alerts, decide which ones are real incidents, investigate them and recommend how to contain them. They work with tools such as XDR and SIEM and document every case.',
      },
      {
        q: 'Where do you work?',
        a: 'In the SOC at Dagram, in Barcelona. I live in Badalona.',
      },
      {
        q: 'What is your background?',
        a: 'I am studying the higher-level Network Systems Administration programme (cybersecurity track) at Col·legi Cultural, and I hold the Trend Micro, Fortinet and Microsoft certifications listed above.',
      },
      {
        q: 'How can I contact you?',
        a: 'Through LinkedIn or the contact form on the home page.',
      },
    ],
    ctaContact: 'Get in touch',
    ctaHome: 'See the full portfolio',
    back: 'Back to home',
  },
  ca: {
    path: socAlternates.ca,
    title: 'Analista SOC a Barcelona i Badalona | Eduardo Olivares',
    description:
      'Analista SOC a Barcelona i Badalona: triatge d\'alertes a Trend Micro Vision One, detecció d\'amenaces, resposta a incidents i automatització amb Python.',
    breadcrumb: 'Analista SOC a Barcelona',
    kicker: 'Perfil / SOC',
    h1: 'Analista SOC a Barcelona i Badalona',
    answer:
      'Sóc l\'Eduardo Olivares, analista de ciberseguretat en un SOC de Barcelona (Dagram) i visc a Badalona. Faig triatge d\'alertes a Trend Micro Vision One, investigo incidents de correu, identitat i endpoint, i automatitzo els informes de seguretat amb Python. Estic certificat per Trend Micro, Fortinet i Microsoft.',
    sections: [
      {
        h: 'Què faig al SOC',
        items: [
          'Triatge i priorització d\'alertes a Trend Micro Vision One (XDR).',
          'Investigació d\'incidents de correu, identitat i endpoint: què ha passat, a qui afecta i què es conté primer.',
          'Suport d\'IAM: comptes, accessos i revisió de privilegis.',
          'Informes de seguretat automatitzats amb Python, perquè no depenguin de copiar dades a mà.',
        ],
      },
      {
        h: 'Amb quines eines',
        items: [
          'Trend Micro Vision One: Security Operations, Cloud Security, Identity Security, Email & Collaboration Security, Threat Intelligence i AI Security.',
          'Fortinet: FortiGate i FortiAnalyzer.',
          'Python per a automatització i anàlisi; Active Directory i Windows Server.',
        ],
      },
      {
        h: 'Certificacions',
        items: [
          'Set certificacions Trend Micro Vision One (Cloud, Identity, Email & Collaboration, SecOps, Threat Intelligence, AI Security i Platform Advanced).',
          'Fortinet NSE 3, Fortinet Certified Associate Cybersecurity i FortiGate 7.6 Operator.',
          'Microsoft Azure AI Fundamentals.',
          'La llista completa i verificable és a la secció de certificacions de la portada.',
        ],
      },
    ],
    faqTitle: 'Preguntes freqüents',
    faq: [
      {
        q: 'Què fa un analista SOC?',
        a: 'Vigila les alertes de seguretat d\'una organització, decideix quines són incidents reals, les investiga i proposa com contenir-les. Treballa amb eines com XDR i SIEM i deixa constància de cada cas.',
      },
      {
        q: 'On treballes?',
        a: 'Al SOC de Dagram, a Barcelona. Visc a Badalona.',
      },
      {
        q: 'Quina formació tens?',
        a: 'Estudio el cicle superior d\'Administració de Sistemes Informàtics en Xarxa (itinerari Ciberseguretat) al Col·legi Cultural, i tinc les certificacions de Trend Micro, Fortinet i Microsoft que es llisten a dalt.',
      },
      {
        q: 'Com puc contactar amb tu?',
        a: 'Per LinkedIn o pel formulari de contacte de la portada.',
      },
    ],
    ctaContact: 'Contactar',
    ctaHome: 'Veure el portfolio complet',
    back: 'Tornar a l\'inici',
  },
};
