import { shallowMount, flushPromises } from '@vue/test-utils';
import NewInternalTicket from '../NewInternalTicket.vue';
import TicketsAPI from 'dashboard/api/tickets';
import * as catalogApis from 'dashboard/api/ticketCatalog';
import { useTicketCatalog } from 'dashboard/composables/useTicketCatalog';

const { ticketCustomFieldsAPI } = catalogApis;

const testState = vi.hoisted(() => ({
  getters: {},
  onFileUpload: vi.fn(),
}));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useStore: () => ({ dispatch: vi.fn() }),
    useMapGetter: key => computed(() => testState.getters[key]),
  };
});
vi.mock('dashboard/composables/useFileUpload', () => ({
  useFileUpload: () => ({ onFileUpload: testState.onFileUpload }),
}));
vi.mock('dashboard/api/tickets', () => ({
  default: { createInternalTicket: vi.fn() },
}));
vi.mock('dashboard/api/ticketCatalog', () => ({
  ticketServicesAPI: { get: vi.fn() },
  ticketCategoriesAPI: { get: vi.fn() },
  ticketStatusesAPI: { get: vi.fn() },
  ticketJustificationsAPI: { get: vi.fn() },
  ticketCloseReasonsAPI: { get: vi.fn() },
  ticketCustomFieldsAPI: { get: vi.fn() },
  ticketFieldRulesAPI: { get: vi.fn() },
}));

const DialogStub = {
  name: 'Dialog',
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /><slot name="footer" /></div>',
};

const portalInbox = { id: 1, name: 'Portal do Cliente' };
const internalInbox = { id: 5, name: 'Tickets Internos' };
const team = { id: 3, name: 'Suporte' };
const contact = { id: 24, name: 'Ana', additionalAttributes: {} };

const mountComponent = inboxes => {
  testState.getters = {
    'agents/getAgents': [],
    'teams/getTeams': [team],
    'inboxes/getInboxes': inboxes,
  };
  return shallowMount(NewInternalTicket, {
    global: { stubs: { Dialog: DialogStub } },
  });
};

const fillRequiredFields = wrapper => {
  wrapper.vm.formState.contact = contact;
  wrapper.vm.formState.team = team;
  wrapper.vm.formState.message = '<p>Detalhes</p>';
};

const submittedTicket = () => TicketsAPI.createInternalTicket.mock.calls[0][0];

