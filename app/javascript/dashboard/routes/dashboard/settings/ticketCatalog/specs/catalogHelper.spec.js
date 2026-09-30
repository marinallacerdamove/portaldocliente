// PATCH LOCAL (fork) - árvore de serviços e corpo enviado pra API.
import {
  buildServiceTree,
  catalogPayload,
  editableCatalogRecord,
  serviceSubtreeIds,
} from '../catalogHelper';

const services = [
  { id: 3, parent_id: 1, name: 'NF-e' },
  { id: 1, parent_id: null, name: 'Fiscal' },
  { id: 4, parent_id: 3, name: 'Carta de Correção' },
  { id: 2, parent_id: null, name: 'Financeiro' },
  { id: 5, parent_id: 99, name: 'Órfão' },
];

describe('buildServiceTree', () => {
  it('puts each parent before its children with the tree depth', () => {
    expect(
      buildServiceTree(services).map(({ id, depth }) => [id, depth])
    ).toEqual([
      [1, 0],
      [3, 1],
      [4, 2],
      [2, 0],
      [5, 0],
    ]);
  });
});

describe('serviceSubtreeIds', () => {
  it('returns the service and all of its descendants', () => {
    expect([...serviceSubtreeIds(services, 1)].sort()).toEqual([1, 3, 4]);
    expect(serviceSubtreeIds(services, null).size).toBe(0);
  });
});

describe('catalogPayload', () => {
  it('drops read-only fields and the category choice when all are allowed', () => {
    const payload = catalogPayload('services', {
      id: 1,
      name: 'Fiscal',
      full_name: 'Fiscal',
      position: 2,
      all_categories: true,
      category_ids: [7],
    });
    expect(payload).toEqual({
      id: 1,
      name: 'Fiscal',
      all_categories: true,
      category_ids: [],
    });
  });
});

describe('editableCatalogRecord', () => {
  it('fills null text fields with their defaults', () => {
    const record = editableCatalogRecord('services', {
      id: 1,
      name: 'Fiscal',
      description: null,
      parent_id: null,
    });
    expect(record.description).toBe('');
    expect(record.parent_id).toBeNull();
    expect(record.category_ids).toEqual([]);
  });
});
