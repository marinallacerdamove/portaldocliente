import { shallowMount, flushPromises } from '@vue/test-utils';
import NewInternalTicket from '../NewInternalTicket.vue';
import TicketsAPI from 'dashboard/api/tickets';
import * as catalogApis from 'dashboard/api/ticketCatalog';
import { useTicketCatalog } from 'dashboard/composables/useTicketCatalog';

const { ticketCustomFieldsAPI, ticketFieldRulesAPI, ticketServicesAPI } =
  catalogApis;

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

// Regressão B77 (auditoria 18/11): "Em cópia" oferecia todos os agentes da conta, mas o servidor só
// aceita membros da caixa escolhida: marcar outro agente dava erro genérico e o ticket não era criado.
describe('NewInternalTicket cc agents', () => {
  const member = { id: 11, name: 'Membro' };
  const outsider = { id: 12, name: 'Fora da caixa' };

  it('offers only agents of the chosen inbox', async () => {
    testState.getters = {
      'agents/getAgents': [member, outsider],
      'teams/getTeams': [team],
      'inboxes/getInboxes': [portalInbox, internalInbox],
      'inboxAssignableAgents/getAssignableAgents': inboxId =>
        inboxId === internalInbox.id ? [member] : [],
    };
    const wrapper = shallowMount(NewInternalTicket, {
      global: { stubs: { Dialog: DialogStub } },
    });
    wrapper.vm.formState.inbox = internalInbox;
    await flushPromises();

    expect(wrapper.vm.ccAgentOptions.map(agent => agent.id)).toEqual([
      member.id,
    ]);
  });
});

// Regressão B31 (auditoria 18/11): o Portal cobra os campos adicionais obrigatórios na abertura e o "Novo
// ticket interno" criava o ticket sem eles (e nem mostrava campo de texto ou checklist). Igual ao Movidesk:
// aparecem os campos que a regra abre para a classificação, os obrigatórios travam a criação, e escolher o
// serviço roda a macro dele no próprio formulário.
describe('NewInternalTicket opening fields and service macro', () => {
  const idDaBase = {
    id: 10,
    key: 'id_da_base',
    name: 'ID da Base:',
    field_type: 'text',
    options: [],
    active: true,
  };
  const checklist = {
    id: 11,
    key: 'checklist_importacao',
    name: 'Checklist: Importação',
    field_type: 'checklist',
    options: ['01. Backup', '02. Importar'],
    active: true,
  };
  const service = {
    id: 1,
    name: 'ALBATROSS',
    full_name: 'ALBATROSS',
    active: true,
    ticket_type: 'ambos',
    macro_id: 7,
  };
  const macro = {
    id: 7,
    actions: [
      {
        action_name: 'set_subject',
        action_params: ['Backup de {{contact.name}}'],
      },
      {
        action_name: 'fill_reply',
        action_params: ['Empresa: {{ticket.empresa}}'],
      },
    ],
  };

  const mountWithCatalog = async ({ idDaBaseRule = {}, getters = {} } = {}) => {
    ticketCustomFieldsAPI.get.mockResolvedValue({
      data: { payload: [idDaBase, checklist] },
    });
    ticketFieldRulesAPI.get.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            active: true,
            conditions: [
              {
                group: 'all',
                attribute: 'servico',
                operator: 'equal_to',
                value: 'ALBATROSS',
              },
            ],
            fields: [
              {
                field_id: 10,
                required_on: 'abertura_agente',
                editable_by_agents: true,
                ...idDaBaseRule,
              },
              {
                field_id: 11,
                required_on: 'abertura',
                editable_by_agents: true,
              },
            ],
          },
        ],
      },
    });
    ticketServicesAPI.get.mockResolvedValue({ data: { payload: [service] } });
    await Promise.all(
      ['customFields', 'fieldRules', 'services'].map(kind =>
        useTicketCatalog().fetchList(kind, { force: true })
      )
    );
    testState.getters = {
      'agents/getAgents': [],
      'teams/getTeams': [team],
      'inboxes/getInboxes': [internalInbox],
      'macros/getMacros': [macro],
      ...getters,
    };
    const wrapper = shallowMount(NewInternalTicket, {
      global: { stubs: { Dialog: DialogStub } },
      attachTo: document.body,
    });
    await flushPromises();
    fillRequiredFields(wrapper);
    return wrapper;
  };

  const selectService = async wrapper => {
    await wrapper.vm.onSelectServico({ id: 'ALBATROSS', name: 'ALBATROSS' });
    await flushPromises();
  };

  beforeEach(() => {
    Object.values(catalogApis).forEach(api =>
      api.get.mockResolvedValue({ data: { payload: [] } })
    );
    TicketsAPI.createInternalTicket.mockResolvedValue({
      data: { id: 900, account_id: 1 },
    });
  });

  it('shows the text and checklist fields the rule opens and blocks the ticket until the required ones are filled', async () => {
    const wrapper = await mountWithCatalog();
    await selectService(wrapper);

    expect(wrapper.vm.openingItems.map(({ field }) => field.key)).toEqual([
      'id_da_base',
      'checklist_importacao',
    ]);
    expect(wrapper.vm.canSubmit).toBe(false);

    wrapper.vm.setClassification('id_da_base', '10234');
    wrapper.vm.setClassification('checklist_importacao', ['01. Backup']);
    expect(wrapper.vm.canSubmit).toBe(true);

    await wrapper.vm.onSubmit();
    expect(submittedTicket().custom_attributes.campos_adicionais).toEqual({
      id_da_base: '10234',
      checklist_importacao: ['01. Backup'],
    });
  });

  // Movidesk: "somente as equipes". Campo de outra equipe não entra na abertura
  // de quem não é dela: não é cobrado nem enviado.
  describe('field restricted to a team', () => {
    const restricted = { team_names: ['Infra'] };
    const asAgent = teamIds => ({
      getCurrentUser: { id: 7 },
      getCurrentRole: 'agent',
      'agents/getAgents': [{ id: 7, team_ids: teamIds }],
      'teams/getTeams': [team, { id: 4, name: 'infra' }],
    });

    it('is neither required nor sent for an agent outside the team', async () => {
      const wrapper = await mountWithCatalog({
        idDaBaseRule: restricted,
        getters: asAgent([3]),
      });
      await selectService(wrapper);
      wrapper.vm.setClassification('id_da_base', '10234');
      wrapper.vm.setClassification('checklist_importacao', ['01. Backup']);

      expect(wrapper.vm.openingItems.map(({ field }) => field.key)).toEqual([
        'checklist_importacao',
      ]);
      expect(wrapper.vm.canSubmit).toBe(true);
      await wrapper.vm.onSubmit();
      expect(submittedTicket().custom_attributes.campos_adicionais).toEqual({
        checklist_importacao: ['01. Backup'],
      });
    });

    it('is required for an agent of the team (name in any case)', async () => {
      const wrapper = await mountWithCatalog({
        idDaBaseRule: restricted,
        getters: asAgent([4]),
      });
      await selectService(wrapper);

      expect(wrapper.vm.openingItems.map(({ field }) => field.key)).toEqual([
        'id_da_base',
        'checklist_importacao',
      ]);
    });
  });

  it('does not require nor send a field the rule no longer shows', async () => {
    const wrapper = await mountWithCatalog();
    await selectService(wrapper);
    wrapper.vm.setClassification('id_da_base', '10234');

    wrapper.vm.onSelectServico({ id: '', name: '' });

    expect(wrapper.vm.openingItems).toEqual([]);
    expect(wrapper.vm.canSubmit).toBe(true);
    await wrapper.vm.onSubmit();
    expect(
      submittedTicket().custom_attributes.campos_adicionais
    ).toBeUndefined();
  });

  it('runs the service macro in the form: fills an empty subject and adds the text to the message', async () => {
    const wrapper = await mountWithCatalog();
    wrapper.vm.formState.contact = { ...contact, name: 'Ana Souza' };

    await selectService(wrapper);

    expect(wrapper.vm.formState.subject).toBe('Backup de Ana Souza');
    expect(wrapper.vm.formState.message).toContain(
      'Empresa: {{ticket.empresa}}'
    );
  });

  it('keeps a subject the agent already typed', async () => {
    const wrapper = await mountWithCatalog();
    wrapper.vm.formState.subject = 'Meu assunto';

    await selectService(wrapper);

    expect(wrapper.vm.formState.subject).toBe('Meu assunto');
  });
});

