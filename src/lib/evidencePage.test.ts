import { describe, expect, it } from 'vitest';
import { evidenceCopy, evidencePaths, evidenceRows, issuerOf } from './evidencePage';
import { evidence } from '../config';

describe('evidencePage', () => {
  it('builds one row per evidence with real fields', () => {
    const rows = evidenceRows();
    expect(rows.map((r) => r.id)).toEqual(evidence.map((e) => e.id));
    expect(rows[0].year).toBe('2026');
    expect(rows.every((r) => r.issuer && r.href)).toBe(true);
  });
  it('uses empty year when absent', () => {
    expect(evidenceRows([{ id: 'E-09', kind: 'repo', label: 'Repo X', href: 'https://a.b' }])[0].year).toBe('');
  });
  it('resolves issuer from credentials or falls back to first word', () => {
    expect(issuerOf('Trend Micro Vision One AI Security Foundation')).toBe('Trend Micro');
    expect(issuerOf('Zzz unknown thing')).toBe('Zzz');
    expect(issuerOf('')).toBe('');
  });
  it('has copy and paths for every language', () => {
    for (const l of ['es', 'en', 'ca'] as const) {
      expect(evidenceCopy[l].h1).toBeTruthy();
      expect(evidencePaths[l]).toMatch(/\/$/);
    }
  });
});
