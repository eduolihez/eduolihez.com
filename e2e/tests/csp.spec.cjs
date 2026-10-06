// (f) CSP del panel: cabecera, <style> inyectado bloqueado, element.style permitido.
// Nota: un antivirus que inspecciona HTTPS/HTTP (p.ej. Kaspersky) puede
// AÑADIR hosts a la cabecera que ve el navegador; por eso se comparan
// directivas por su texto y no la cabecera entera por igualdad.
const { test, expect } = require('@playwright/test');
const { watchProblems } = require('./helpers.cjs');

function directives(header) {
  return Object.fromEntries(
    header
      .split(';')
      .map((d) => d.trim())
      .filter(Boolean)
      .map((d) => {
        const [name, ...values] = d.split(/\s+/);
        return [name, values.join(' ')];
      })
  );
}

async function checkCspHeader(page, pg) {
  const resp = await page.goto(`/admin/${pg}`);
  await expect(page).toHaveURL(new RegExp(`/admin/${pg.replace('.', '\\.')}$`));
  const header = resp.headers()['content-security-policy'] || '';
  expect(header).toContain("style-src-elem 'self'");
  expect(header).toContain("style-src-attr 'unsafe-inline'");
  const d = directives(header);
  expect(d['default-src']).toMatch(/^'self'/);
  expect(d['script-src']).toMatch(/^'self'/);
  expect(d['script-src']).not.toContain('unsafe-inline');
  expect(d['style-src-elem']).toMatch(/^'self'/);
  expect(d['style-src-elem']).not.toContain('unsafe-inline');
  expect(d['frame-ancestors']).toMatch(/^'none'/);
  expect(d['object-src']).toMatch(/^'none'/);
}

test('cabecera CSP de index.php', async ({ page }) => {
  await checkCspHeader(page, 'index.php');
});

test('un <style> inyectado se bloquea y element.style sigue funcionando', async ({ page }) => {
  await page.goto('/admin/index.php');
  const r = await page.evaluate(async () => {
    const events = [];
    document.addEventListener('securitypolicyviolation', (e) => events.push(e.violatedDirective));
    const probe = document.createElement('div');
    probe.id = 'csp-probe';
    probe.textContent = 'x';
    document.body.appendChild(probe);
    const st = document.createElement('style');
    st.textContent = '#csp-probe{color:rgb(255, 0, 0) !important}';
    document.head.appendChild(st);
    await new Promise((res) => setTimeout(res, 300));
    const afterStyle = getComputedStyle(probe).color;
    st.remove();
    probe.style.color = 'rgb(0, 128, 0)';
    const afterCssom = getComputedStyle(probe).color;
    return { events, afterStyle, afterCssom };
  });
  expect(r.events).toContain('style-src-elem');
  expect(r.afterStyle).not.toBe('rgb(255, 0, 0)');
  expect(r.afterCssom).toBe('rgb(0, 128, 0)');
});

test('un script en linea inyectado no se ejecuta', async ({ page }) => {
  await page.goto('/admin/index.php');
  const ran = await page.evaluate(async () => {
    const s = document.createElement('script');
    s.textContent = 'window.__inline = 1';
    document.head.appendChild(s);
    await new Promise((res) => setTimeout(res, 100));
    return window.__inline === 1;
  });
  expect(ran).toBe(false);
});

test.describe('sin sesion', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test('cabecera CSP de login.php', async ({ page }) => {
    await checkCspHeader(page, 'login.php');
  });

  for (const theme of ['light', 'dark']) {
    test(`login (${theme}) sin violaciones de CSP ni errores de consola`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: theme });
      const watch = await watchProblems(page);
      const resp = await page.goto('/admin/login.php');
      expect(resp.status()).toBe(200);
      await page.waitForLoadState('load');
      await page.waitForTimeout(200);
      expect(await watch.csp()).toEqual([]);
      expect(watch.found.console).toEqual([]);
      expect(watch.found.errors).toEqual([]);
    });
  }
});
