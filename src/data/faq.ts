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
      es: '¿Quien es Eduardo Olivares?',
      en: 'Who is Eduardo Olivares?',
      ca: 'Qui es Eduardo Olivares?',
    },
    answer: {
      es: 'Eduardo Olivares Hernandez es analista de ciberseguridad (SOC Analyst, Blue Team) con base en Badalona, en el area metropolitana de Barcelona. Trabaja en deteccion de amenazas, respuesta a incidentes y automatizacion de seguridad con Python, y esta certificado por Fortinet (NSE), Microsoft y Trend Micro.',
      en: 'Eduardo Olivares Hernandez is a cybersecurity analyst (SOC Analyst, Blue Team) based in Badalona, in the Barcelona metropolitan area. He works on threat detection, incident response and Python security automation, and holds certifications from Fortinet (NSE), Microsoft and Trend Micro.',
      ca: "Eduardo Olivares Hernandez es analista de ciberseguretat (SOC Analyst, Blue Team) amb base a Badalona, a l'area metropolitana de Barcelona. Treballa en deteccio d'amenaces, resposta a incidents i automatitzacio de seguretat amb Python, i esta certificat per Fortinet (NSE), Microsoft i Trend Micro.",
    },
  },
  {
    question: {
      es: '¿Donde trabaja Eduardo Olivares? ¿Da servicio en Badalona y Barcelona?',
      en: 'Where is Eduardo Olivares based? Does he work in Badalona and Barcelona?',
      ca: 'On treballa Eduardo Olivares? Dona servei a Badalona i Barcelona?',
    },
    answer: {
      es: 'Reside en Badalona (Barcelona, Cataluna) y trabaja tanto en el area metropolitana de Barcelona como en remoto. Esta acostumbrado a entornos SOC distribuidos, asi que puede colaborar con equipos de toda Espana sin problema.',
      en: 'He lives in Badalona (Barcelona, Catalonia) and works both across the Barcelona metropolitan area and remotely. He is used to distributed SOC environments, so he can work with teams anywhere in Spain.',
      ca: "Resideix a Badalona (Barcelona, Catalunya) i treballa tant a l'area metropolitana de Barcelona com en remot. Esta acostumat a entorns SOC distribuits, aixi que pot col·laborar amb equips de tot Espanya sense problema.",
    },
  },
  {
    question: {
      es: '¿Que hace exactamente un analista SOC?',
      en: 'What does a SOC analyst actually do?',
      ca: 'Que fa exactament un analista SOC?',
    },
    answer: {
      es: 'Un analista SOC (Security Operations Center) vigila de forma continua los sistemas de una organizacion para detectar ataques. Su dia a dia es triar alertas de las plataformas XDR y SIEM, investigar cuales son amenazas reales, contener los incidentes y documentar lo ocurrido para que no se repita.',
      en: 'A SOC (Security Operations Center) analyst continuously monitors an organisation’s systems to detect attacks. Day to day that means triaging alerts from XDR and SIEM platforms, investigating which ones are real threats, containing incidents and documenting what happened so it does not repeat.',
      ca: "Un analista SOC (Security Operations Center) vigila de manera continua els sistemes d'una organitzacio per detectar atacs. El seu dia a dia es triar alertes de les plataformes XDR i SIEM, investigar quines son amenaces reals, contenir els incidents i documentar el que ha passat perque no es repeteixi.",
    },
  },
  {
    question: {
      es: '¿Con que tecnologias y herramientas de seguridad trabaja?',
      en: 'Which security technologies and tools does he work with?',
      ca: 'Amb quines tecnologies i eines de seguretat treballa?',
    },
    answer: {
      es: 'En el dia a dia: Trend Micro Vision One (XDR), FortiGate y FortiAnalyzer de Fortinet, plataformas SIEM, fuentes de Threat Intelligence y Active Directory. Automatiza informes y tareas repetitivas con Python, y aplica modelos de IA al analisis de amenazas y a la deteccion de phishing.',
      en: 'Day to day: Trend Micro Vision One (XDR), Fortinet FortiGate and FortiAnalyzer, SIEM platforms, Threat Intelligence feeds and Active Directory. He automates reports and repetitive tasks with Python, and applies AI models to threat analysis and phishing detection.',
      ca: "En el dia a dia: Trend Micro Vision One (XDR), FortiGate i FortiAnalyzer de Fortinet, plataformes SIEM, fonts de Threat Intelligence i Active Directory. Automatitza informes i tasques repetitives amb Python, i aplica models d'IA a l'analisi d'amenaces i a la deteccio de phishing.",
    },
  },
  {
    question: {
      es: '¿Que certificaciones de ciberseguridad tiene?',
      en: 'What cybersecurity certifications does he hold?',
      ca: 'Quines certificacions de ciberseguretat te?',
    },
    answer: {
      es: 'Esta certificado en Fortinet NSE (seguridad de red), Microsoft Cybersecurity y Azure AI Fundamentals, y en el itinerario de Trend Micro Vision One: SecOps, AI Security, Threat Intelligence y Cloud Security. El listado completo y verificable esta en la seccion de certificaciones de la web.',
      en: 'He is certified in Fortinet NSE (network security), Microsoft Cybersecurity and Azure AI Fundamentals, plus the Trend Micro Vision One track: SecOps, AI Security, Threat Intelligence and Cloud Security. The full, verifiable list is in the certifications section of this site.',
      ca: "Esta certificat en Fortinet NSE (seguretat de xarxa), Microsoft Cybersecurity i Azure AI Fundamentals, i en l'itinerari de Trend Micro Vision One: SecOps, AI Security, Threat Intelligence i Cloud Security. El llistat complet i verificable es a la seccio de certificacions del web.",
    },
  },
  {
    question: {
      es: '¿Esta disponible para nuevas oportunidades laborales?',
      en: 'Is he available for new job opportunities?',
      ca: 'Esta disponible per a noves oportunitats laborals?',
    },
    answer: {
      es: 'Si esta abierto a ofertas, veras un indicador verde de "Disponible" junto a su foto en la pagina principal. La via mas rapida para contactarle es el formulario de esta web o LinkedIn; suele responder en menos de 48 horas.',
      en: 'If he is open to offers, a green "Open to work" badge appears next to his photo on the home page. The fastest way to reach him is the contact form on this site or LinkedIn; he usually replies within 48 hours.',
      ca: 'Si esta obert a ofertes, veuras un indicador verd de "Disponible" al costat de la seva foto a la pagina principal. La via mes rapida per contactar-lo es el formulari del web o LinkedIn; sol respondre en menys de 48 hores.',
    },
  },
  {
    question: {
      es: '¿En que idiomas trabaja?',
      en: 'Which languages does he work in?',
      ca: 'En quins idiomes treballa?',
    },
    answer: {
      es: 'Espanol y catalan como lenguas nativas, e ingles con nivel B2, suficiente para documentacion tecnica, informes y reuniones con equipos internacionales. Esta web esta disponible en los tres idiomas.',
      en: 'Spanish and Catalan as native languages, and English at B2 level, enough for technical documentation, reports and meetings with international teams. This site is available in all three languages.',
      ca: 'Espanyol i catala com a llengues natives, i angles amb nivell B2, suficient per a documentacio tecnica, informes i reunions amb equips internacionals. Aquest web esta disponible en els tres idiomes.',
    },
  },
  {
    question: {
      es: '¿Como puedo contactar con el?',
      en: 'How can I get in touch?',
      ca: 'Com puc contactar amb ell?',
    },
    answer: {
      es: 'Mediante el formulario de contacto de esta misma web, por correo a eduardo@eduolihez.com o a traves de su perfil de LinkedIn. Tambien puedes descargar su tarjeta de contacto (vCard) desde la seccion de contacto.',
      en: 'Through the contact form on this site, by email at eduardo@eduolihez.com, or via his LinkedIn profile. You can also download his contact card (vCard) from the contact section.',
      ca: 'Mitjancant el formulari de contacte del web, per correu a eduardo@eduolihez.com o a traves del seu perfil de LinkedIn. Tambe pots descarregar la seva targeta de contacte (vCard) des de la seccio de contacte.',
    },
  },
];
