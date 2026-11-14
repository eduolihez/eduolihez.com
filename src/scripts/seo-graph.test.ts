import { describe, it, expect } from 'vitest';
import { shouldEmitProfilePage } from './seo-graph';

describe('shouldEmitProfilePage', () => {
  it('por defecto solo en la portada', () => {
    expect(shouldEmitProfilePage(undefined, '/', '/')).toBe(true);
    expect(shouldEmitProfilePage(undefined, '/en/', '/en/')).toBe(true);
  });

  it('no en posts ni en otras paginas', () => {
    expect(shouldEmitProfilePage(undefined, '/blog/post/algo/', '/')).toBe(false);
    expect(shouldEmitProfilePage(undefined, '/projects/zeora/', '/')).toBe(false);
  });

  it('profile=true lo fuerza en una pagina de perfil', () => {
    expect(shouldEmitProfilePage(true, '/analista-soc-barcelona/', '/')).toBe(true);
  });

  it('profile=false lo impide incluso en la portada', () => {
    expect(shouldEmitProfilePage(false, '/', '/')).toBe(false);
  });
});
