// (e) Cajon lateral en movil (375 px): abrir/cerrar con los botones y con el overlay.
const { test, expect } = require('@playwright/test');

test.describe('movil 375 px', () => {
  test.use({ viewport: { width: 375, height: 800 }, hasTouch: true });

  test('el cajon se abre con el boton y se cierra con la X y con el overlay', async ({ page }) => {
    await page.goto('/admin/index.php?space=site');
    const sidebar = page.locator('#admin-sidebar');
    const overlay = page.locator('#sidebar-overlay');
    const openBtn = page.locator('#sidebar-open-btn');

    await expect(openBtn).toBeVisible();
    await expect(sidebar).not.toHaveClass(/\bopen\b/);
    await expect(sidebar).not.toBeInViewport();

    await openBtn.click();
    await expect(sidebar).toHaveClass(/\bopen\b/);
    await expect(overlay).toHaveClass(/\bopen\b/);
    await expect(sidebar).toBeInViewport();
    await expect(page.locator('.sidebar-menu a.menu-item', { hasText: 'Proyectos' })).toBeVisible();

    await page.locator('#sidebar-close-btn').click();
    await expect(sidebar).not.toHaveClass(/\bopen\b/);
    await expect(overlay).not.toHaveClass(/\bopen\b/);

    await openBtn.click();
    await expect(sidebar).toHaveClass(/\bopen\b/);
    // Clic en la zona del overlay que no tapa el cajon (borde derecho).
    await page.mouse.click(368, 400);
    await expect(sidebar).not.toHaveClass(/\bopen\b/);
    await expect(overlay).not.toHaveClass(/\bopen\b/);
  });

  test('un enlace del menu abierto navega', async ({ page }) => {
    await page.goto('/admin/index.php?space=site');
    await page.locator('#sidebar-open-btn').click();
    await page.locator('.sidebar-menu a.menu-item', { hasText: 'Blog' }).click();
    await expect(page).toHaveURL(/\/admin\/posts\.php\?space=site$/);
  });
});

test('en escritorio los botones del cajon no se muestran', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto('/admin/index.php');
  await expect(page.locator('#sidebar-open-btn')).toBeHidden();
  await expect(page.locator('#admin-sidebar')).toBeInViewport();
});
