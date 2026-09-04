import { describe, it, expect, vi, afterEach } from 'vitest';
import { fetchJsonSoft } from './buildFetch';

afterEach(() => {
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe('fetchJsonSoft()', () => {
  it('devuelve el JSON si el primer intento responde bien', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => [{ id: 1 }] })
    );
    const result = await fetchJsonSoft<{ id: number }[]>('https://example.com/api');
    expect(result).toEqual([{ id: 1 }]);
  });

  it('reintenta tras un fallo y devuelve el JSON si un intento posterior responde bien', async () => {
    vi.useFakeTimers();
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce({ ok: false })
      .mockResolvedValueOnce({ ok: true, json: async () => [{ id: 2 }] });
    vi.stubGlobal('fetch', fetchMock);

    const promise = fetchJsonSoft<{ id: number }[]>('https://example.com/api');
    await vi.runAllTimersAsync();
    const result = await promise;

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(result).toEqual([{ id: 2 }]);
  });

  it('devuelve un array vacio (fallo suave) si TODOS los intentos fallan', async () => {
    vi.useFakeTimers();
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network down')));

    const promise = fetchJsonSoft<{ id: number }[]>('https://example.com/api', 3);
    await vi.runAllTimersAsync();
    const result = await promise;

    expect(result).toEqual([]);
  });

  it('no lanza si fetch rechaza (error de red), solo devuelve vacio', async () => {
    vi.useFakeTimers();
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('fetch failed')));

    const promise = fetchJsonSoft('https://example.com/api', 1);
    await vi.runAllTimersAsync();
    await expect(promise).resolves.toEqual([]);
  });
});
