import { describe, it, expect, vi, afterEach } from 'vitest';
import { foldExperience } from './experience-fold';

function setup() {
  document.body.innerHTML = `
    <div class="exp-detail"><p>primero</p></div>
    <details class="exp-detail" data-exp-fold open><summary>Ver detalle</summary><p>antiguo</p></details>
    <details open><summary>otro</summary></details>`;
  return document.querySelector<HTMLDetailsElement>('details[data-exp-fold]')!;
}

describe('foldExperience', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    document.body.innerHTML = '';
  });

  it('en movil cierra solo los <details data-exp-fold>; el contenido sigue en el DOM', () => {
    vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: true }));
    const d = setup();
    foldExperience();
    expect(d.open).toBe(false);
    expect(d.textContent).toContain('antiguo');
    expect(document.querySelectorAll('details')[1].open).toBe(true);
  });

  it('en escritorio los deja abiertos', () => {
    vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: false }));
    const d = setup();
    foldExperience();
    expect(d.open).toBe(true);
  });

  it('sin matchMedia no hace nada', () => {
    vi.stubGlobal('matchMedia', undefined);
    const d = setup();
    foldExperience();
    expect(d.open).toBe(true);
  });
});
