import { describe, expect, it, vi } from 'vitest';
import { initPrintButtons } from './print';

describe('initPrintButtons', () => {
  it('calls print on click and is idempotent', () => {
    document.body.innerHTML = '<button data-print>x</button>';
    const print = vi.fn();
    expect(initPrintButtons(document, print)).toBe(1);
    expect(initPrintButtons(document, print)).toBe(0);
    document.querySelector('button')!.click();
    expect(print).toHaveBeenCalledTimes(1);
  });
  it('does nothing without buttons', () => {
    document.body.innerHTML = '';
    expect(initPrintButtons(document, vi.fn())).toBe(0);
  });
});
