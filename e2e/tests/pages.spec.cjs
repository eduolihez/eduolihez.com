// (c) Todas las paginas del panel, en claro y en oscuro: HTTP 200, sin avisos
// PHP, sin errores de consola (incluye un favicon 404), sin violaciones de
// CSP, un unico <h1>, sin desbordamiento horizontal (1280 y 375 px) y sin
// <svg> anidados en los iconos del menu.
const { test, expect } = require('@playwright/test');
const { PHP_WARNING, adminPages, watchProblems } = require('./helpers.cjs');

// La lista sale del disco: una pagina nueva en server/admin/ entra sola.
const PAGES = [
  ...adminPages(),
  // Variantes de espacio con contenido propio.
  'index.php?space=site',
  'analytics.php?space=site',
  'analytics.php?space=phishlab',
  'analytics.php?space=app:nowait',
];

test('la lista de paginas incluye las de edicion', () => {
  for (const p of ['app-edit.php', 'project-edit.php', 'cert-edit.php', 'post-edit.php', 'index.php']) {
    expect(PAGES).toContain(p);
  }
  for (const p of ['login.php', 'logout.php', 'setup.php', 'auth.php']) {
    expect(PAGES).not.toContain(p);
  }
});

for (const theme of ['light', 'dark']) {
  test.describe(`tema ${theme}`, () => {
    test.use({ colorScheme: theme, viewport: { width: 1280, height: 900 } });

    for (const pg of PAGES) {
      test(`${pg}`, async ({ page }) => {
        const watch = await watchProblems(page);
        const resp = await page.goto(`/admin/${pg}`);
        expect(resp.status(), 'HTTP').toBe(200);
        await expect(page).toHaveURL(new RegExp(`/admin/${pg.split('?')[0].replace('.', '\\.')}`));
        await page.waitForLoadState('load');

        const html = await page.content();
        expect(html.match(PHP_WARNING)?.[0] ?? null, 'aviso PHP en el HTML').toBeNull();
        expect(await page.locator('html').getAttribute('data-theme')).toBe(theme);
        await expect(page.locator('h1')).toHaveCount(1);
        await expect(page.locator('.menu-icon svg svg')).toHaveCount(0);
        await expect(page.locator('.menu-icon > svg').first()).toBeVisible();

        const overflow = () =>
          page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
        expect(await overflow(), 'desborda a 1280 px').toBeLessThanOrEqual(0);
        await page.setViewportSize({ width: 375, height: 800 });
        await page.waitForTimeout(100);
        expect(await overflow(), 'desborda a 375 px').toBeLessThanOrEqual(0);

        expect(await watch.csp(), 'violaciones de CSP').toEqual([]);
        expect(watch.found.console, 'errores de consola').toEqual([]);
        expect(watch.found.errors, 'excepciones JS').toEqual([]);
      });
    }
  });
}
