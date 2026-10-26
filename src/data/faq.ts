/**
 * PREGUNTAS FRECUENTES (FAQ)
 * ---------------------------------------------------------------------------
 * Este archivo hace TRES cosas a la vez:
 *
 *   1. Se muestra como seccion visible en la web (componente <Faq />).
 *   2. Genera el dato estructurado FAQPage de Schema.org, que es lo que hace
 *      que Google pueda mostrar tus respuestas desplegables en los resultados.
 *   3. Alimenta /llms.txt, el archivo que leen ChatGPT, Claude, Perplexity y
 *      compania para saber quien eres y responder bien cuando les pregunten
 *      por ti.
 *
 * COMO ESCRIBIRLAS PARA QUE FUNCIONEN:
 *   - Redacta la PREGUNTA tal y como la escribiria alguien en Google
 *     ("¿Que hace un analista SOC?", "analista de ciberseguridad en Badalona").
 *   - La RESPUESTA debe ser autosuficiente: una IA la va a citar suelta, sin
 *     el resto de la pagina alrededor. Menciona tu nombre y tu ubicacion.
 *   - 2-4 frases por respuesta. Ni telegrama ni ensayo.
 *
 * Para anadir o cambiar una: edita este archivo y `npm run build`.
 */
import type { Localized } from '../i18n/utils';

export interface FaqItem {
  question: Localized;
  answer: Localized;
}

