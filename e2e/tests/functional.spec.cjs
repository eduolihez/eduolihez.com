// (g) Humo funcional contra la BD de test: cada test crea lo suyo con un
// nombre unico (prefijo "E2E " para que seed/seed.php limpie restos si un
// test falla a medias) y lo borra al terminar por la propia interfaz.
const { test, expect } = require('@playwright/test');
const { acceptNextDialog, followLink, stamp } = require('./helpers.cjs');

test('proyecto: crear, editar y borrar', async ({ page }) => {
  const title = `E2E Proyecto ${stamp()}`;
  await page.goto('/admin/project-edit.php');
  await page.locator('#title_es').fill(title);
  await page.locator('#summary_es').fill('Resumen creado por la suite E2E.');
  await page.locator('#stack').fill('PHP, Playwright');
  await page.getByRole('button', { name: 'Crear proyecto' }).click();

  await expect(page).toHaveURL(/\/admin\/projects\.php$/);
  await expect(page.locator('.flash.ok')).toHaveText('Proyecto creado.');
  const row = page.locator('tbody tr', { hasText: title });
  await expect(row).toHaveCount(1);

  await row.getByRole('link', { name: 'Editar' }).click();
  await expect(page).toHaveURL(/\/admin\/project-edit\.php\?id=\d+$/);
  await expect(page.locator('#title_es')).toHaveValue(title);
  await expect(page.locator('#stack')).toHaveValue('PHP, Playwright');
  const edited = `${title} editado`;
  await page.locator('#title_es').fill(edited);
  await page.getByRole('button', { name: 'Guardar cambios' }).click();
  await expect(page.locator('.flash.ok')).toHaveText('Proyecto actualizado.');
  const editedRow = page.locator('tbody tr', { hasText: edited });
  await expect(editedRow).toHaveCount(1);

  const dialog = acceptNextDialog(page);
  await editedRow.getByRole('button', { name: 'Borrar' }).click();
  expect(await dialog).toContain('Eliminar este proyecto');
  await expect(page.locator('.flash.ok')).toHaveText('Proyecto eliminado.');
  await expect(page.locator('tbody tr', { hasText: title })).toHaveCount(0);
});

test('proyecto: cancelar el confirm no borra nada', async ({ page }) => {
  const title = `E2E Cancelar ${stamp()}`;
  await page.goto('/admin/project-edit.php');
  await page.locator('#title_es').fill(title);
  await page.locator('#summary_es').fill('No se debe borrar al cancelar.');
  await page.getByRole('button', { name: 'Crear proyecto' }).click();
  const row = page.locator('tbody tr', { hasText: title });
  await expect(row).toHaveCount(1);

  page.once('dialog', (d) => d.dismiss());
  await row.getByRole('button', { name: 'Borrar' }).click();
  await page.waitForTimeout(300);
  await page.reload();
  await expect(row).toHaveCount(1);

  const dialog = acceptNextDialog(page);
  await row.getByRole('button', { name: 'Borrar' }).click();
  await dialog;
  await expect(page.locator('tbody tr', { hasText: title })).toHaveCount(0);
});

test('articulo: slug automatico al crear, manual despues, intacto al editar; y borrado', async ({ page }) => {
  const id = stamp();
  const title = `E2E Árbol de pruebas ${id}`;
  await page.goto('/admin/post-edit.php');
  const titleIn = page.locator('#title');
  const slugIn = page.locator('#slug');

  // Se genera mientras se escribe (evento input), sin acentos ni mayusculas.
  await titleIn.pressSequentially(title);
  await expect(slugIn).toHaveValue(`e2e-arbol-de-pruebas-${id}`);

  // En cuanto el slug se toca a mano deja de seguir al titulo.
  await slugIn.fill(`e2e-manual-${id}`);
  await titleIn.press('End'); // al enfocar, el cursor no siempre queda al final
  await titleIn.pressSequentially(' bis');
  await expect(titleIn).toHaveValue(`${title} bis`);
  await expect(slugIn).toHaveValue(`e2e-manual-${id}`);

  await page.locator('#summary').fill('Resumen E2E.');
  await page.locator('#content').fill('<p>Contenido E2E.</p>');
  await page.locator('#visible').uncheck();
  await page.getByRole('button', { name: 'Guardar artículo' }).click();
  await expect(page).toHaveURL(/\/admin\/posts\.php$/);
  await expect(page.locator('.flash.ok')).toContainText('creado');

  const row = page.locator('tbody tr', { hasText: `${title} bis` });
  await expect(row).toHaveCount(1);
  await expect(row).toContainText(`/blog/e2e-manual-${id}`);

  // Editar: el slug ya no se autogenera al cambiar el titulo.
  await row.locator(`a[href^="post-edit.php?id="]`).first().click();
  await expect(slugIn).toHaveValue(`e2e-manual-${id}`);
  await expect(slugIn).not.toHaveAttribute('data-slug-auto', /.*/);
  await titleIn.press('End');
  await titleIn.pressSequentially(' cambiado');
  await expect(titleIn).toHaveValue(`${title} bis cambiado`);
  await expect(slugIn).toHaveValue(`e2e-manual-${id}`);
  await page.getByRole('link', { name: 'Volver al listado' }).click();

  const dialog = acceptNextDialog(page);
  await page.locator('tbody tr', { hasText: `${title} bis` }).getByRole('button', { name: 'Eliminar' }).click();
  expect(await dialog).toContain('eliminar este artículo');
  await expect(page.locator('.flash.ok')).toContainText('eliminado');
  await expect(page.locator('tbody tr', { hasText: title })).toHaveCount(0);
});

