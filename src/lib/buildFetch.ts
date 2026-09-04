/**
 * buildFetch.ts - fetch() JSON en build-time con reintentos, fallo suave.
 * ---------------------------------------------------------------------------
 * La API en produccion responde 500 de forma intermitente a peticiones hechas
 * con fetch() de Node (no con curl, no con el navegador) -- muy probablemente
 * el mismo Cloudflare Bot Management que la auditoria GEO encontro
 * sobreescribiendo el robots.txt propio del sitio, puntuando distinto a un
 * cliente HTTP sin huella de navegador. src/lib/posts.ts ya resolvia esto
 * para el blog (ahi con fallo DURO tras 3 intentos, porque sin esos datos la
 * pagina del articulo no existiria). src/lib/projects.ts y
 * src/lib/certifications.ts necesitan el mismo reintento pero con fallo
 * SUAVE: solo rellenan el primer pintado de una seccion que igualmente
 * reconstruye el cliente, asi que un array vacio tras agotar reintentos es
 * aceptable -- lo que no lo es, es no reintentar y perder el primer pintado
 * por un 500 puntual que un segundo intento habria resuelto.
 */
export async function fetchJsonSoft<T>(url: string, attempts = 3): Promise<T> {
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': 'eduolihez.com-build/1.0' } });
      if (res.ok) return (await res.json()) as T;
    } catch {
      // sigue al reintento
    }
    if (attempt < attempts) await new Promise((r) => setTimeout(r, attempt * 1000));
  }
  return [] as T;
}
