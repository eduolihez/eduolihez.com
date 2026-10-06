// @ts-check
/**
 * globalSetup de Playwright: aborta TODA la ejecucion si server/config.php
 * (la BD que usa el servidor PHP al que hablan los tests) no es una base de
 * datos de test local. Ver db-guard.cjs.
 */
const fs = require('node:fs');
const path = require('node:path');
const { checkDbConfig } = require('./db-guard.cjs');

module.exports = async () => {
  const file = path.join(__dirname, '..', 'server', 'config.php');
  let text;
  try {
    text = fs.readFileSync(file, 'utf8');
  } catch {
    throw new Error(
      'E2E ABORTADO: no se pudo leer server/config.php. Crealo apuntando a una base de datos de test ' +
        '(nombre acabado en "_test", host localhost/127.0.0.1): estos tests crean y borran datos.'
    );
  }
  const r = checkDbConfig(text);
  if (!r.ok) {
    throw new Error(
      `E2E ABORTADO: server/config.php no es seguro para esta suite: ${r.error}. ` +
        'Los tests crean y borran datos en la BD que usa el servidor PHP: solo se permite una BD ' +
        'cuyo nombre acabe en "_test" y un host localhost o 127.0.0.1.'
    );
  }
  console.log(`[e2e] BD de server/config.php: ${r.name}@${r.host} (OK)`);
};