describe('NewInternalTicket', () => {
  beforeEach(() => {
    Object.values(catalogApis).forEach(api =>
      api.get.mockResolvedValue({ data: { payload: [] } })
    );
    TicketsAPI.createInternalTicket.mockResolvedValue({
      data: { id: 900, account_id: 1 },
    });
  });

  // Regressão B215: o ticket interno novo caía na 1ª caixa da conta (Portal do
  // Cliente) quando a caixa "Tickets Internos" não era encontrada.
  describe('inbox', () => {
    it('starts in the Tickets Internos inbox, not in the first inbox of the account', () => {
      const wrapper = mountComponent([portalInbox, internalInbox]);

      expect(wrapper.vm.formState.inbox).toEqual(internalInbox);
    });

    it('has no inbox and does not create the ticket when Tickets Internos does not exist', async () => {
      const wrapper = mountComponent([portalInbox]);
      fillRequiredFields(wrapper);

      expect(wrapper.vm.formState.inbox).toBeNull();
      expect(wrapper.vm.canSubmit).toBe(false);
      await wrapper.vm.onSubmit();

      expect(TicketsAPI.createInternalTicket).not.toHaveBeenCalled();
    });
  });

  // Regressão B214: "Novo ticket interno" sempre criava mensagem pública e
  // notificava o cliente.
  describe('first message visibility', () => {
    it('is a private note by default', async () => {
      const wrapper = mountComponent([internalInbox]);
      fillRequiredFields(wrapper);

      await wrapper.vm.onSubmit();

      expect(submittedTicket().message.private).toBe(true);
    });

    it('is public only when the agent marks it visible to the client', async () => {
      const wrapper = mountComponent([internalInbox]);
      fillRequiredFields(wrapper);
      wrapper.vm.formState.visibleToClient = true;

      await wrapper.vm.onSubmit();

      expect(submittedTicket().message.private).toBe(false);
    });
  });

  // Regressão B217: o ticket interno ficava sem assunto no cabeçalho
  // (custom_attributes.assunto não era gravado).
  it('records the subject in custom_attributes.assunto', async () => {
    const wrapper = mountComponent([internalInbox]);
    fillRequiredFields(wrapper);
    wrapper.vm.formState.subject = '  Relatório fora do ar ';

    await wrapper.vm.onSubmit();

    expect(submittedTicket().custom_attributes.assunto).toBe(
      'Relatório fora do ar'
    );
  });

  // Regressão B213: imagem colada no ticket interno aparecia como texto
  // base64 na mensagem. Agora vai como anexo de verdade.
  describe('pasted image', () => {
    const pasteImage = wrapper => {
      const image = new File(['x'], 'print.png', { type: 'image/png' });
      const event = new Event('paste', { cancelable: true });
      event.clipboardData = { files: [image] };
      URL.createObjectURL = vi.fn(() => 'blob:print');
      wrapper.vm.onPasteMessage(event);
      return { image, event };
    };

    it('is uploaded as an attachment and never embedded as base64 in the message', () => {
      const wrapper = mountComponent([internalInbox]);

      const { image, event } = pasteImage(wrapper);

      expect(event.defaultPrevented).toBe(true);
      expect(testState.onFileUpload).toHaveBeenCalledTimes(1);
      expect(testState.onFileUpload.mock.calls[0][0].file).toBe(image);
      expect(wrapper.vm.formState.message).not.toContain('data:');
    });

    it('lets a ticket with only attachments be created', () => {
      const wrapper = mountComponent([internalInbox]);
      wrapper.vm.formState.contact = contact;
      wrapper.vm.formState.team = team;
      expect(wrapper.vm.canSubmit).toBe(false);

      wrapper.vm.attachedFiles = [
        { resource: { file: new File(['x'], 'a.png') } },
      ];

      expect(wrapper.vm.canSubmit).toBe(true);
    });
  });

  // Regressão B223: os campos QA/DEV do novo ticket (Liberações, Decisão PO,
  // Status da cobrança) ficavam com os selects vazios e gravavam numa chave
  // solta em vez de campos_adicionais.
  describe('QA/DEV fields', () => {
    beforeEach(async () => {
      ticketCustomFieldsAPI.get.mockResolvedValue({
        data: {
          payload: [
            { id: 1, key: 'liberacoes', options: ['Sprint 1', 'Sprint 2'] },
            { id: 2, key: 'decisao_po', options: ['Aprovado'] },
          ],
        },
      });
      await useTicketCatalog().fetchList('customFields', { force: true });
    });

    it('takes the select options from the custom fields catalog', async () => {
      const wrapper = mountComponent([internalInbox]);
      await flushPromises();

      expect(wrapper.vm.liberacoesOptions.map(({ name }) => name)).toEqual([
        'NEW_INTERNAL_TICKET_DIALOG.NONE_OPTION',
        'Sprint 1',
        'Sprint 2',
      ]);
      expect(wrapper.vm.decisaoPoOptions.map(({ id }) => id)).toEqual([
        '',
        'Aprovado',
      ]);
    });

    it('saves the chosen values inside custom_attributes.campos_adicionais, not in loose keys', async () => {
      const wrapper = mountComponent([internalInbox]);
      await flushPromises();
      fillRequiredFields(wrapper);
      wrapper.vm.formState.liberacoes = { id: 'Sprint 2', name: 'Sprint 2' };
      wrapper.vm.formState.issueJira = ' ABC-1 ';

      await wrapper.vm.onSubmit();

      const attributes = submittedTicket().custom_attributes;
      expect(attributes.campos_adicionais).toEqual({
        liberacoes: 'Sprint 2',
        issue_jira: 'ABC-1',
      });
      expect(attributes).not.toHaveProperty('liberacoes');
      expect(attributes).not.toHaveProperty('issue_jira');
    });
  });
});
