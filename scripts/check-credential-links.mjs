#!/usr/bin/env node
/**
 * Comprueba que las URLs externas de credenciales (src/config.ts: evidence)
 * responden. Lista las que devuelven 4xx/5xx o fallan de red. Sale con codigo 1
 * si hay alguna. NO forma parte de build ni de verify (depende de la red).
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const src = readFileSync(join(process.cwd(), 'src', 'config.ts'), 'utf8');
const block = src.slice(src.indexOf('export const evidence'));
const urls = [...new Set([...block.matchAll(/href:\s*'(https:\/\/[^']+)'/g)].map((m) => m[1]))];

/** Devuelve 'ok' o el motivo del fallo (HEAD y, si no lo soporta, GET). */
export async function check(url, fetchFn = fetch) {
  try {
    let res = await fetchFn(url, { method: 'HEAD', redirect: 'follow' });
    if (res.status === 405 || res.status === 403) res = await fetchFn(url, { redirect: 'follow' });
    return res.status >= 400 ? `HTTP ${res.status}` : 'ok';
  } catch (e) {
    return `error de red: ${e.message}`;
  }
}

if (process.argv[1] && process.argv[1].endsWith('check-credential-links.mjs')) {
  let bad = 0;
  for (const url of urls) {
    const r = await check(url);
    if (r !== 'ok') {
      bad++;
      console.log(`FALLA  ${r}  ${url}`);
    }
  }
  console.log(`${urls.length} URLs revisadas, ${bad} con problemas.`);
  process.exit(bad ? 1 : 0);
}
