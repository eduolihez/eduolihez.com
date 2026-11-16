import { describe, expect, it } from 'vitest';
import { skillGroups } from './skills';

describe('skillGroups', () => {
  it('has unique items and a title in every language', () => {
    const all = skillGroups.flatMap((g) => g.items);
    expect(new Set(all).size).toBe(all.length);
    for (const g of skillGroups) {
      expect(g.category.es && g.category.en && g.category.ca).toBeTruthy();
    }
  });
});
