import {
  activeInScope,
  allowedCategories,
  applyServiceChange,
  filterPriorityOptions,
  justificationsForStatus,
} from '../ticketCatalogRules';

const categories = [
  { id: 1, name: 'Dúvida', active: true, ticket_scope: 'ambos' },
  { id: 2, name: 'Erro', active: true, ticket_scope: 'publico' },
  { id: 3, name: 'Interna', active: true, ticket_scope: 'interno' },
  { id: 4, name: 'Antiga', active: false, ticket_scope: 'ambos' },
];

describe('ticketCatalogRules', () => {
  it('keeps only active records of the ticket scope, in API order', () => {
    expect(activeInScope(categories, 'publico').map(c => c.id)).toEqual([1, 2]);
    expect(activeInScope(categories, 'interno').map(c => c.id)).toEqual([1, 3]);
  });

  it('shows every active category of the scope when no service is chosen', () => {
    expect(
      allowedCategories(categories, null, 'publico').map(c => c.id)
    ).toEqual([1, 2]);
  });

  it('honours all_categories and category_ids of the chosen service', () => {
    const all = { all_categories: true, category_ids: [] };
    const some = { all_categories: false, category_ids: [2, 3, 4] };

    expect(
      allowedCategories(categories, all, 'publico').map(c => c.id)
    ).toEqual([1, 2]);
    expect(
      allowedCategories(categories, some, 'publico').map(c => c.id)
    ).toEqual([2]);
    expect(
      allowedCategories(categories, some, 'interno').map(c => c.id)
    ).toEqual([3]);
  });

  it('limits priorities to the category allowed_priorities, keeping none', () => {
    const options = [
      { id: null },
      { id: 'urgent' },
      { id: 'high' },
      { id: 'low' },
    ];

    expect(filterPriorityOptions(options, null)).toEqual(options);
    expect(filterPriorityOptions(options, { allowed_priorities: [] })).toEqual(
      options
    );
    expect(
      filterPriorityOptions(options, { allowed_priorities: ['low'] })
    ).toEqual([{ id: null }, { id: 'low' }]);
  });

  it('lists the active justifications of the chosen status', () => {
    const justifications = [
      { id: 1, active: true, ticket_scope: 'ambos', status_ids: [10] },
      { id: 2, active: false, ticket_scope: 'ambos', status_ids: [10] },
      { id: 3, active: true, ticket_scope: 'interno', status_ids: [10] },
      { id: 4, active: true, ticket_scope: 'publico', status_ids: [20] },
    ];

    expect(
      justificationsForStatus(justifications, { id: 10 }, 'publico').map(
        j => j.id
      )
    ).toEqual([1]);
    expect(justificationsForStatus(justifications, null, 'publico')).toEqual(
      []
    );
  });
});

describe('applyServiceChange', () => {
  const catalog = [
    { id: 1, name: 'Dúvida', active: true, ticket_scope: 'ambos' },
    {
      id: 2,
      name: 'Erro',
      active: true,
      ticket_scope: 'ambos',
      allowed_priorities: ['high', 'urgent'],
    },
    { id: 3, name: 'Interna', active: true, ticket_scope: 'interno' },
  ];
  const change = (service, currentTipo, scope = 'publico') =>
    applyServiceChange({ service, currentTipo, categories: catalog, scope });

  it('keeps the current type when the new service allows it', () => {
    const service = { all_categories: false, category_ids: [1, 2] };
    service.default_category_id = 1;

    expect(change(service, 'Erro').tipo).toBe('Erro');
  });

  it('falls back to the default category of the service, then to none', () => {
    const withDefault = {
      all_categories: false,
      category_ids: [1],
      default_category_id: 1,
    };
    const withoutDefault = { all_categories: false, category_ids: [1] };

    expect(change(withDefault, 'Erro').tipo).toBe('Dúvida');
    expect(change(withoutDefault, 'Erro').tipo).toBe('');
  });

  it('ignores a default category that is not valid for the ticket scope', () => {
    const service = {
      all_categories: true,
      category_ids: [],
      default_category_id: 3,
    };

    expect(change(service, '').tipo).toBe('');
    expect(change(service, '', 'interno').tipo).toBe('Interna');
  });

  it('keeps the current type when the service is cleared and it is valid', () => {
    expect(change(null, 'Dúvida').tipo).toBe('Dúvida');
  });

  it('applies the default priority only when the resulting type allows it', () => {
    const service = {
      all_categories: true,
      category_ids: [],
      default_priority: 'low',
    };

    expect(change(service, 'Dúvida').priority).toBe('low');
    expect(change(service, 'Erro').priority).toBeNull();
    expect(
      change({ ...service, default_priority: 'high' }, 'Erro').priority
    ).toBe('high');
  });
});
