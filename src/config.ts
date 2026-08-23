/**
 * Configuracion central del sitio.
 * ---------------------------------------------------------------------------
 * Edita aqui tus datos personales, enlaces y la URL del backend PHP.
 * Es el UNICO sitio donde deberias tocar estos valores.
 */

export const SITE = {
  // Dominio de produccion (tambien configurado en astro.config.mjs -> site).
  domain: 'https://eduolihez.com',

  // Nombre y titulares.
  name: 'Eduardo Olivares Hernández',
  shortName: 'Edu Olivares',
  jobTitle: 'SOC Analyst · Blue Team',

  /**
   * Ubicacion. Alimenta el SEO local (que te encuentren buscando
   * "analista SOC Badalona" o "ciberseguridad Barcelona"), los datos
   * estructurados de Google y las etiquetas geo.
   */
  location: {
    city: 'Badalona',
    region: 'Barcelona',
    regionCode: 'ES-CT', // Cataluña (ISO 3166-2)
    country: 'ES',
    countryName: 'España',
    postalCode: '08911',
    // Coordenadas aproximadas de Badalona (centro). No es tu direccion:
    // solo situa el municipio para las busquedas locales.
    lat: 41.4500,
    lon: 2.2474,
    // Zonas donde trabajas o te desplazas (Google las usa para el SEO local).
    areaServed: [
      'Badalona',
      'Barcelona',
      'Área Metropolitana de Barcelona',
      'Cataluña',
      'España',
      'Remoto / Teletrabajo',
    ],
  },

  /** Empresa actual (para el dato estructurado worksFor). */
  worksFor: {
    name: 'Dagram',
    url: '',
  },

  /**
   * Temas en los que eres experto. Google (knowsAbout) y las IAs lo usan
   * para saber sobre que te pueden citar. Manten la lista concreta.
   */
  knowsAbout: [
    'Security Operations Center (SOC)',
    'Blue Team',
    'Detección de amenazas',
    'Respuesta a incidentes',
    'SIEM y XDR',
    'Trend Micro Vision One',
    'Fortinet FortiGate y FortiAnalyzer',
    'Análisis de phishing',
    'Threat Intelligence',
    'Automatización de seguridad con Python',
    'Inteligencia artificial aplicada a ciberseguridad',
    'Active Directory y Windows Server',
    'Ciberseguridad en Badalona y Barcelona',
  ],

  /** Idiomas que hablas (codigo BCP-47 + nivel legible). */
  languages: [
    { code: 'es', name: 'Español', level: 'Nativo' },
    { code: 'ca', name: 'Catalan', level: 'Nativo' },
    { code: 'en', name: 'Ingles', level: 'B2' },
  ],

  /**
   * Certificaciones DESTACADAS.
   *
   * El listado completo y verificable vive en la base de datos y se pinta en
   * /#certificaciones. Estas son las de mas peso, y estan aqui porque las
   * necesitan dos consumidores que no pueden leer la base de datos al compilar:
   * el bloque hasCredential de Schema.org y el resumen de /llms.txt.
   *
   * Manten la lista CORTA. Su valor es decir "esto es lo importante"; si crece
   * hasta replicar la tabla entera, deja de responder a esa pregunta.
   */
  credentials: [
    { name: 'Fortinet NSE', issuer: 'Fortinet', year: '2026' },
    { name: 'Microsoft Certified: Azure AI Fundamentals', issuer: 'Microsoft', year: '2026' },
    {
      name: 'Trend Micro Vision One Platform — Advanced',
      issuer: 'Trend Micro',
      year: '2024',
    },
    { name: 'TryHackMe Pre-Security', issuer: 'TryHackMe', year: '2023' },
    {
      name: 'Fundamentos profesionales en ciberseguridad',
      issuer: 'Microsoft / LinkedIn',
      year: '2023',
    },
    { name: 'First Certificate in English (B2)', issuer: 'Cambridge English', year: '2021' },
  ],

  /** Reconocimientos. Alimentan la propiedad `award` de Schema.org. */
  awards: [
    {
      name: 'Ganador de la 8a Hackathon TecnoCampus',
      year: '2025',
      description:
        'Primer premio con Dewi, un prototipo web para monitorizar el consumo de agua en tiempo real.',
    },
  ],

  // Foto de perfil y CV (colocados en /public, se sirven desde la raiz).
  avatar: '/img/eduardo.webp',
  // Portada para redes (1200x630). Se genera un placeholder con `npm run icons`
  // (og-cover.png). Sustituyelo por uno con tu foto/nombre cuando lo tengas.
  ogImage: '/img/og-cover.png',
  cv: {
    es: '/cv/CV-Eduardo-Olivares-ES.pdf',
    en: '/cv/CV-Eduardo-Olivares-EN.pdf',
    ca: '/cv/CV-Eduardo-Olivares-CA.pdf',
  },

  // Tarjeta de contacto descargable (vCard). Se genera en /public.
  vcard: '/eduardo-olivares.vcf',

  // Enlaces sociales.
  social: {
    linkedin: 'https://www.linkedin.com/in/eduolihez/',
    github: 'https://github.com/eduolihez',
    email: 'eduardo@eduolihez.com',
  },

  // Repositorio de ESTA web (distinto del perfil de github.eduolihez de
  // arriba). Enlazado desde la cabecera: la web es la demostracion, el
  // repositorio es la prueba (ver PRODUCT.md, seccion Positioning).
  githubRepo: 'https://github.com/eduolihez/eduolihez.com',

  /**
   * Base del backend PHP en CDMON.
   * - En LOCAL (npm run dev) no hay PHP, asi que las llamadas fallaran de forma
   *   controlada (las secciones muestran su mensaje de error). Es normal.
   * - En PRODUCCION las rutas /api/*.php estaran junto al sitio, por eso
   *   dejamos la base vacia => se usan rutas relativas ("/api/projects.php").
   *
   * Si algun dia sirves el backend desde otro subdominio, pon aqui la URL
   * completa, p.ej. 'https://api.eduolihez.com'.
   */
  apiBase: '',

  // Endpoint de respaldo Formspree (red de seguridad del formulario).
  formspree: 'https://formspree.io/f/mnnebybn',

  // Cloudflare Turnstile (captcha invisible del formulario). OPCIONAL.
  // Deja '' para desactivarlo. Si lo activas, pon aqui la CLAVE PUBLICA y la
  // secreta en server/config.php. Ademas anade challenges.cloudflare.com a la
  // CSP del .htaccess. Ver CLOUDFLARE.md.
  turnstileSiteKey: '',
} as const;

/** Construye la URL de un endpoint del API PHP. */
export function api(path: string): string {
  const base = SITE.apiBase.replace(/\/$/, '');
  const clean = path.startsWith('/') ? path : `/${path}`;
  return `${base}${clean}`;
}
