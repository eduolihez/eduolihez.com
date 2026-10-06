// @ts-check
/**
 * Guarda de seguridad de la suite E2E: la BD que de verdad modifican los
 * tests es la de server/config.php (la lee el servidor PHP al que hablan), no
 * la del seed. Aqui se lee ese fichero COMO TEXTO (sin ejecutar PHP) y se
 * exige que la BD sea de test y local.
 */

/**
 * Quita comentarios PHP (//, #, bloques) respetando las cadenas '...' y "...".
 * @param {string} src
 * @returns {string}
 */
function stripPhpComments(src) {
  let out = '';
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    const n = src[i + 1];
    if (c === "'" || c === '"') {
      let j = i + 1;
      while (j < src.length && src[j] !== c) j += src[j] === '\\' ? 2 : 1;
      out += src.slice(i, j + 1);
      i = j + 1;
    } else if ((c === '/' && n === '/') || (c === '#' && n !== '[')) {
      while (i < src.length && src[i] !== '\n') i++;
    } else if (c === '/' && n === '*') {
      const end = src.indexOf('*/', i + 2);
      i = end === -1 ? src.length : end + 2;
      out += ' ';
    } else {
      out += c;
      i++;
    }
  }
  return out;
}

/**
 * Devuelve el contenido del array 'db' => [ ... ] (o array( ... )), con
 * corchetes anidados y cadenas respetados; null si no existe o no cierra.
 * @param {string} code texto sin comentarios
 * @returns {string | null}
 */
function extractDbBlock(code) {
  const m = /['"]db['"]\s*=>\s*(\[|array\s*\()/i.exec(code);
  if (!m) return null;
  let depth = 1;
  let i = m.index + m[0].length;
  const start = i;
  while (i < code.length) {
    const c = code[i];
    if (c === "'" || c === '"') {
      let j = i + 1;
      while (j < code.length && code[j] !== c) j += code[j] === '\\' ? 2 : 1;
      i = j + 1;
      continue;
    }
    if (c === '[' || c === '(') depth++;
    else if (c === ']' || c === ')') depth--;
    if (depth === 0) return code.slice(start, i);
    i++;
  }
  return null;
}

/**
 * @param {string} block
 * @param {string} key
 * @returns {string | null} ultimo valor literal de la clave (como PHP)
 */
function stringValue(block, key) {
  const re = new RegExp(`['"]${key}['"]\\s*=>\\s*(?:'([^']*)'|"([^"$]*)")`, 'g');
  /** @type {string | null} */
  let last = null;
  for (const m of block.matchAll(re)) last = m[1] !== undefined ? m[1] : m[2];
  return last;
}

/**
 * Valida el texto de server/config.php.
 * @param {string} text
 * @returns {{ ok: true, name: string, host: string } | { ok: false, error: string }}
 */
function checkDbConfig(text) {
  const block = extractDbBlock(stripPhpComments(String(text)));
  if (block === null) return { ok: false, error: "no se encontro el bloque 'db' => [...]" };
  const name = stringValue(block, 'name');
  const host = stringValue(block, 'host');
  if (!name) return { ok: false, error: "el bloque 'db' no tiene un 'name' literal" };
  if (!host) return { ok: false, error: "el bloque 'db' no tiene un 'host' literal" };
  if (!name.endsWith('_test')) {
    return { ok: false, error: `la base de datos "${name}" no termina en "_test"` };
  }
  if (!['localhost', '127.0.0.1'].includes(host)) {
    return { ok: false, error: `el host de la base de datos "${host}" no es local (solo localhost o 127.0.0.1)` };
  }
  return { ok: true, name, host };
}

module.exports = { checkDbConfig, stripPhpComments, extractDbBlock };
