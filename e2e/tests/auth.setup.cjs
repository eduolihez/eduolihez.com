// Inicia sesion una vez y guarda la sesion para el resto de specs.
const { test: setup, expect } = require('@playwright/test');
const { AUTH_FILE, credentials, login } = require('./helpers.cjs');

setup('iniciar sesion como admin', async ({ page }) => {
  const { user, password } = credentials();
  await login(page, user, password);
  await expect(page).toHaveURL(/\/admin\/index\.php$/);
  await page.context().storageState({ path: AUTH_FILE });
});
