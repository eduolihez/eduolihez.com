import { describe, expect, it } from 'vitest';
import { splitSentences } from './sentences';

describe('splitSentences', () => {
  it('parte en frases cuando la siguiente empieza en mayuscula', () => {
    expect(splitSentences('Uno dos. Tres cuatro. Cinco.')).toEqual(['Uno dos.', 'Tres cuatro.', 'Cinco.']);
  });

  it('no corta si lo que sigue es minuscula o cifra', () => {
    expect(splitSentences('Version 2.0 estable. Luego v1. y mas')).toEqual(['Version 2.0 estable.', 'Luego v1. y mas']);
  });

  it('respeta ? ! y signos de apertura', () => {
    expect(splitSentences('¿Hola? ¡Si! Vale.')).toEqual(['¿Hola?', '¡Si!', 'Vale.']);
  });

  it('devuelve [] con texto vacio o en blanco', () => {
    expect(splitSentences('')).toEqual([]);
    expect(splitSentences('   ')).toEqual([]);
  });
});
