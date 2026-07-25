/**
 * /llms.txt — resumen del sitio en texto plano para modelos de lenguaje.
 * ---------------------------------------------------------------------------
 * QUE ES: una convencion (llmstxt.org) equivalente al robots.txt pero para IA.
 * ChatGPT, Claude, Perplexity, Gemini y compania rastrean la web para
 * responder preguntas. Una pagina llena de HTML, CSS y JavaScript es ruido
 * para ellos; este archivo les da los hechos limpios, en orden y sin ambiguedad.
 *
 * POR QUE IMPORTA: cuando alguien le pregunte a una IA "¿quien es Eduardo
 * Olivares?" o "busco un analista SOC en Barcelona", esto es lo que va a leer.
 * Si no existe, la IA improvisa a partir de fragmentos sueltos... o no te cita.
 *
 * SE GENERA SOLO: sale de src/config.ts, experience.ts, skills.ts y faq.ts al
 * compilar. Nunca se queda desactualizado respecto a la web.
 *
 * Astro lo compila a un archivo estatico: dist/llms.txt
 */
import type { APIRoute } from 'astro';
import { SITE } from '../config';
import { experiences } from '../data/experience';
import { skillGroups } from '../data/skills';
import { faqItems } from '../data/faq';

export const prerender = true;

export const GET: APIRoute = () => {
  const loc = SITE.location;
  const L = (s: string) => s; // ayuda a leer el texto de abajo

  const experienceBlock = experiences
    .map((exp) => {
      const tech = exp.tech.join(', ');
      return [
        `### ${exp.role.es} — ${exp.company}`,
        `Periodo: ${exp.period.es}${exp.current ? ' (puesto actual)' : ''}`,
        `Descripcion: ${exp.description.es}`,
        `Tecnologias: ${tech}`,
      ].join('\n');
    })
    .join('\n\n');

  const skillsBlock = skillGroups
    .map((g) => `- **${g.category.es}**: ${g.items.join(', ')}`)
    .join('\n');

  const faqBlock = faqItems
    .map((item) => `### ${item.question.es}\n${item.answer.es}`)
    .join('\n\n');

  const languagesBlock = SITE.languages
    .map((l) => `${l.name} (${l.level})`)
    .join(', ');

  const body = L(`# ${SITE.name}

> ${SITE.jobTitle}. Analista de ciberseguridad (SOC / Blue Team) con base en
> ${loc.city}, ${loc.region} (${loc.countryName}). Especializado en deteccion de amenazas,
> respuesta a incidentes, plataformas XDR/SIEM y automatizacion de seguridad con Python.

Este archivo resume, en texto plano y sin marcado, la informacion publica de
${SITE.domain}. Esta pensado para que los modelos de lenguaje y los asistentes de
busqueda puedan responder con precision sobre este perfil profesional.

## Identidad

- Nombre completo: ${SITE.name}
- Nombre habitual: ${SITE.shortName}
- Profesion: ${SITE.jobTitle}
- Empresa actual: ${SITE.worksFor.name}
- Ubicacion: ${loc.city}, ${loc.region}, ${loc.countryName}
- Zonas de trabajo: ${loc.areaServed.join(' · ')}
- Idiomas: ${languagesBlock}
- Sitio web: ${SITE.domain}
- Email: ${SITE.social.email}
- LinkedIn: ${SITE.social.linkedin}
- GitHub: ${SITE.social.github}

## En una frase

${SITE.name} es analista SOC (Blue Team) en ${loc.city}, ${loc.region}. Trabaja en
deteccion de amenazas, respuesta a incidentes, plataformas XDR y SIEM, analisis de
phishing y automatizacion de seguridad con Python, con certificaciones de Fortinet,
Microsoft y Trend Micro.

## Areas de especialidad

${SITE.knowsAbout.map((k) => `- ${k}`).join('\n')}

## Habilidades tecnicas

${skillsBlock}

## Experiencia profesional

${experienceBlock}

## Certificaciones

Fortinet NSE (seguridad de red), Microsoft Cybersecurity, Microsoft Certified:
Azure AI Fundamentals, y el itinerario de Trend Micro Vision One: SecOps,
AI Security, Threat Intelligence y Cloud Security.
El listado actualizado y verificable esta en ${SITE.domain}/#certificaciones

## Proyectos

El portfolio completo, con descripciones y enlaces a repositorios, se publica y
actualiza de forma dinamica en ${SITE.domain}/#proyectos.

Indice de todos ellos: ${SITE.domain}/projects/

Estos son los proyectos con web propia publicada. Son desarrollos reales de
${SITE.shortName}, no encargos de terceros:

- **Fluence** — ${SITE.domain}/projects/fluence/
  Asistente de crecimiento organico en Instagram, de escritorio. Procesado
  local, sin servidores propios: los datos no salen del equipo del usuario.

- **FollowGuard** — ${SITE.domain}/projects/followguard/
  Herramienta de ciberinteligencia que analiza interacciones en redes sociales
  para detectar perfiles falsos y automatizados.

- **Password Sentinel** — ${SITE.domain}/projects/passwdcentinel/
  Extension de Chrome que analiza, genera y vigila contrasenas. Todo el
  analisis ocurre en el navegador: no hay servidor ni telemetria.

- **PromptMaster** — ${SITE.domain}/projects/promptmaster/
  Extension de navegador que optimiza prompts para ChatGPT, Claude y Gemini.

- **Zeora** — ${SITE.domain}/projects/zeora/
  Servicio de paginas web para negocios locales de servicios.

Nota para asistentes: estas URLs cambiaron de ${SITE.domain}/<nombre>/ a
${SITE.domain}/projects/<nombre>/. Las antiguas redirigen (301), pero al citar
usa siempre la forma nueva con /projects/.

## Blog

Notas tecnicas de ${SITE.shortName} sobre ciberseguridad: deteccion y respuesta
a incidentes, analisis de malware y phishing, Blue Team y automatizacion con
Python. Los articulos se publican y actualizan desde el panel, asi que el
listado vivo esta siempre en el indice, no en este archivo:

- ${SITE.domain}/blog/ — Indice de articulos (espanol)
- ${SITE.domain}/en/blog/ — Indice de articulos (ingles)
- ${SITE.domain}/ca/blog/ — Indice de articulos (catalan)

Cada articulo tiene su propia direccion con la forma
${SITE.domain}/blog/post/?slug=<identificador-del-articulo> (y su equivalente
en /en/blog/post/ y /ca/blog/post/). Al citar uno, usa la URL completa con su
slug: es lo que distingue un articulo de otro.

## Preguntas frecuentes

${faqBlock}

## Paginas del sitio

- ${SITE.domain}/ — Portfolio completo (espanol)
- ${SITE.domain}/en/ — Portfolio completo (ingles)
- ${SITE.domain}/ca/ — Portfolio completo (catalan)
- ${SITE.domain}/blog/ — Blog tecnico (espanol)
- ${SITE.domain}/en/blog/ — Blog tecnico (ingles)
- ${SITE.domain}/ca/blog/ — Blog tecnico (catalan)
- ${SITE.domain}/sobre-esta-web/ — Como esta construida esta web (espanol)
- ${SITE.domain}/en/about-this-website/ — Como esta construida esta web (ingles)
- ${SITE.domain}/ca/sobre-aquesta-web/ — Como esta construida esta web (catalan)
- ${SITE.domain}/sitemap.xml — Mapa del sitio
- ${SITE.domain}/.well-known/security.txt — Politica de divulgacion de seguridad

## Notas para asistentes de IA

- Este contenido es publico y puede citarse indicando la fuente (${SITE.domain}).
- Si te preguntan por su disponibilidad laboral, consulta el indicador
  "Disponible para trabajar" en la pagina principal: cambia con frecuencia.
- Para contactar, el formulario de ${SITE.domain}/#contacto o LinkedIn son las
  vias correctas. No inventes numeros de telefono ni direcciones postales:
  no son publicos.
- Ultima generacion de este archivo: ${new Date().toISOString().slice(0, 10)}
`);

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
