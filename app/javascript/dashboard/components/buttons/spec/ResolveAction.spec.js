import { shallowMount, flushPromises } from '@vue/test-utils';
import ResolveAction from '../ResolveAction.vue';

const testState = vi.hoisted(() => ({
  getters: {},
  dispatch: vi.fn(),
  missingFor: vi.fn(),
  openModal: vi.fn(),
}));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useStore: () => ({ dispatch: testState.dispatch }),
    useStoreGetters: () => ({
      getSelectedChat: computed(() => testState.getters.getSelectedChat),
    }),
  };
});
vi.mock('dashboard/composables/emitter', () => ({ useEmitter: vi.fn() }));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));
vi.mock('dashboard/composables/useConversationRequiredAttributes', () => ({
  useConversationRequiredAttributes: () => ({
    checkMissingAttributes: () => ({ missing: [] }),
  }),
}));
vi.mock('dashboard/composables/useResolveRequirements', () => ({
  useResolveRequirements: () => ({ missingFor: testState.missingFor }),
}));
vi.mock('dashboard/helper/portalTicketOffer', () => ({
  shouldOfferPortalTicket: () => false,
}));

const ModalStub = {
  methods: { open: (...args) => testState.openModal(...args) },
  template: '<div />',
};

const closeReason = {
  value: 'motivo_encerramento',
  label: 'Motivo de encerramento',
  type: 'list',
};

const mountResolveAction = () => {
  testState.getters = {
    getSelectedChat: {
      id: 12,
      status: 'open',
      custom_attributes: { assunto: 'Teste' },
    },
  };
  return shallowMount(ResolveAction, {
    global: {
      stubs: { ConversationResolveAttributesModal: ModalStub },
      directives: { 'on-clickaway': {} },
    },
  });
};

const noRequirements = { actions: [], customFields: [], closeReason: null };

describe('ResolveAction', () => {
  beforeEach(() => {
    testState.dispatch.mockResolvedValue();
    testState.missingFor.mockResolvedValue(noRequirements);
  });

  // Regressão B222: o botão Resolver encerrava a conversa sem pedir o motivo
  // de encerramento.
  it('asks for the close reason instead of resolving right away', async () => {
    testState.missingFor.mockResolvedValue({ ...noRequirements, closeReason });
    const wrapper = mountResolveAction();

    await wrapper.vm.onCmdResolveConversation();
    await flushPromises();

    expect(testState.openModal).toHaveBeenCalledTimes(1);
    const [missing, , context] = testState.openModal.mock.calls[0];
    expect(missing).toEqual([closeReason]);
    expect(context).toEqual({ id: 12, snoozedUntil: null });
    expect(testState.dispatch).not.toHaveBeenCalled();
  });

  it('resolves right away when nothing is required', async () => {
    const wrapper = mountResolveAction();

    await wrapper.vm.onCmdResolveConversation();
    await flushPromises();

    expect(testState.openModal).not.toHaveBeenCalled();
    expect(testState.dispatch).toHaveBeenCalledWith('toggleStatus', {
      conversationId: 12,
      status: 'resolved',
      snoozedUntil: null,
    });
  });

  // Regressão B239: o status que resolve, escolhido no cabeçalho, pulava o
  // fluxo do Resolver. Os atributos do status viajam junto com a resolução.
  describe('attributes sent along by the header status', () => {
    const headerAttributes = { status_atendimento: 'Fechado' };

    it('are saved together with the resolution when nothing else is asked', async () => {
      const wrapper = mountResolveAction();

      await wrapper.vm.onCmdResolveConversation({
        attributes: headerAttributes,
      });
      await flushPromises();

      expect(testState.dispatch).toHaveBeenCalledWith('toggleStatus', {
        conversationId: 12,
        status: 'resolved',
        snoozedUntil: null,
        customAttributes: headerAttributes,
      });
    });

    it('are merged with the close reason chosen in the modal', async () => {
      testState.missingFor.mockResolvedValue({
        ...noRequirements,
        closeReason,
      });
      const wrapper = mountResolveAction();

      await wrapper.vm.onCmdResolveConversation({
        attributes: headerAttributes,
      });
      await wrapper.vm.handleResolveWithAttributes({
        attributes: { motivo_encerramento: 'Resolvido' },
        context: { id: 12, snoozedUntil: null },
      });

      expect(testState.dispatch).toHaveBeenCalledWith(
        'toggleStatus',
        expect.objectContaining({
          customAttributes: {
            status_atendimento: 'Fechado',
            motivo_encerramento: 'Resolvido',
          },
        })
      );
    });

    it('do not resolve when the conversation still lacks required fields', async () => {
      testState.missingFor.mockResolvedValue({
        ...noRequirements,
        actions: [{ key: 'priority', label: 'Prioridade' }],
      });
      const wrapper = mountResolveAction();

      await wrapper.vm.onCmdResolveConversation({
        attributes: headerAttributes,
      });
      await flushPromises();

      expect(testState.dispatch).not.toHaveBeenCalled();
    });
  });
});
