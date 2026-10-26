import { describe, expect, it } from 'vitest';
import { skillGroups, skillRows } from './skills';

describe('skillRows', () => {
  it('keeps every skill exactly once across the two rows', () => {
    const [a, b] = skillRows();
    const all = skillGroups.flatMap((g) => g.items).sort();
    expect([...a, ...b].map((s) => s.label).sort()).toEqual(all);
  });

  it('balances the rows to within one item', () => {
    const [a, b] = skillRows();
    expect(Math.abs(a.length - b.length)).toBeLessThanOrEqual(1);
  });

  it('carries the icon of the group each skill belongs to', () => {
    const [a, b] = skillRows();
    const byLabel = new Map([...a, ...b].map((s) => [s.label, s.icon]));
    for (const g of skillGroups) for (const item of g.items) expect(byLabel.get(item)).toBe(g.icon);
  });

  it('interleaves groups so neighbours in a row come from different groups', () => {
    const [a] = skillRows();
    const sameNeighbour = a.filter((s, i) => i > 0 && s.icon === a[i - 1].icon).length;
    expect(sameNeighbour).toBeLessThan(a.length / 2);
  });
});
