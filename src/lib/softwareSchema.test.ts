import { describe, expect, it } from 'vitest';
import { buildSoftwareNodes } from './softwareSchema';
import { softwareEntries } from '../data/software';

const DOMAIN = 'https://eduolihez.com';
const PERSON = `${DOMAIN}/#person`;

describe('buildSoftwareNodes', () => {
  const nodes = buildSoftwareNodes('es', DOMAIN, PERSON);

  it('emits one node per catalogued entry', () => {
    expect(nodes).toHaveLength(softwareEntries.length);
  });

  it('gives every node a unique @id and links the author to the Person node', () => {
    const ids = nodes.map((n) => n['@id']);
    expect(new Set(ids).size).toBe(ids.length);
    for (const n of nodes) expect(n.author).toEqual({ '@id': PERSON });
  });

  it('types repositories as SoftwareSourceCode with a GitHub codeRepository', () => {
    const code = nodes.filter((n) => n['@type'] === 'SoftwareSourceCode');
    expect(code.length).toBeGreaterThan(0);
    for (const n of code) expect(String(n.codeRepository)).toMatch(/^https:\/\/github\.com\/eduolihez\//);
  });

  it('types browser extensions as SoftwareApplication with their /apps/ URL', () => {
    const nowait = nodes.find((n) => n.name === 'NoWait');
    expect(nowait?.['@type']).toBe('SoftwareApplication');
    expect(nowait?.url).toBe(`${DOMAIN}/apps/nowait/`);
    expect(nowait?.applicationCategory).toBe('BrowserApplication');
  });

  it('resolves internal paths against the domain and keeps external URLs as they are', () => {
    const hub = nodes.find((n) => n.name === 'Blue Team Hub');
    expect(hub?.url).toBe('https://eduolihez.github.io/');
    const phishlab = nodes.find((n) => n.name === 'PhishLab');
    expect(phishlab?.url).toBe(`${DOMAIN}/projects/phishlab/`);
  });

  it('localises descriptions and falls back to Spanish when a language is missing', () => {
    const en = buildSoftwareNodes('en', DOMAIN, PERSON);
    const es = nodes.find((n) => n.name === 'Vigia')?.description;
    const enDesc = en.find((n) => n.name === 'Vigia')?.description;
    expect(enDesc).toBeTruthy();
    expect(enDesc).not.toBe(es);
    const ca = buildSoftwareNodes('ca', DOMAIN, PERSON);
    expect(ca.find((n) => n.name === 'Vigia')?.description).toBeTruthy();
  });

  it('flags projects still in development', () => {
    const ng = nodes.find((n) => n.name === 'NorthGate Browser');
    expect(ng?.creativeWorkStatus).toBe('In development');
  });

  it('serialises without undefined or empty values', () => {
    const json = JSON.stringify(nodes);
    expect(json).not.toContain('undefined');
    expect(json).not.toContain('""');
  });
});
