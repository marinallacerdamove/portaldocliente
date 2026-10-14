// PATCH LOCAL (fork) - árvore de serviços e corpo enviado pra API.
import {
  buildServiceTree,
  catalogPayload,
  displayCatalogCode,
  editableCatalogRecord,
  serviceSubtreeIds,
} from '../catalogHelper';
import { CATALOG_KINDS } from '../constants';

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

describe('catalog code', () => {
  it('shows the code the Portal gave, or the waiting text while it is null', () => {
    expect(displayCatalogCode({ code: 'SRV-0042' }, 'Aguardando')).toBe(
      'SRV-0042'
    );
    expect(displayCatalogCode({ code: null }, 'Aguardando')).toBe('Aguardando');
    expect(displayCatalogCode({}, 'Aguardando')).toBe('Aguardando');
  });

  it('never sends the code to the admin API', () => {
    const record = editableCatalogRecord('statuses', {
      id: 3,
      name: 'Novo',
      code: 'STS-0003',
    });

    expect(record.code).toBe('STS-0003');
    expect(catalogPayload('statuses', record)).not.toHaveProperty('code');
  });

  it('has a code only on the five catalogs the Portal numbers', () => {
    const withCode = Object.entries(CATALOG_KINDS)
      .filter(([, kind]) => kind.hasCode !== false)
      .map(([name]) => name);

    expect(withCode).toEqual([
      'services',
      'categories',
      'statuses',
      'justifications',
      'closeReasons',
    ]);
  });
});
