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

El portfolio de proyectos se publica y actualiza de forma dinamica en
${SITE.domain}/#proyectos (incluye herramientas de seguridad, extensiones de
navegador y proyectos de machine learning aplicado a la deteccion de phishing).

## Preguntas frecuentes

${faqBlock}

## Paginas del sitio

- ${SITE.domain}/ — Portfolio completo (espanol)
- ${SITE.domain}/en/ — Portfolio completo (ingles)
- ${SITE.domain}/ca/ — Portfolio completo (catalan)
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
