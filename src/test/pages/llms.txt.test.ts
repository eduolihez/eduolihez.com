import { describe, it, expect } from 'vitest';
import { GET } from '../../pages/llms.txt';
import { SITE } from '../../config';
import type { APIContext } from 'astro';

// Smoke test para el endpoint que alimenta a las IAs (ver comentario de
// llms.txt.ts). No mockeamos config/experience/skills/faq a proposito: el
// riesgo real es que un cambio en esos archivos rompa el texto generado sin
// que nadie lo note hasta que una IA reciba una respuesta rota o vacia.
//
// IMPORTANTE: este archivo vive fuera de src/pages/ a proposito. Astro trata
// CUALQUIER archivo dentro de src/pages/ como una ruta a compilar; un
// describe()/it() de Vitest ahi dentro rompe `npm run build` porque Astro
// intenta evaluar el modulo como si fuera un endpoint.

describe('GET /llms.txt', () => {
  it('responde texto plano con cache publica', async () => {
    const response = GET({} as APIContext);
    expect(response).toBeInstanceOf(Response);
    expect(response.headers.get('Content-Type')).toBe('text/plain; charset=utf-8');
    expect(response.headers.get('Cache-Control')).toContain('public');
  });

  it('incluye la identidad real desde config.ts', async () => {
    const response = GET({} as APIContext);
    const body = await response.text();

    expect(body).toContain(SITE.name);
    expect(body).toContain(SITE.domain);
    expect(body).toContain(SITE.jobTitle);
    expect(body).toContain(SITE.social.linkedin);
  });

  it('no deja huecos de plantilla sin rellenar', async () => {
    const response = GET({} as APIContext);
    const body = await response.text();

    // Si un campo cambia de forma en config/experience/skills/faq y deja de
    // existir, la interpolacion de la plantilla lo convierte en uno de estos
    // dos textos en vez de fallar de forma ruidosa -- por eso se comprueban
    // explicitamente en vez de confiar en que un test unitario los detecte.
    expect(body).not.toContain('undefined');
    expect(body).not.toContain('[object Object]');
  });

  it('genera al menos una entrada de experiencia y una de FAQ', async () => {
    const response = GET({} as APIContext);
    const body = await response.text();

    expect(body).toMatch(/## Experiencia profesional\n+### .+/);
    expect(body).toMatch(/## Preguntas frecuentes\n+### .+/);
  });

  it('enlaza las fuentes de blog para rastreadores sin JavaScript', async () => {
    // Regresion: la seccion "Paginas del sitio" antes solo apuntaba a
    // sitemap.xml. Ahora tambien debe listar /llms-blog.txt (texto integro
    // de los articulos) y /sitemap-posts.xml (indice de posts), porque el
    // listado del blog se pinta con JavaScript y un rastreador que no lo
    // ejecute veria esas rutas vacias sin estos dos punteros.
    const response = GET({} as APIContext);
    const body = await response.text();

    expect(body).toContain(`${SITE.domain}/llms-blog.txt`);
    expect(body).toContain(`${SITE.domain}/sitemap-posts.xml`);
  });
});
