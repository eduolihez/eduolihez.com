/**
 * Titulo y meta description a medida para articulos cuyo texto de la base de
 * datos no cabe en el SERP (titulo > 60, descripcion > 155). Se indexa por slug.
 * El contenido visible del articulo NO cambia: solo <title>, description y OG.
 * Limites verificados en seo-overrides.test.ts.
 */
export interface SeoOverride {
  title?: string;
  description?: string;
}

export const seoOverrides: Record<string, SeoOverride> = {
  // --- ES ---
  'auditar-permisos-de-microsoft-365-en-una-tarde': {
    description: 'Auditoría de permisos de Microsoft 365 en una tarde: admins, MFA, cuentas sin uso, consentimientos OAuth y reenvíos, con PowerShell de solo lectura.',
  },
  'certificaciones-para-empezar-como-analista-soc': {
    title: 'Certificaciones para analista SOC: cuáles valen la pena',
    description: 'Security+, SC-200, CySA+ y BTL1: qué aporta cada certificación en un primer puesto SOC, cuáles dejar para después y qué pesa más que un título.',
  },
  'ransomware-que-hacer-en-las-primeras-24-horas': {
    description: 'Qué hacer ante un ransomware: aislar equipos, cortar accesos, proteger copias, guardar evidencias, avisar a la AEPD en 72 h y recuperar.',
  },
  'he-hecho-clic-en-un-phishing-que-hacer-ahora': {
    description: 'Qué hacer en los primeros minutos tras hacer clic en un phishing, según lo ocurrido: solo clic, contraseña, fichero abierto o datos bancarios.',
  },
  'ciberseguridad-para-pymes-en-barcelona-diez-medidas': {
    title: 'Ciberseguridad para pymes en Barcelona: 10 medidas',
    description: 'Diez medidas de ciberseguridad para pymes de Barcelona y Badalona con herramientas que ya pagas: MFA, copias, bajas de cuentas, DMARC y control del fraude.',
  },
  'que-hace-un-analista-soc-un-dia-de-trabajo-real': {
    title: 'Qué hace un analista SOC: un día de trabajo real',
    description: 'Qué hace un analista SOC cada día: revisar alertas, investigar, contener y documentar. Niveles N1 a N3, herramientas y cómo entrar sin experiencia.',
  },
  'errores-de-configuracion-cloud-mas-comunes': {
    description: 'Configuraciones erróneas en la nube: casi todas las brechas cloud vienen de la configuración. Buckets públicos, claves eternas, logs apagados.',
  },
  'minimo-privilegio-en-microsoft-entra-id': {
    description: 'Demasiados administradores globales y roles permanentes. Cómo aplicar el mínimo privilegio en Microsoft Entra ID con roles, PIM y cuentas break-glass.',
  },
  'el-desacuerdo-entre-clasificadores-pierde-contra-algo-mas-simple': {
    title: 'Clasificadores en desacuerdo: gana algo más simple',
    description: 'Con 7.822 correos reales mido si el desacuerdo entre cuatro clasificadores ayuda a priorizar qué revisa un analista. Pierde contra algo más simple.',
  },
  'lo-que-da-tiempo-a-aprender-en-24-horas-de-hackathon': {
    title: 'Qué da tiempo a aprender en 24 horas de hackathon',
    description: 'Dewi App, nuestro prototipo ganador en la Hackathon TecnoCampus: un sensor de caudal conectado a una web de consumo de agua, montado en menos de un día.',
  },
  'revocar-un-token-sin-derribar-la-sesion-entera': {
    description: 'BinCat, un SDK de Python para emitir, validar y revocar tokens Fernet y JWT con auditoría. Por qué revocar un acceso no debe cerrar la sesión.',
  },
  'blue-team-hub-por-que-quite-el-cristal-esmerilado': {
    title: 'Blue Team Hub: por qué quité el cristal esmerilado',
    description: 'Siete herramientas de SOC gratuitas y del lado del cliente, con vigilancia en vivo del catálogo KEV. Y por qué rediseñé el sitio en blanco y negro.',
  },
  'vigilar-el-catalogo-kev-de-cisa-sin-servidor': {
    title: 'Vigilar el catálogo KEV de CISA sin servidor',
    description: 'kev-digest comprueba el catálogo CISA KEV cada tres horas y publica los cambios con GitHub Actions, sin dependencias externas ni servidor encendido.',
  },
  'active-directory-los-primeros-diez-cambios-en-cualquier-dominio-nuevo': {
    title: 'Active Directory: 10 cambios en un dominio nuevo',
    description: 'La lista corta que reviso siempre en un dominio de Active Directory nuevo, antes de tocar GPOs avanzadas. Casi todo viene mal desde la instalación.',
  },
  'de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto': {
    description: 'Pasar de dar soporte a más de 100 usuarios a triar alertas en un SOC no fue un cambio de título, sino de la pregunta ante cada tarea repetitiva.',
  },
  'hardening-fortigate-antes-de-dar-un-despliegue-por-bueno': {
    title: 'Hardening de FortiGate: qué reviso antes del OK',
    description: 'La configuración de fábrica de un FortiGate no está lista para producción. Mi lista de revisión y por qué la inspección SSL es lo que más se pospone.',
  },
  'priorizar-cves-sin-fiarse-solo-del-cvss': {
    description: 'Un CVSS de 9.8 puede ser irrelevante y uno de 6.5 una emergencia. Cómo cruzo NVD, el catálogo KEV de CISA y EPSS para decidir qué parchear primero.',
  },
  'automatizar-el-informe-semanal-del-soc-con-python': {
    description: 'El informe semanal del SOC eran tres horas de copiar y pegar. Al automatizarlo con Python, lo difícil fue la paginación y las zonas horarias.',
  },
  'clasificar-phishing-en-el-navegador-sin-mandar-la-url': {
    title: 'Clasificar phishing en el navegador sin enviar la URL',
    description: 'Un modelo ONNX pequeño dentro del navegador clasifica phishing sin que la URL salga del equipo. Lo pruebo en NorthGate Browser.',
  },
  'triaje-de-alertas-en-un-soc-en-que-orden-mirar': {
    description: 'La severidad de una alerta no es su prioridad. Cómo ordeno la cola cuando hay más alertas que horas y las tres preguntas con las que abro cada una.',
  },
  'comprobar-si-una-contrasena-esta-filtrada-sin-enviarsela-a-nadie': {
    title: 'Comprobar si una contraseña está filtrada sin enviarla',
    description: 'Cómo consultar Have I Been Pwned, con más de 800 millones de contraseñas filtradas, sin revelar cuál buscas: k-anonimato, aplicado en Password Sentinel.',
  },
  'mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta': {
    title: 'MFA resistente a phishing: por qué el SMS no basta',
    description: 'MFA resistente a phishing (phishing-resistant MFA): por qué el SMS y el push ya no bastan y qué usar en su lugar, con FIDO2 y passkeys.',
  },
  'xdr-vs-siem-vs-edr-diferencias-en-un-soc': {
    description: 'SIEM vs EDR vs XDR: en qué se diferencian, qué ve cada uno y cuándo usarlos en un SOC real. Explicado por un analista SOC en Barcelona.',
  },
  // --- CA ---
  'auditar-els-permisos-de-microsoft-365-en-una-tarda': {
    description: 'Auditoria de permisos de Microsoft 365 en una tarda: admins, MFA, comptes sense ús, consentiments OAuth i reenviaments, amb PowerShell de només lectura.',
  },
  'certificacions-per-comencar-com-a-analista-soc-quines-valen-la-pena': {
    title: 'Certificacions per a analista SOC: quines valen la pena',
    description: 'Security+, SC-200, CySA+ i BTL1: què aporta cada certificació en un primer lloc SOC, quines deixar per més endavant i què pesa més que un títol.',
  },
  'ransomware-que-fer-en-les-primeres-24-hores': {
    description: "Què fer davant d'un ransomware: aïllar equips, tallar accessos, protegir còpies, guardar evidències, avisar l'AEPD en 72 h i recuperar des de còpies netes.",
  },
  'he-fet-clic-a-un-phishing-que-fer-ara-mateix': {
    description: 'Què fer en els primers minuts després de fer clic a un phishing, segons el que ha passat: només clic, contrasenya, fitxer obert o dades bancàries.',
  },
  'ciberseguretat-per-a-pimes-a-barcelona-i-badalona-deu-mesures': {
    title: 'Ciberseguretat per a pimes a Barcelona: 10 mesures',
  },
  'que-fa-un-analista-soc-un-dia-de-feina-real': {
    title: 'Què fa un analista SOC: un dia de feina real',
    description: 'Què fa un analista SOC cada dia: revisar alertes, investigar, contenir i documentar. Nivells N1 a N3, eines i com entrar-hi sense experiència.',
  },
  'secrets-en-repositoris-com-es-filtren-i-com-evitar-ho': {
    description: "Una clau d'API pujada a GitHub s'explota en minuts i esborrar-la del commit no n'hi ha prou. Com es filtren, com aturar-los abans del push i què fer.",
  },
  'xdr-siem-i-edr-diferencies-en-un-soc': {
    description: "L'EDR vigila l'endpoint, el SIEM centralitza logs i l'XDR correlaciona capes. Què aporta cadascun a la feina diària d'un SOC.",
  },
  'el-desacord-entre-classificadors-perd-contra-alguna-cosa-mes-simple': {
    title: 'Classificadors en desacord: guanya una cosa més simple',
    description: 'Amb 7.822 correus reals, mesuro si el desacord entre quatre classificadors serveix per decidir què revisa abans un analista. Les dades diuen que no.',
  },
  'el-que-dona-temps-a-aprendre-en-24-hores-de-hackathon': {
    title: 'Què dona temps a aprendre en 24 hores de hackathon',
  },
  'revocar-un-token-sense-enderrocar-la-sessio-sencera': {
    title: 'Revocar un token sense enderrocar la sessió sencera',
    description: 'BinCat, un SDK de Python per emetre, validar i revocar tokens Fernet i JWT amb auditoria i panell, per fer-ho sense escriure codi.',
  },
  'blue-team-hub-per-que-vaig-treure-el-vidre-esmerilat': {
    title: 'Blue Team Hub: per què vaig treure el vidre esmerilat',
    description: 'Set eines de SOC gratuïtes i del costat del client, amb vigilància en viu del catàleg KEV. I per què vaig redissenyar el lloc en blanc i negre.',
  },
  'vigilar-el-cataleg-kev-de-cisa-sense-servidor': {
    description: 'kev-digest comprova el catàleg CISA KEV cada tres hores i publica els canvis amb GitHub Actions, sense dependències externes.',
  },
  'active-directory-els-deu-primers-canvis-en-qualsevol-domini-nou': {
    title: 'Active Directory: 10 canvis en un domini nou',
  },
  'de-suport-tecnic-a-soc-el-que-va-canviar-no-va-ser-el-lloc': {
    description: 'Passar de donar suport a més de 100 usuaris a triar alertes en un SOC no va ser un canvi de títol, sinó de pregunta davant de cada tasca repetitiva.',
  },
  'hardening-de-fortigate-abans-de-donar-un-desplegament-per-bo': {
    title: 'Hardening de FortiGate: què reviso abans del vistiplau',
    description: "La configuració de fàbrica d'un FortiGate no està llesta per a producció. La llista que reviso sempre i per què la inspecció SSL s'ajorna tant.",
  },
  'prioritzar-cve-sense-refiar-se-nomes-del-cvss': {
    description: 'Un CVSS de 9,8 pot ser irrellevant i un de 6,5 una emergència. Com creuo NVD, el catàleg KEV de CISA i EPSS per decidir què pedaçar primer.',
  },
  'automatitzar-informe-setmanal-del-soc-amb-python': {
    description: "L'informe setmanal del SOC eren tres hores de copiar i enganxar. En automatitzar-lo amb Python, el difícil va ser la paginació i les zones horàries.",
  },
  'classificar-phishing-al-navegador-sense-enviar-la-url': {
    title: 'Classificar phishing al navegador sense enviar la URL',
    description: "Un model ONNX petit dins del navegador classifica phishing sense que la URL surti de l'equip. El provo a NorthGate Browser com a alternativa a les llistes.",
  },
  'triatge-alertes-en-un-soc-en-quin-ordre-mirar': {
    title: "Triatge d'alertes en un SOC: en quin ordre mirar",
    description: "La severitat d'una alerta no és la seva prioritat. Com ordeno la cua quan hi ha més alertes que hores i les tres preguntes amb què obro cadascuna.",
  },
  'comprovar-si-una-contrasenya-esta-filtrada-sense-enviar-la-a-ningu': {
    title: 'Comprovar si una contrasenya està filtrada sense enviar-la',
    description: 'Com consultar Have I Been Pwned, amb més de 800 milions de contrasenyes filtrades, sense revelar quina cerques: k-anonimat, aplicat a Password Sentinel.',
  },
};