// Revisão do campo restrito (25/11): os campos do QA/DEV (Fluxo PO no Movidesk, restrito a algumas equipes)
// ficavam editáveis para quem não é da equipe e o servidor descartava o valor sem avisar.
describe('NewInternalTicket QA/DEV fields restricted to a team', () => {
  const decisaoPo = {
    id: 1,
    key: 'decisao_po',
    name: 'Decisão PO',
    field_type: 'list',
    options: ['Aprovado'],
    active: true,
  };

  const mountAs = async teamName => {
    ticketCustomFieldsAPI.get.mockResolvedValue({
      data: { payload: [decisaoPo] },
    });
    ticketFieldRulesAPI.get.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            active: true,
            conditions: [],
            fields: [
              {
                field_id: 1,
                editable_by_agents: true,
                team_names: ['Desenvolvimento'],
              },
            ],
          },
        ],
      },
    });
    await Promise.all(
      ['customFields', 'fieldRules'].map(kind =>
        useTicketCatalog().fetchList(kind, { force: true })
      )
    );
    testState.getters = {
      'agents/getAgents': [{ id: 5, team_ids: [9] }],
      'teams/getTeams': [team, { id: 9, name: teamName }],
      'inboxes/getInboxes': [internalInbox],
      getCurrentRole: 'agent',
      getCurrentUser: { id: 5 },
    };
    const wrapper = shallowMount(NewInternalTicket, {
      global: { stubs: { Dialog: DialogStub } },
    });
    await flushPromises();
    fillRequiredFields(wrapper);
    wrapper.vm.formState.decisaoPo = { id: 'Aprovado', name: 'Aprovado' };
    return wrapper;
  };

  beforeEach(() => {
    Object.values(catalogApis).forEach(api =>
      api.get.mockResolvedValue({ data: { payload: [] } })
    );
    TicketsAPI.createInternalTicket.mockResolvedValue({
      data: { id: 900, account_id: 1 },
    });
  });

  it('locks the field and does not send it for an agent outside the team', async () => {
    const wrapper = await mountAs('suporte técnico');

    expect(wrapper.vm.qaDevLocked('decisao_po')).toBe(true);
    await wrapper.vm.onSubmit();
    expect(
      submittedTicket().custom_attributes.campos_adicionais
    ).toBeUndefined();
  });

  it('keeps the field for a team member', async () => {
    const wrapper = await mountAs('desenvolvimento');

    expect(wrapper.vm.qaDevLocked('decisao_po')).toBe(false);
    await wrapper.vm.onSubmit();
    expect(submittedTicket().custom_attributes.campos_adicionais).toEqual({
      decisao_po: 'Aprovado',
    });
  });
});
