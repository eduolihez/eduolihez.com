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

  test('el primer pintado ya es oscuro por el sistema (sin destello)', async ({ page }) => {
    await recordThemeAtBody(page);
    await page.goto('/admin/index.php');
    // Sin eleccion guardada theme.js no fija data-theme: el CSS sigue al sistema.
    expect(await page.evaluate(() => window.__themeAtBody)).toBeNull();
    await expect(page.locator('html')).not.toHaveAttribute('data-theme', /.*/);
    expect(await page.evaluate(() => getComputedStyle(document.body).backgroundColor)).toBe('rgb(11, 18, 32)');
    await expect(page.locator('#theme-toggle')).toHaveAttribute('aria-pressed', 'true');
  });

  test('un valor guardado invalido cae en la preferencia del sistema', async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('theme', 'morado'));
    await page.goto('/admin/index.php');
    await expect(page.locator('html')).not.toHaveAttribute('data-theme', /.*/);
    expect(await page.evaluate(() => getComputedStyle(document.body).backgroundColor)).toBe('rgb(11, 18, 32)');
  });
});

test.describe('sistema en claro', () => {
  test.use({ colorScheme: 'light' });

  test('el primer pintado es claro', async ({ page }) => {
    await recordThemeAtBody(page);
    await page.goto('/admin/index.php');
    expect(await page.evaluate(() => window.__themeAtBody)).toBeNull();
    await expect(page.locator('#theme-toggle')).toHaveAttribute('aria-pressed', 'false');
  });

  test('un valor guardado invalido cae en la preferencia del sistema', async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('theme', '"><img src=x>'));
    await page.goto('/admin/index.php');
    await expect(page.locator('html')).not.toHaveAttribute('data-theme', /.*/);
  });

  test('el interruptor alterna, actualiza aria-pressed y persiste al recargar', async ({ page }) => {
    await page.goto('/admin/index.php');
    const html = page.locator('html');
    const toggle = page.locator('#theme-toggle');
    await expect(html).not.toHaveAttribute('data-theme', /.*/);

    await toggle.click();
    await expect(html).toHaveAttribute('data-theme', 'dark');
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');
    expect(await page.evaluate(() => localStorage.getItem('theme'))).toBe('dark');

    // El valor guardado manda sobre la preferencia del sistema, tambien en otra pagina.
    await page.goto('/admin/messages.php?space=global');
    await expect(html).toHaveAttribute('data-theme', 'dark');
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');

    await toggle.click();
    await expect(html).toHaveAttribute('data-theme', 'light');
    await expect(toggle).toHaveAttribute('aria-pressed', 'false');
    await page.reload();
    await expect(html).toHaveAttribute('data-theme', 'light');
    expect(await page.evaluate(() => localStorage.getItem('theme'))).toBe('light');
  });
});
