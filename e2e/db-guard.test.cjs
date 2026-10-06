// Tests unitarios de la guarda (node --test db-guard.test.cjs).
const test = require('node:test');
const assert = require('node:assert/strict');
const { checkDbConfig } = require('./db-guard.cjs');

const cfg = (name, host = 'localhost', extra = '') =>
  `<?php\nreturn [\n${extra}    'db' => [\n        'host' => '${host}',\n        'name' => '${name}',\n        'user' => 'x',\n        'pass' => 'p]w//d',\n    ],\n    'mail' => ['enabled' => false],\n];\n`;

test('acepta eduolihez_test en localhost y 127.0.0.1', () => {
  assert.equal(checkDbConfig(cfg('eduolihez_test')).ok, true);
  assert.equal(checkDbConfig(cfg('eduolihez_test', '127.0.0.1')).ok, true);
});
test('rechaza nombres sin _test', () => {
  assert.equal(checkDbConfig(cfg('portfolio')).ok, false);
  assert.equal(checkDbConfig(cfg('1234567_portfolio')).ok, false);
  assert.equal(checkDbConfig(cfg('x_test_prod')).ok, false);
});
test('rechaza hosts remotos', () => {
  assert.equal(checkDbConfig(cfg('eduolihez_test', 'db.example.com')).ok, false);
  assert.equal(checkDbConfig(cfg('eduolihez_test', '10.0.0.5')).ok, false);
});
test('los comentarios no engañan', () => {
  const lineComment = cfg('portfolio').replace("'name'", "// 'name' => 'x_test',\n        'name'");
  assert.equal(checkDbConfig(lineComment).ok, false);
  const hash = cfg('portfolio').replace("'name'", "# 'name' => 'x_test',\n        'name'");
  assert.equal(checkDbConfig(hash).ok, false);
  const block = cfg('portfolio').replace("'name'", "/* 'name' => 'x_test', */ 'name'");
  assert.equal(checkDbConfig(block).ok, false);
  const hostComment = cfg('eduolihez_test', 'db.example.com').replace("'host'", "// 'host' => 'localhost',\n        'host'");
  assert.equal(checkDbConfig(hostComment).ok, false);
  // un bloque 'db' comentado entero no cuenta
  assert.equal(checkDbConfig("<?php\n// 'db' => ['host'=>'localhost','name'=>'a_test'],\nreturn [];").ok, false);
});
test('una cadena con // dentro no se toma por comentario', () => {
  const r = checkDbConfig(cfg('eduolihez_test', 'localhost', "    'site' => 'https://x.es/a',\n"));
  assert.equal(r.ok, true);
});
test('un name en otro bloque no vale', () => {
  const t = "<?php return ['mail' => ['name' => 'a_test'], 'db' => ['host' => 'localhost', 'name' => 'prod']];";
  assert.equal(checkDbConfig(t).ok, false);
});
test('bloque ausente, vacio o sin cerrar se rechaza', () => {
  assert.equal(checkDbConfig('<?php return [];').ok, false);
  assert.equal(checkDbConfig('').ok, false);
  assert.equal(checkDbConfig("<?php return ['db' => ['host' => 'localhost', 'name' => 'a_test'").ok, false);
  assert.equal(checkDbConfig("<?php return ['db' => ['host' => 'localhost']];").ok, false);
  assert.equal(checkDbConfig("<?php return ['db' => ['name' => 'a_test']];").ok, false);
  assert.equal(checkDbConfig("<?php return ['db' => ['host' => 'localhost', 'name' => getenv('X')]];").ok, false);
});
test('comillas dobles y array() tambien', () => {
  assert.equal(checkDbConfig('<?php return ["db" => array("host" => "localhost", "name" => "a_test")];').ok, true);
});
