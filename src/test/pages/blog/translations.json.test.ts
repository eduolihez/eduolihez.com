import { describe, expect, it } from 'vitest';
import type { APIContext } from 'astro';
import { GET } from '../../../pages/blog/translations.json';
import { POST_TRANSLATIONS_CA } from '../../../lib/postTranslations';

// Lo lee server/lib/sitemap.php para poner los hreflang de /sitemap-posts.xml.
// Si este archivo cambia de forma, el sitemap se queda sin alternos en silencio.

describe('GET /blog/translations.json', () => {
  it('publica el mapa slug ES -> slug CA tal cual', async () => {
    const response = GET({} as APIContext);
    expect(response.headers.get('Content-Type')).toBe('application/json; charset=utf-8');
    expect(await response.json()).toEqual(POST_TRANSLATIONS_CA);
  });
});
