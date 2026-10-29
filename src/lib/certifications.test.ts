import { describe, expect, it, vi } from 'vitest';
import { buildLogoMap } from './certifications';

const CREDLY = 'https://images.credly.com/images/a/badge.png';
const OTHER = 'https://images.credly.com/images/b/blob';

describe('buildLogoMap', () => {
  it('maps every distinct remote logo to its optimized version', async () => {
    const optimize = vi.fn(async (url: string) => `/_astro/${url.split('/')[4]}.webp`);
    const map = await buildLogoMap(
      [{ logo_url: CREDLY }, { logo_url: CREDLY }, { logo_url: OTHER }, { name: 'sin logo' }],
      optimize,
    );
    expect(map).toEqual({ [CREDLY]: '/_astro/a.webp', [OTHER]: '/_astro/b.webp' });
    expect(optimize).toHaveBeenCalledTimes(2);
  });

  it('skips a logo whose optimization fails instead of breaking the build', async () => {
    const map = await buildLogoMap([{ logo_url: CREDLY }, { logo_url: OTHER }], async (url) => {
      if (url === CREDLY) throw new Error('timeout');
      return '/_astro/b.webp';
    });
    expect(map).toEqual({ [OTHER]: '/_astro/b.webp' });
  });

  it('ignores relative paths and unsafe schemes', async () => {
    const optimize = vi.fn(async () => '/x.webp');
    const map = await buildLogoMap(
      [{ logo_url: '/img/local.png' }, { logo_url: 'javascript:alert(1)' }, { logo_url: 'data:image/png;base64,AA' }],
      optimize,
    );
    expect(map).toEqual({});
    expect(optimize).not.toHaveBeenCalled();
  });
});