test('PhishLab: crear usuario, desactivar/activar, ver cambio de contrasena y borrar', async ({ page }) => {
  const username = `e2e-lab-${stamp()}`;
  await page.goto('/admin/lab-users.php?space=phishlab');

  // Validacion del servidor: contrasena corta (se quita minlength para que
  // la peticion llegue y se compruebe el lado PHP).
  await page.locator('#username').fill(username);
  await page.locator('#password').evaluate((el) => el.removeAttribute('minlength'));
  await page.locator('#password').fill('corta');
  await page.getByRole('button', { name: 'Crear usuario' }).click();
  await expect(page.locator('.flash.err')).toContainText('al menos 12');
  await expect(page.locator('tbody tr', { hasText: username })).toHaveCount(0);

  await page.locator('#username').fill(username);
  await page.locator('#password').fill('una-contrasena-larga-E2E');
  await page.getByRole('button', { name: 'Crear usuario' }).click();
  await expect(page.locator('.flash.ok')).toContainText(`"${username}" creado`);
  const row = page.locator('tbody tr', { hasText: username });
  await expect(row.locator('.pill').first()).toHaveText('Activa');

  await row.getByRole('button', { name: 'Desactivar', exact: true }).click();
  await expect(page.locator('.flash.ok')).toHaveText('Usuario desactivado.');
  await expect(row.locator('.pill').first()).toHaveText('Desactivada');
  await row.getByRole('button', { name: 'Activar', exact: true }).click();
  await expect(page.locator('.flash.ok')).toHaveText('Usuario activado.');
  await expect(row.locator('.pill').first()).toHaveText('Activa');

  // "Cambiar contrasena" despliega el formulario (sin JS en linea: CSP).
  const pwForm = row.locator('form[id^="pw-"]');
  await expect(pwForm).toBeHidden();
  await row.getByRole('button', { name: 'Cambiar contraseña' }).click();
  await expect(pwForm).toBeVisible();

  const dialog = acceptNextDialog(page);
  await row.getByRole('button', { name: 'Borrar' }).click();
  expect(await dialog).toContain(username);
  await expect(page.locator('.flash.ok')).toHaveText('Usuario eliminado.');
  await expect(page.locator('tbody tr', { hasText: username })).toHaveCount(0);
});

test('mensajes: abrir marca como leido, archivar, desarchivar y volver a no leido', async ({ page }) => {
  const subject = 'E2E sin leer 1';
  await page.goto('/admin/messages.php?space=site&f=inbox');
  let row = page.locator('tbody tr', { hasText: subject });
  await expect(row).toHaveCount(1);
  await expect(row.locator('.pill.on')).toHaveText('Nuevo');

  await row.getByRole('link', { name: subject }).click();
  await expect(page).toHaveURL(/\/admin\/messages\.php\?id=\d+$/);
  await expect(page.locator('main')).toContainText('Primer mensaje de prueba.');

  await page.getByRole('button', { name: 'Archivar' }).click();
  await expect(page.locator('.flash.ok')).toContainText('archivados');
  await expect(page.locator('tbody tr', { hasText: subject })).toHaveCount(0);

  await page.locator('.tabs a', { hasText: 'Archivados' }).click();
  row = page.locator('tbody tr', { hasText: subject });
  await expect(row).toHaveCount(1);
  await expect(row.locator('.pill.on')).toHaveCount(0); // ya leido

  await row.getByRole('link', { name: subject }).click();
  await page.getByRole('button', { name: 'Desarchivar' }).click();
  await expect(page.locator('.flash.ok')).toContainText('devueltos a la bandeja');
  await page.getByRole('button', { name: 'Marcar como no leido' }).click();
  await expect(page).toHaveURL(/\/admin\/messages\.php\?f=inbox$/);
  await expect(page.locator('tbody tr', { hasText: subject }).locator('.pill.on')).toHaveText('Nuevo');
});

