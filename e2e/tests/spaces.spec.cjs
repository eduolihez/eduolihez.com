// (b) Espacios y menu lateral: selector, menu de cada espacio, item activo,
// parametros raros y el espacio recordado en sesion.
const { test, expect } = require('@playwright/test');
const { PHP_WARNING, menuLabels, expectActive, expectSpace, followLink } = require('./helpers.cjs');

const MENUS = {
  global: ['Resumen', 'Bandeja', 'Analítica', 'Seguridad', 'Ajustes', 'Backup', 'Integraciones', 'Gestionar apps'],
  site: ['Resumen', 'Proyectos', 'Certificaciones', 'Blog', 'Mensajes', 'Analítica'],
  phishlab: ['Resumen', 'Usuarios'],
  app: ['Resumen'],
};

test('Global: menu completo y Resumen activo', async ({ page }) => {
  await page.goto('/admin/index.php?space=global');
  await expectSpace(page, 'Global');
  expect(await menuLabels(page)).toEqual(MENUS.global);
  await expectActive(page, 'Resumen');
});

test('el selector lista los espacios y navega al inicio de cada uno', async ({ page }) => {
  await page.goto('/admin/index.php');
  const switcher = page.locator('.app-switcher');
  await switcher.locator('summary').click();
  const options = switcher.locator('.app-switcher-menu a');
  await expect(options).toHaveText(['Global', 'eduolihez.com', 'PhishLab', 'NoWait']);
  await expect(switcher.locator('.app-switcher-menu a.active')).toHaveText('Global');

  await options.filter({ hasText: 'eduolihez.com' }).click();
  await expect(page).toHaveURL(/\/admin\/index\.php\?space=site$/);
  await expectSpace(page, 'eduolihez.com');

  await page.locator('.app-switcher summary').click();
  await page.locator('.app-switcher-menu a', { hasText: 'PhishLab' }).click();
  await expect(page).toHaveURL(/\/admin\/lab-users\.php\?space=phishlab$/);
  await expectSpace(page, 'PhishLab');

  await page.locator('.app-switcher summary').click();
  await followLink(page, page.locator('.app-switcher-menu a', { hasText: 'NoWait' }));
  await expect(page).toHaveURL(/\/admin\/analytics\.php\?space=app%3Anowait$/);
  await expectSpace(page, 'NoWait');
});

const SPACE_CASES = [
  { url: 'index.php?space=site', space: 'eduolihez.com', menu: MENUS.site, active: 'Resumen' },
  { url: 'projects.php?space=site', space: 'eduolihez.com', menu: MENUS.site, active: 'Proyectos' },
  { url: 'certifications.php?space=site', space: 'eduolihez.com', menu: MENUS.site, active: 'Certificaciones' },
  { url: 'posts.php?space=site', space: 'eduolihez.com', menu: MENUS.site, active: 'Blog' },
  { url: 'messages.php?space=site', space: 'eduolihez.com', menu: MENUS.site, active: 'Mensajes' },
  { url: 'analytics.php?space=site', space: 'eduolihez.com', menu: MENUS.site, active: 'Analítica' },
  { url: 'messages.php?space=global', space: 'Global', menu: MENUS.global, active: 'Bandeja' },
  { url: 'apps.php?space=global', space: 'Global', menu: MENUS.global, active: 'Gestionar apps' },
  { url: 'lab-users.php?space=phishlab', space: 'PhishLab', menu: MENUS.phishlab, active: 'Usuarios' },
  { url: 'analytics.php?space=phishlab', space: 'PhishLab', menu: MENUS.phishlab, active: 'Resumen' },
  { url: 'analytics.php?space=app:nowait', space: 'NoWait', menu: MENUS.app, active: 'Resumen' },
];

for (const c of SPACE_CASES) {
  test(`${c.url}: menu de ${c.space} y "${c.active}" activo`, async ({ page }) => {
    await page.goto(`/admin/${c.url}`);
    await expectSpace(page, c.space);
    expect(await menuLabels(page)).toEqual(c.menu);
    await expectActive(page, c.active);
  });
}

test('alias legado ?app=nowait abre el espacio de NoWait', async ({ page }) => {
  await page.goto('/admin/analytics.php?app=nowait');
  await expectSpace(page, 'NoWait');
  expect(await menuLabels(page)).toEqual(MENUS.app);
});

for (const qs of ['space=../x', 'space[]=x', 'space=app:noexiste', 'app[]=nowait']) {
  test(`valor invalido (?${qs}) cae en Global sin avisos PHP`, async ({ page }) => {
    const resp = await page.goto(`/admin/index.php?${qs}`);
    expect(resp.status()).toBe(200);
    await expectSpace(page, 'Global');
    expect(await page.content()).not.toMatch(PHP_WARNING);
  });
}

test('<script> en ?space no se ejecuta ni se refleja', async ({ page }) => {
  const payload = '<script>window.__xss=1</script>';
  const resp = await page.goto(`/admin/messages.php?space=${encodeURIComponent(payload)}`);
  expect(resp.status()).toBe(200);
  expect(await resp.text()).not.toContain(payload);
  expect(await page.evaluate(() => window.__xss)).toBeUndefined();
  await expectSpace(page, 'Global');
});

test('index.php abre Global aunque la sesion recuerde otro espacio', async ({ page }) => {
  await page.goto('/admin/messages.php?space=site');
  await expectSpace(page, 'eduolihez.com');
  // Las demas paginas SI recuerdan el espacio...
  await page.goto('/admin/messages.php');
  await expectSpace(page, 'eduolihez.com');
  // ...pero index.php sin ?space= siempre es Global.
  await page.goto('/admin/index.php');
  await expectSpace(page, 'Global');
  await expectActive(page, 'Resumen');
  expect(await menuLabels(page)).toEqual(MENUS.global);
});

test('el enlace de marca lleva a Global', async ({ page }) => {
  await page.goto('/admin/projects.php?space=site');
  await page.locator('a.brand').click();
  await expect(page).toHaveURL(/\/admin\/index\.php\?space=global$/);
  await expectSpace(page, 'Global');
});

for (const [edit, parent] of [
  ['post-edit.php', 'Blog'],
  ['project-edit.php', 'Proyectos'],
  ['cert-edit.php', 'Certificaciones'],
]) {
  test(`${edit} se queda en eduolihez.com y marca "${parent}"`, async ({ page }) => {
    // Aunque la sesion venga de otro espacio.
    await page.goto('/admin/lab-users.php?space=phishlab');
    await expectSpace(page, 'PhishLab');
    await page.goto(`/admin/${edit}`);
    await expectSpace(page, 'eduolihez.com');
    await expectActive(page, parent);
  });
}

test('app-edit.php vive en Global y marca "Gestionar apps"', async ({ page }) => {
  await page.goto('/admin/app-edit.php');
  await expectSpace(page, 'Global');
  await expectActive(page, 'Gestionar apps');
});
