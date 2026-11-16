import { describe, expect, it, vi } from 'vitest';
// @ts-expect-error modulo .mjs sin tipos
import { check } from '../../scripts/check-credential-links.mjs';

const res = (status: number) => ({ status }) as Response;

describe('check-credential-links', () => {
  it('ok on 200', async () => {
    expect(await check('https://a.b', vi.fn().mockResolvedValue(res(200)))).toBe('ok');
  });
  it('reports 4xx/5xx', async () => {
    expect(await check('https://a.b', vi.fn().mockResolvedValue(res(404)))).toBe('HTTP 404');
  });
  it('retries with GET when HEAD is refused', async () => {
    const f = vi.fn().mockResolvedValueOnce(res(405)).mockResolvedValueOnce(res(200));
    expect(await check('https://a.b', f)).toBe('ok');
    expect(f).toHaveBeenCalledTimes(2);
  });
  it('reports network errors', async () => {
    expect(await check('https://a.b', vi.fn().mockRejectedValue(new Error('boom')))).toContain('boom');
  });
});
