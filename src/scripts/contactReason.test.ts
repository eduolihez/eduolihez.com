import { describe, it, expect } from 'vitest';
import { reasonTag, applyReason, SUBJECT_MAX } from './contactReason';

describe('reasonTag()', () => {
  it('Oferta y Proyecto llevan etiqueta', () => {
    expect(reasonTag('job')).toBe('[Oferta]');
    expect(reasonTag('project')).toBe('[Proyecto]');
  });
  it('Otro y valores desconocidos no llevan etiqueta', () => {
    expect(reasonTag('other')).toBe('');
    expect(reasonTag('')).toBe('');
    expect(reasonTag('toString')).toBe('');
  });
});

describe('applyReason()', () => {
  it('antepone la etiqueta al asunto', () => {
    expect(applyReason('Rol SOC', 'job')).toBe('[Oferta] Rol SOC');
  });
  it('asunto vacio con motivo: solo la etiqueta', () => {
    expect(applyReason('', 'project')).toBe('[Proyecto]');
  });
  it('Otro deja el asunto intacto (rama sin etiqueta)', () => {
    expect(applyReason('Hola', 'other')).toBe('Hola');
    expect(applyReason('', 'other')).toBe('');
  });
  it('no supera la longitud maxima del asunto', () => {
    expect(applyReason('x'.repeat(300), 'job')).toHaveLength(SUBJECT_MAX);
  });
});