test('mensajes: accion en lote "Leido" y vuelta a "No leido"', async ({ page }) => {
  const subject = 'E2E sin leer 2';
  await page.goto('/admin/messages.php?space=site');
  const row = page.locator('tbody tr', { hasText: subject });
  await row.locator('.row-check').check();
  await page.getByRole('button', { name: 'Leido', exact: true }).click();
  await expect(page.locator('.flash.ok')).toContainText('1 mensaje(s) marcados como leidos');
  await expect(row.locator('.pill.on')).toHaveCount(0);
  await row.locator('.row-check').check();
  await page.getByRole('button', { name: 'No leido', exact: true }).click();
  await expect(row.locator('.pill.on')).toHaveText('Nuevo');
});

test('analitica: enlaces de rango y CSV', async ({ page }) => {
  await page.goto('/admin/analytics.php?space=site');
  await expect(page.locator('h1')).toContainText('eduolihez.com');
  const ranges = page.locator('.page-actions a.btn', { hasText: /^(24 h|\d+d)$/ });
  await expect(ranges).toHaveText(['24 h', '7d', '14d', '30d', '90d', '365d']);

  await followLink(page, page.locator('.page-actions a', { hasText: /^7d$/ }));
  await expect(page).toHaveURL(/\?days=7&space=site$/);
  await expect(page.locator('.page-actions a', { hasText: /^7d$/ })).not.toHaveClass(/ghost/);
  await expect(page.locator('.page-actions a', { hasText: /^30d$/ })).toHaveClass(/ghost/);
  await expect(page.locator('.card.stat .lbl').first()).toContainText('Visitas (7 dias)');
  // El seed mete visitas de los ultimos 6 dias para eduolihez.
  const visits = Number((await page.locator('.card.stat .num').first().innerText()).replace(/\D.*$/s, '').replace(/[.,]/g, ''));
  expect(visits).toBeGreaterThan(0);

  // Un rango fuera de la lista blanca cae en 30.
  await page.goto('/admin/analytics.php?days=9999&space=site');
  await expect(page.locator('.card.stat .lbl').first()).toContainText('Visitas (30 dias)');

  const csvHref = await page.locator('.page-actions a', { hasText: 'Exportar CSV' }).getAttribute('href');
  expect(csvHref).toContain('export=csv');
  const resp = await page.request.get(new URL(csvHref, page.url()).toString());
  expect(resp.status()).toBe(200);
  expect(resp.headers()['content-type']).toMatch(/^text\/csv/);
  expect(resp.headers()['content-disposition']).toMatch(/attachment; filename="visitas-30d-/);
  const lines = (await resp.text()).replace(/^﻿/, '').trim().split(/\r?\n/);
  expect(lines[0]).toMatch(/^Fecha,Pagina,Idioma,Referrer/);
  expect(lines.length).toBeGreaterThan(1);
});

test('mensajes: CSV con cabecera', async ({ page }) => {
  const resp = await page.request.get('/admin/messages.php?f=all&export=csv');
  expect(resp.status()).toBe(200);
  expect(resp.headers()['content-type']).toMatch(/^text\/csv/);
  const lines = (await resp.text()).replace(/^﻿/, '').trim().split(/\r?\n/);
  expect(lines[0]).toBe('ID,Nombre,Email,Asunto,Mensaje,IP,Leido,Destacado,Archivado,Fecha');
  expect(lines.some((l) => l.includes('E2E leido'))).toBe(true);
});

test('apps.php lista las 3 apps', async ({ page }) => {
  await page.goto('/admin/apps.php');
  const rows = page.locator('tbody tr');
  await expect(rows).toHaveCount(3);
  // created_at puede coincidir (mismo import): se compara sin depender del orden.
  const names = (await rows.locator('td:first-child strong').allInnerTexts()).sort();
  expect(names).toEqual(['NoWait', 'PhishLab', 'eduolihez.com']);
  const slugs = (await rows.locator('td.mono').allInnerTexts()).sort();
  expect(slugs).toEqual(['eduolihez', 'nowait', 'phishlab']);
});
