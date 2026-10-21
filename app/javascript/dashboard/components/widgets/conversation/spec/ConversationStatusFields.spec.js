import { shallowMount } from '@vue/test-utils';
import { emitter } from 'shared/helpers/mitt';
import { CMD_RESOLVE_CONVERSATION } from 'dashboard/helper/commandbar/events';
import ConversationStatusFields from '../ConversationStatusFields.vue';

const testState = vi.hoisted(() => ({
  getters: {},
  saveAttributes: vi.fn(),
}));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useMapGetter: key => computed(() => testState.getters[key]),
  };
});
vi.mock('dashboard/composables/useSaveConversationAttributes', () => ({
  useSaveConversationAttributes: () => testState.saveAttributes,
}));
vi.mock('dashboard/composables/useTicketCatalog', async importOriginal => {
  const { reactive } = await import('vue');
  return {
    ...(await importOriginal()),
    conversationTicketScope: () => 'publico',
    useTicketCatalog: () => ({
      fetchList: vi.fn(),
      state: reactive({
        statuses: [
          {
            id: 1,
            name: 'Em atendimento',
            base: 'em_atendimento',
            conversation_status: 'open',
            active: true,
            ticket_scope: 'ambos',
          },
          {
            id: 2,
            name: 'Fechado',
            base: 'fechado',
            conversation_status: 'resolved',
            active: true,
            ticket_scope: 'ambos',
          },
        ],
        justifications: [],
      }),
    }),
  };
});

const mountFields = chat => {
  testState.getters = {
    getSelectedChat: chat,
    'inboxes/getInbox': () => ({ id: 1, name: 'Portal' }),
  };
  return shallowMount(ConversationStatusFields);
};

describe('ConversationStatusFields', () => {
  const onResolve = vi.fn();

  beforeEach(() => emitter.on(CMD_RESOLVE_CONVERSATION, onResolve));
  afterEach(() => emitter.off(CMD_RESOLVE_CONVERSATION, onResolve));

  // Regressão B239: o status que resolve, escolhido no cabeçalho, só gravava o
  // atributo e pulava o fluxo do Resolver (motivo + campos obrigatórios).
  it('sends a resolving status picked on an open conversation through the Resolve flow', () => {
    const wrapper = mountFields({
      id: 5,
      status: 'open',
      custom_attributes: {},
    });

    wrapper.vm.onSelectStatus({ id: 'Fechado' });

    expect(onResolve).toHaveBeenCalledWith({
      attributes: { status_atendimento: 'Fechado', justificativa: '' },
    });
    expect(testState.saveAttributes).not.toHaveBeenCalled();
  });

  it('saves a non-resolving status directly', () => {
    const wrapper = mountFields({
      id: 5,
      status: 'open',
      custom_attributes: {},
    });

    wrapper.vm.onSelectStatus({ id: 'Em atendimento' });

    expect(onResolve).not.toHaveBeenCalled();
    expect(testState.saveAttributes).toHaveBeenCalledWith(
      expect.objectContaining({ id: 5 }),
      { status_atendimento: 'Em atendimento', justificativa: '' }
    );
  });

  it('saves a resolving status directly when the conversation is already resolved', () => {
    const wrapper = mountFields({
      id: 5,
      status: 'resolved',
      custom_attributes: {},
    });

    wrapper.vm.onSelectStatus({ id: 'Fechado' });

    expect(onResolve).not.toHaveBeenCalled();
    expect(testState.saveAttributes).toHaveBeenCalledTimes(1);
  });
});