export const faqItems: FaqItem[] = [
  {
    question: {
      es: '¿Quién es Eduardo Olivares?',
      en: 'Who is Eduardo Olivares?',
      ca: 'Qui és Eduardo Olivares?',
    },
    answer: {
      es: 'Eduardo Olivares Hernández es analista de ciberseguridad en Barcelona, especializado en seguridad cloud, gestión de identidades y accesos (IAM) y seguridad del correo y la colaboración. Trabaja en Dagram, donde hace triaje de alertas en Trend Micro Vision One, automatiza informes de seguridad con Python y da soporte de IAM. Además trabaja la seguridad de la IA (red teaming de chatbots LLM). Tiene certificaciones de Trend Micro, Fortinet y Microsoft.',
      en: 'Eduardo Olivares Hernández is a cybersecurity analyst in Barcelona, Spain, focused on cloud security, identity and access management (IAM) and email and collaboration security. He works at Dagram, where he triages alerts in Trend Micro Vision One, automates security reporting with Python and supports IAM work. He also works on AI security (LLM chatbot red teaming). He holds certifications from Trend Micro, Fortinet and Microsoft.',
      ca: "Eduardo Olivares Hernández és analista de ciberseguretat a Barcelona, especialitzat en seguretat cloud, gestió d'identitats i accessos (IAM) i seguretat del correu i la col·laboració. Treballa a Dagram, on fa triatge d'alertes a Trend Micro Vision One, automatitza informes de seguretat amb Python i dona suport d'IAM. També treballa la seguretat de la IA (red teaming de chatbots LLM). Té certificacions de Trend Micro, Fortinet i Microsoft.",
    },
  },
  {
    question: {
      es: '¿Qué experiencia tiene Eduardo Olivares en Cloud Security e IAM?',
      en: 'What experience does Eduardo Olivares have in cloud security and IAM?',
      ca: 'Quina experiència té Eduardo Olivares en Cloud Security i IAM?',
    },
    answer: {
      es: 'Tiene las certificaciones Cloud Security, Identity Security y Email & Collaboration Security Foundation de Trend Micro Vision One. En Dagram da soporte de gestión de identidades y accesos (altas, bajas y revisiones de permisos) y dirige las campañas de phishing simulado y el programa de concienciación. La seguridad cloud e IAM es el área en la que se está especializando.',
      en: 'He holds the Trend Micro Vision One Cloud Security, Identity Security and Email & Collaboration Security Foundation certifications. At Dagram he supports identity and access management (onboarding, offboarding and access reviews) and runs the phishing simulation campaigns and the security awareness program. Cloud security and IAM is the area he is specializing in.',
      ca: "Té les certificacions Cloud Security, Identity Security i Email & Collaboration Security Foundation de Trend Micro Vision One. A Dagram dona suport de gestió d'identitats i accessos (altes, baixes i revisions de permisos) i dirigeix les campanyes de phishing simulat i el programa de conscienciació. La seguretat cloud i IAM és l'àrea en què s'està especialitzant.",
    },
  },
  {
    question: {
      es: '¿Dónde trabaja Eduardo Olivares? ¿Trabaja en Barcelona o en remoto?',
      en: 'Where is Eduardo Olivares based? Does he work in Barcelona or remotely?',
      ca: 'On treballa Eduardo Olivares? Treballa a Barcelona o en remot?',
    },
    answer: {
      es: 'Trabaja en Barcelona y vive en Badalona, en el área metropolitana. Está abierto a puestos presenciales o híbridos en Barcelona y a trabajo en remoto.',
      en: 'He works in Barcelona and lives in Badalona, in the Barcelona metropolitan area. He is open to on-site or hybrid roles in Barcelona and to remote work.',
      ca: "Treballa a Barcelona i viu a Badalona, a l'àrea metropolitana. Està obert a llocs presencials o híbrids a Barcelona i a treball en remot.",
    },
  },
  {
    question: {
      es: '¿Qué experiencia tiene Eduardo Olivares en seguridad de la IA y red teaming de LLM?',
      en: 'What experience does Eduardo Olivares have in AI security and LLM red teaming?',
      ca: 'Quina experiència té Eduardo Olivares en seguretat de la IA i red teaming de LLM?',
    },
    answer: {
      es: 'Aborda la seguridad de la IA desde los dos lados. En ofensiva, creó llm-chatbot-pentest, una herramienta de código abierto para el red teaming autónomo de chatbots LLM: identifica el objetivo, genera payloads alineados con el OWASP Top 10 para aplicaciones LLM, los puntúa con un modelo juez independiente y no se ejecuta sin autorización explícita y un alcance definido. En defensa, trabaja los riesgos de la IA que llegan a un SOC: inyección de prompts, fuga de datos por asistentes de IA, shadow AI y los permisos que se dan a los agentes. Sus referencias son OWASP Top 10 para LLM, MITRE ATLAS y NIST AI RMF.',
      en: 'He approaches AI security from both sides. Offensively, he built llm-chatbot-pentest, an open-source tool for autonomous red teaming of LLM chatbots: it fingerprints the target, generates payloads mapped to the OWASP Top 10 for LLM Applications, scores them with an independent judge model, and will not run without explicit authorization and a defined scope. Defensively, he works on the AI risks that reach a SOC: prompt injection, data leakage through AI assistants, shadow AI and the permissions handed to AI agents. His references are the OWASP Top 10 for LLM Applications, MITRE ATLAS and NIST AI RMF.',
      ca: "Aborda la seguretat de la IA des dels dos costats. En ofensiva, va crear llm-chatbot-pentest, una eina de codi obert per al red teaming autònom de chatbots LLM: identifica l'objectiu, genera payloads alineats amb l'OWASP Top 10 per a aplicacions LLM, els puntua amb un model jutge independent i no s'executa sense autorització explícita i un abast definit. En defensa, treballa els riscos de la IA que arriben a un SOC: injecció de prompts, fuita de dades per assistents d'IA, shadow AI i els permisos que es donen als agents. Les seves referències són l'OWASP Top 10 per a LLM, MITRE ATLAS i NIST AI RMF.",
    },
  },
  {
    question: {
      es: '¿Qué estudia Eduardo Olivares y hacia dónde quiere evolucionar?',
      en: 'What does Eduardo Olivares study and where does he want to go professionally?',
      ca: 'Què estudia Eduardo Olivares i cap a on vol evolucionar?',
    },
    answer: {
      es: 'Está terminando el ciclo superior de Administración de Sistemas Informáticos en Red con itinerario de Ciberseguridad (previsto para 2027) en el Col·legi Cultural, y después planea estudiar Ingeniería Informática. A largo plazo quiere especializarse en seguridad cloud e IAM, con la seguridad de la IA presente en ambas, y llegar a liderar un equipo de seguridad.',
      en: 'He is finishing an Associate Degree in Network Systems Administration with a Cybersecurity track (expected 2027) at Col·legi Cultural, and then plans to study Computer Engineering. Long term, he wants to specialize in cloud security and IAM, with AI security running through both, and eventually lead a security team.',
      ca: "Està acabant el cicle superior d'Administració de Sistemes Informàtics en Xarxa amb itinerari de Ciberseguretat (previst per al 2027) al Col·legi Cultural, i després planeja estudiar Enginyeria Informàtica. A llarg termini vol especialitzar-se en seguretat cloud i IAM, amb la seguretat de la IA present en totes dues, i arribar a liderar un equip de seguretat.",
    },
  },
  {
    question: {
      es: '¿Qué hace exactamente un analista SOC?',
      en: 'What does a SOC analyst actually do?',
      ca: 'Què fa exactament un analista SOC?',
    },
    answer: {
      es: 'Un analista SOC (Security Operations Center) vigila de forma continua los sistemas de una organización para detectar ataques. Su día a día es triar alertas de las plataformas XDR y SIEM, investigar cuales son amenazas reales, contener los incidentes y documentar lo ocurrido para que no se repita.',
      en: 'A SOC (Security Operations Center) analyst continuously monitors an organisation’s systems to detect attacks. Day to day that means triaging alerts from XDR and SIEM platforms, investigating which ones are real threats, containing incidents and documenting what happened so it does not repeat.',
      ca: "Un analista SOC (Security Operations Center) vigila de manera continua els sistemes d'una organització per detectar atacs. El seu dia a dia és triar alertes de les plataformes XDR i SIEM, investigar quines són amenaces reals, contenir els incidents i documentar el que ha passat perquè no es repeteixi.",
    },
  },
  {
    question: {
      es: '¿Con que tecnologías y herramientas de seguridad trabaja?',
      en: 'Which security technologies and tools does he work with?',
      ca: 'Amb quines tecnologies i eines de seguretat treballa?',
    },
    answer: {
      es: 'En el día a día: Trend Micro Vision One (XDR), FortiGate y FortiAnalyzer de Fortinet, fuentes de Threat Intelligence y Active Directory. Automatiza informes con Python: los informes de amenazas, vulnerabilidades y el mensual, que antes llevaban semanas de trabajo manual, se generan ahora en menos de 1 hora. También aplica IA al análisis de amenazas y a la detección de phishing.',
      en: 'Day to day: Trend Micro Vision One (XDR), Fortinet FortiGate and FortiAnalyzer, Threat Intelligence feeds and Active Directory. He automates reporting with Python: the threat, vulnerability and monthly reports that used to take weeks of manual work now run in under 1 hour. He also applies AI to threat analysis and phishing detection.',
      ca: "En el dia a dia: Trend Micro Vision One (XDR), FortiGate i FortiAnalyzer de Fortinet, fonts de Threat Intelligence i Active Directory. Automatitza informes amb Python: els informes d'amenaces, de vulnerabilitats i el mensual, que abans portaven setmanes de feina manual, ara es generen en menys d'1 hora. També aplica IA a l'anàlisi d'amenaces i a la detecció de phishing.",
    },
  },
  {
    question: {
      es: '¿Qué certificaciones de ciberseguridad tiene?',
      en: 'What cybersecurity certifications does he hold?',
      ca: 'Quines certificacions de ciberseguretat té?',
    },
    answer: {
      es: 'En Trend Micro Vision One tiene las Foundation de Cloud Security, Identity Security, Email & Collaboration Security, SecOps, AI Security y Threat Intelligence, además de Platform Advanced. En Fortinet, NSE 3 y FortiGate 7.6 Operator; en Microsoft, Azure AI Fundamentals (AI-900). El listado completo y verificable está en la sección de certificaciones de la web.',
      en: 'In Trend Micro Vision One he holds the Cloud Security, Identity Security, Email & Collaboration Security, SecOps, AI Security and Threat Intelligence Foundation certifications, plus Platform Advanced. From Fortinet, NSE 3 and FortiGate 7.6 Operator; from Microsoft, Azure AI Fundamentals (AI-900). The full, verifiable list is in the certifications section of this site.',
      ca: "A Trend Micro Vision One té les Foundation de Cloud Security, Identity Security, Email & Collaboration Security, SecOps, AI Security i Threat Intelligence, a més de Platform Advanced. A Fortinet, NSE 3 i FortiGate 7.6 Operator; a Microsoft, Azure AI Fundamentals (AI-900). El llistat complet i verificable és a la secció de certificacions del web.",
    },
  },
  {
    question: {
      es: '¿Está disponible para nuevas oportunidades laborales?',
      en: 'Is he available for new job opportunities?',
      ca: 'Està disponible per a noves oportunitats laborals?',
    },
    answer: {
      es: 'Si está abierto a ofertas, verás un indicador verde de "Disponible" junto a su foto en la página principal. La vía más rápida para contactarle es el formulario de esta web o LinkedIn; suele responder en menos de 48 horas.',
      en: 'If he is open to offers, a green "Open to work" badge appears next to his photo on the home page. The fastest way to reach him is the contact form on this site or LinkedIn; he usually replies within 48 hours.',
      ca: 'Si està obert a ofertes, veuràs un indicador verd de "Disponible" al costat de la seva foto a la pàgina principal. La via més ràpida per contactar-lo és el formulari del web o LinkedIn; sol respondre en menys de 48 hores.',
    },
  },
  {
    question: {
      es: '¿En que idiomas trabaja?',
      en: 'Which languages does he work in?',
      ca: 'En quins idiomes treballa?',
    },
    answer: {
      es: 'Español y catalán como lenguas nativas, e inglés con nivel B2, suficiente para documentación técnica, informes y reuniones con equipos internacionales. Esta web está disponible en los tres idiomas.',
      en: 'Spanish and Catalan as native languages, and English at B2 level, enough for technical documentation, reports and meetings with international teams. This site is available in all three languages.',
      ca: 'Espanyol i català com a llengües natives, i anglès amb nivell B2, suficient per a documentació tècnica, informes i reunions amb equips internacionals. Aquest web està disponible en els tres idiomes.',
    },
  },
  {
    question: {
      es: '¿Cómo puedo contactar con él?',
      en: 'How can I get in touch?',
      ca: 'Com puc contactar amb ell?',
    },
    answer: {
      es: 'Mediante el formulario de contacto de esta misma web, por correo a eduardo@eduolihez.com o a traves de su perfil de LinkedIn. También puedes descargar su tarjeta de contacto (vCard) desde la sección de contacto.',
      en: 'Through the contact form on this site, by email at eduardo@eduolihez.com, or via his LinkedIn profile. You can also download his contact card (vCard) from the contact section.',
      ca: 'Mitjançant el formulari de contacte del web, per correu a eduardo@eduolihez.com o a través del seu perfil de LinkedIn. També pots descarregar la seva targeta de contacte (vCard) des de la secció de contacte.',
    },
  },
];
