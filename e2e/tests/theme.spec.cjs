// (d) Tema claro/oscuro: primer pintado sin destello, interruptor que
// alterna y persiste, valor guardado invalido y aria-pressed.
const { test, expect } = require('@playwright/test');

/**
 * Registra el data-theme de <html> en el instante en que el parser crea el
 * <body>, es decir, antes del primer pintado del contenido. Si el tema se
 * fijara despues (en admin.js, al final del body) aqui se veria vacio.
 */
async function recordThemeAtBody(page) {
  await page.addInitScript(() => {
    const obs = new MutationObserver(() => {
      if (document.body) {
        window.__themeAtBody = document.documentElement.dataset.theme ?? null;
        obs.disconnect();
      }
    });
    obs.observe(document, { childList: true, subtree: true });
  });
}

test.describe('sistema en oscuro', () => {
  test.use({ colorScheme: 'dark' });

  test('el primer pintado ya es oscuro (sin destello)', async ({ page }) => {
    await recordThemeAtBody(page);
    await page.goto('/admin/index.php');
    expect(await page.evaluate(() => window.__themeAtBody)).toBe('dark');
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    await expect(page.locator('#theme-toggle')).toHaveAttribute('aria-pressed', 'true');
  });

  test('un valor guardado invalido cae en la preferencia del sistema', async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('admin-theme', 'morado'));
    await page.goto('/admin/index.php');
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  });
});

test.describe('sistema en claro', () => {
  test.use({ colorScheme: 'light' });

  test('el primer pintado es claro', async ({ page }) => {
    await recordThemeAtBody(page);
    await page.goto('/admin/index.php');
    expect(await page.evaluate(() => window.__themeAtBody)).toBe('light');
    await expect(page.locator('#theme-toggle')).toHaveAttribute('aria-pressed', 'false');
  });

  test('un valor guardado invalido cae en la preferencia del sistema', async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('admin-theme', '"><img src=x>'));
    await page.goto('/admin/index.php');
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  });

  test('el interruptor alterna, actualiza aria-pressed y persiste al recargar', async ({ page }) => {
    await page.goto('/admin/index.php');
    const html = page.locator('html');
    const toggle = page.locator('#theme-toggle');
    await expect(html).toHaveAttribute('data-theme', 'light');

    await toggle.click();
    await expect(html).toHaveAttribute('data-theme', 'dark');
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');
    expect(await page.evaluate(() => localStorage.getItem('admin-theme'))).toBe('dark');

    // El valor guardado manda sobre la preferencia del sistema, tambien en otra pagina.
    await page.goto('/admin/messages.php?space=global');
    await expect(html).toHaveAttribute('data-theme', 'dark');
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');

    await toggle.click();
    await expect(html).toHaveAttribute('data-theme', 'light');
    await expect(toggle).toHaveAttribute('aria-pressed', 'false');
    await page.reload();
    await expect(html).toHaveAttribute('data-theme', 'light');
    expect(await page.evaluate(() => localStorage.getItem('admin-theme'))).toBe('light');
  });
});
