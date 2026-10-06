// (a) Acceso: login, logout y paginas protegidas. Cada test con su propio
// contexto SIN la sesion compartida.
const { test, expect } = require('@playwright/test');
const { credentials, login, expectSpace } = require('./helpers.cjs');

test.use({ storageState: { cookies: [], origins: [] } });

test('contrasena incorrecta: sigue en el login con un error', async ({ page }) => {
  const { user } = credentials();
  await login(page, user, 'contrasena-incorrecta-123');
  await expect(page).toHaveURL(/\/admin\/login\.php$/);
  await expect(page.locator('.err')).toContainText('incorrectos');
  await expect(page.locator('#password')).toBeVisible();
});

test('contrasena correcta: aterriza en index.php en Global y el logout cierra la sesion', async ({ page }) => {
  const { user, password } = credentials();
  await login(page, user, password);
  await expect(page).toHaveURL(/\/admin\/index\.php$/);
  await expectSpace(page, 'Global');
  await expect(page.locator('.sidebar-footer .username')).toHaveText(user);

  await page.getByRole('button', { name: 'Cerrar sesion' }).click();
  await expect(page).toHaveURL(/\/admin\/login\.php$/);

  // La sesion ya no vale: volver al panel redirige al login.
  await page.goto('/admin/index.php');
  await expect(page).toHaveURL(/\/admin\/login\.php$/);
});

test('logout por GET no cierra la sesion (solo POST con CSRF)', async ({ page }) => {
  const { user, password } = credentials();
  await login(page, user, password);
  await expect(page).toHaveURL(/\/admin\/index\.php$/);
  await page.goto('/admin/logout.php');
  await page.goto('/admin/index.php');
  await expect(page).toHaveURL(/\/admin\/index\.php$/);
});

for (const pg of ['index.php', 'projects.php', 'messages.php?space=site', 'lab-users.php']) {
  test(`sin sesion, ${pg} redirige al login`, async ({ page }) => {
    await page.goto(`/admin/${pg}`);
    await expect(page).toHaveURL(/\/admin\/login\.php$/);
  });
}
