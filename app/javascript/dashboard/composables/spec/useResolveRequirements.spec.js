import { useResolveRequirements } from '../useResolveRequirements';

const testState = vi.hoisted(() => ({ getters: {} }));

vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useMapGetter: key => computed(() => testState.getters[key]),
  };
});
vi.mock('dashboard/composables/useConversationCustomFields', async () => {
  const { ref } = await import('vue');
  return {
    useConversationCustomFields: () => ({
      missingOnResolve: ref([]),
      load: vi.fn().mockResolvedValue(),
    }),
  };
});

const closeReasonAttribute = {
  attributeKey: 'motivo_encerramento',
  attributeDisplayName: 'Motivo de encerramento',
  attributeDisplayType: 'list',
  attributeValues: ['Resolvido', 'Duplicado'],
};

const setup = attributes => {
  testState.getters = {
    getConversationById: id => ({ id }),
    'attributes/getConversationAttributes': attributes,
    'teams/getTeams': [],
  };
  return useResolveRequirements();
};

describe('useResolveRequirements', () => {
  const baseConversation = {
    id: 1,
    priority: 'low',
    meta: { assignee: { id: 1 } },
  };

  // Regressão B222: o Resolver não pedia o motivo de encerramento (depende do
  // recurso pago do Chatwoot, desligado neste fork).
  it('asks for the close reason when the conversation has none', async () => {
    const { missingFor } = setup([closeReasonAttribute]);

    const result = await missingFor({
      ...baseConversation,
      custom_attributes: {},
    });

    expect(result.closeReason).toMatchObject({
      value: 'motivo_encerramento',
      label: 'Motivo de encerramento',
      type: 'list',
      attributeValues: ['Resolvido', 'Duplicado'],
    });
  });

  it('does not ask for the close reason when it is already filled', async () => {
    const { missingFor } = setup([closeReasonAttribute]);

    const result = await missingFor({
      ...baseConversation,
      custom_attributes: { motivo_encerramento: 'Resolvido' },
    });

    expect(result.closeReason).toBeNull();
  });

  it('does not ask for the close reason when the account has no such attribute', async () => {
    const { missingFor } = setup([]);

    const result = await missingFor({
      ...baseConversation,
      custom_attributes: {},
    });

    expect(result.closeReason).toBeNull();
  });
});
