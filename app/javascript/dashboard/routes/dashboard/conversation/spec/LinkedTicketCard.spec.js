import { shallowMount } from '@vue/test-utils';
import LinkedTicketCard from '../LinkedTicketCard.vue';

const testState = vi.hoisted(() => ({ getters: {}, dispatch: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useStore: () => ({ dispatch: testState.dispatch }),
    useMapGetter: key => computed(() => testState.getters[key]),
  };
});

const conversations = {
  10: {
    id: 10,
    status: 'open',
    meta: { sender: { id: 3 }, assignee: { name: 'Ana' } },
    messages: [{ id: 1, content: 'Ticket pai criado para o time Suporte' }],
    custom_attributes: {},
  },
  11: {
    id: 11,
    status: 'open',
    meta: { sender: { id: 3 } },
    messages: [{ id: 2, content: 'Última mensagem automática' }],
    custom_attributes: { assunto: 'Relatório fora do ar' },
  },
};

const mountCard = conversationId => {
  testState.getters = {
    getConversationById: id => conversations[id],
    'contacts/getContact': () => ({ id: 3, name: 'Cliente Exemplo' }),
  };
  return shallowMount(LinkedTicketCard, {
    props: { conversationId, relationLabel: 'Pai' },
    global: { mocks: { $t: key => key } },
  });
};

describe('LinkedTicketCard', () => {
  // Regressão B224: o card do ticket vinculado mostrava a última mensagem (um
  // aviso automático) em vez do assunto do ticket.
  describe('title', () => {
    it('shows the ticket subject', () => {
      const wrapper = mountCard(11);

      expect(wrapper.text()).toContain('Relatório fora do ar');
      expect(wrapper.text()).not.toContain('Última mensagem automática');
    });

    it('falls back to the contact name, never to the last message', () => {
      const wrapper = mountCard(10);

      expect(wrapper.text()).toContain('Cliente Exemplo');
      expect(wrapper.text()).not.toContain('Ticket pai criado');
    });
  });

  // Regressão B233: o card do ticket vinculado não recarregava quando o vínculo
  // mudava (o componente é reaproveitado ao trocar de conversa).
  describe('loading the linked ticket', () => {
    it('fetches the linked conversation that is not in the store yet', async () => {
      const wrapper = mountCard(10);
      testState.dispatch.mockClear();

      await wrapper.setProps({ conversationId: 99 });

      expect(testState.dispatch).toHaveBeenCalledWith('getConversation', 99);
    });

    it('does not fetch a linked conversation that is already in the store', async () => {
      const wrapper = mountCard(10);
      testState.dispatch.mockClear();

      await wrapper.setProps({ conversationId: 11 });

      expect(testState.dispatch).not.toHaveBeenCalled();
    });
  });
});
