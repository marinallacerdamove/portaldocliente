import { shallowMount, flushPromises } from '@vue/test-utils';
import TicketLinkDialog from '../TicketLinkDialog.vue';
import TicketsAPI from 'dashboard/api/tickets';

const testState = vi.hoisted(() => ({ getters: {} }));
const alert = vi.fn();
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useStore: () => ({ dispatch: vi.fn() }),
    useMapGetter: key => computed(() => testState.getters[key]),
  };
});
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: msg => alert(msg) }));
vi.mock('dashboard/api/tickets', () => ({
  default: { createInternalTicket: vi.fn() },
}));

const DialogStub = {
  name: 'Dialog',
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /></div>',
};

const portalInbox = { id: 1, name: 'Portal do Cliente' };
const internalInbox = { id: 5, name: 'Tickets Internos' };
const currentChat = {
  id: 267,
  inbox_id: portalInbox.id,
  meta: { sender: { id: 24 } },
  custom_attributes: {},
};
const team = { id: 3, name: 'Suporte' };

const mountComponent = inboxes => {
  testState.getters = {
    getSelectedChat: currentChat,
    'teams/getTeams': [team],
    'agents/getAgents': [],
    'inboxes/getInboxes': inboxes,
  };
  return shallowMount(TicketLinkDialog, {
    global: { stubs: { Dialog: DialogStub }, mocks: { $t: key => key } },
  });
};

describe('TicketLinkDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    TicketsAPI.createInternalTicket.mockResolvedValue({ data: { id: 900 } });
  });

  // Regressão B216: o ticket pai/filho novo herdava a caixa do ticket original
  // (Portal do Cliente) e disparava as automações de cliente.
  it('creates the new parent/child ticket in Tickets Internos, not in the inbox of the original ticket', async () => {
    const wrapper = mountComponent([portalInbox, internalInbox]);
    wrapper.vm.open('newChild');
    wrapper.vm.internalTicketTeam = team;
    wrapper.vm.internalTicketMessage = 'Corrigir o relatório';

    await wrapper.vm.onCreateInternalTicket();
    await flushPromises();

    expect(TicketsAPI.createInternalTicket).toHaveBeenCalledTimes(1);
    expect(TicketsAPI.createInternalTicket.mock.calls[0][0].inbox_id).toBe(
      internalInbox.id
    );
  });

  // Regressão B215: sem a caixa "Tickets Internos" o ticket novo caía na 1ª
  // caixa da conta (Portal do Cliente). Sem fallback: não cria nada.
  it('does not create the ticket when there is no Tickets Internos inbox', async () => {
    const wrapper = mountComponent([portalInbox]);
    wrapper.vm.open('newParent');
    wrapper.vm.internalTicketTeam = team;
    wrapper.vm.internalTicketMessage = 'Corrigir o relatório';

    expect(wrapper.vm.canCreateInternalTicket).toBe(false);
    await wrapper.vm.onCreateInternalTicket();
    await flushPromises();

    expect(TicketsAPI.createInternalTicket).not.toHaveBeenCalled();
  });

  // Regressão B214: o ticket interno sempre criava mensagem pública e
  // notificava o cliente. O padrão agora é nota privada.
  it('sends the first message as a private note unless it is marked visible to the client', async () => {
    const wrapper = mountComponent([internalInbox]);
    wrapper.vm.open('newChild');
    wrapper.vm.internalTicketTeam = team;
    wrapper.vm.internalTicketMessage = 'Corrigir o relatório';

    await wrapper.vm.onCreateInternalTicket();
    await flushPromises();
    expect(
      TicketsAPI.createInternalTicket.mock.calls[0][0].message.private
    ).toBe(true);

    wrapper.vm.visibleToClient = true;
    await wrapper.vm.onCreateInternalTicket();
    await flushPromises();
    expect(
      TicketsAPI.createInternalTicket.mock.calls[1][0].message.private
    ).toBe(false);
  });

  // Regressão B217: o ticket novo ficava sem assunto no cabeçalho
  // (custom_attributes.assunto vazio).
  it('records the first line of the description as the ticket subject', async () => {
    const wrapper = mountComponent([internalInbox]);
    wrapper.vm.open('newChild');
    wrapper.vm.internalTicketTeam = team;
    wrapper.vm.internalTicketMessage = '  Corrigir o relatório\nDetalhes aqui';

    await wrapper.vm.onCreateInternalTicket();
    await flushPromises();

    expect(
      TicketsAPI.createInternalTicket.mock.calls[0][0].custom_attributes
    ).toEqual({ assunto: 'Corrigir o relatório' });
  });
});
