import { ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import PortalGroupsIndex from '../Index.vue';
import PortalGroupsAPI from 'dashboard/api/portalGroups';
import { useAlert } from 'dashboard/composables';

const mockGroups = ref([]);
const mockIsLoading = ref(false);
const mockHasError = ref(false);
const mockErrorMessage = ref('');
const mockFetchGroups = vi.fn();
const mockIsAdmin = ref(true);

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: mockIsAdmin }),
}));
vi.mock('dashboard/composables/usePortalGroups', () => ({
  portalGroupsErrorMessage: error =>
    error?.response?.data?.errors?.join(' ') || error?.response?.data?.error,
  usePortalGroups: () => ({
    groups: mockGroups,
    isLoading: mockIsLoading,
    hasError: mockHasError,
    errorMessage: mockErrorMessage,
    fetchGroups: mockFetchGroups,
  }),
}));
vi.mock('dashboard/api/portalGroups', () => ({
  default: {
    show: vi.fn(),
    memberOptions: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
  },
}));
// O cabeçalho real puxa o roteador inteiro (BackButton); aqui só interessa o slot de ações.
vi.mock('../../components/BaseSettingsHeader.vue', () => ({
  default: { template: '<div><slot name="actions" /></div>' },
}));

const pickerOpen = vi.fn();
const pickerClose = vi.fn();
const PickerStub = {
  name: 'PortalGroupPickerDialog',
  props: [
    'title',
    'description',
    'confirmLabel',
    'searchPlaceholder',
    'items',
    'isLoadingItems',
    'itemsError',
    'errorMessage',
    'isLoading',
    'canConfirm',
  ],
  emits: ['confirm', 'retry'],
  methods: { open: pickerOpen, close: pickerClose },
  template: '<div><slot name="top" /></div>',
};

const editOpen = vi.fn();
const editClose = vi.fn();
const NameDialogStub = {
  name: 'PortalGroupNameDialog',
  props: ['errorMessage', 'isLoading'],
  emits: ['submit'],
  methods: { open: editOpen, close: editClose },
  template: '<div />',
};

const PanelStub = {
  name: 'PortalGroupContactsPanel',
  props: ['group', 'canEdit', 'busy'],
  emits: ['linkCompanies', 'addContacts', 'removeContact'],
  template: '<div class="panel" />',
};

const InputStub = {
  name: 'Input',
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template: '<input />',
};

const mountPage = async () => {
  const wrapper = mount(PortalGroupsIndex, {
    global: {
      stubs: {
        PortalGroupPickerDialog: PickerStub,
        PortalGroupNameDialog: NameDialogStub,
        PortalGroupContactsPanel: PanelStub,
        Input: InputStub,
        SettingsLayout: {
          template:
            '<div><slot name="header" /><slot name="preBody" /><slot name="body" /><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

const summary = {
  id: 3,
  name: 'Clientes VIP',
  automatic: false,
  active: true,
  empresas_count: 1,
  contatos_count: 1,
  recipients_count: 3,
};

const groups = [
  {
    id: 'todos',
    name: 'Todos os clientes ativos',
    automatic: true,
    active: true,
    empresas_count: null,
    contatos_count: null,
    recipients_count: 9,
  },
  summary,
];

const detail = {
  ...summary,
  empresas: [{ id: 1, nome: 'Acme', contatos: [] }],
  contatos: [
    { id: 20, name: 'Dora' },
    { id: 21, name: 'Eva' },
  ],
};

const options = {
  empresas: [
    { id: 1, nome: 'Acme', cnpj: '11', active: true, contatos_count: 2 },
    { id: 7, nome: 'Delta', cnpj: '', active: false, contatos_count: 0 },
  ],
  contatos: [
    { id: 20, name: 'Dora', phone: '+55', email: null, empresas: ['Zeta'] },
  ],
};

const rowOf = (wrapper, name) =>
  wrapper.findAll('[role="button"]').find(row => row.text().includes(name));
const picker = wrapper => wrapper.findComponent(PickerStub);
const panel = wrapper => wrapper.findComponent(PanelStub);
const buttonByLabel = (wrapper, label) =>
  wrapper
    .findAllComponents({ name: 'Button' })
    .find(button => button.props('label') === label);

const openGroup = async (wrapper, name = 'Clientes VIP') => {
  await rowOf(wrapper, name).trigger('click');
  await flushPromises();
};

describe('Settings > Groups list', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockGroups.value = groups.map(group => ({ ...group }));
    mockIsLoading.value = false;
    mockHasError.value = false;
    mockErrorMessage.value = '';
    mockIsAdmin.value = true;
    PortalGroupsAPI.show.mockResolvedValue({ data: detail });
    PortalGroupsAPI.memberOptions.mockResolvedValue({ data: options });
  });

  it('loads every group, active or not, and lists them with their numbers', async () => {
    const wrapper = await mountPage();

    expect(mockFetchGroups).toHaveBeenCalledWith({ all: true });
    expect(rowOf(wrapper, 'Todos os clientes ativos').text()).toContain('9');
    expect(rowOf(wrapper, 'Clientes VIP').text()).toContain('3');
    expect(panel(wrapper).exists()).toBe(false);
  });

  it('opens the contacts of a group right below it and closes on a second click', async () => {
    const wrapper = await mountPage();

    await openGroup(wrapper);
    expect(PortalGroupsAPI.show).toHaveBeenCalledWith(3);
    expect(panel(wrapper).props('group')).toEqual(detail);
    expect(panel(wrapper).props('canEdit')).toBe(true);

    await openGroup(wrapper);
    expect(panel(wrapper).exists()).toBe(false);
  });

  it('opens one group at a time and fetches again on every open', async () => {
    const wrapper = await mountPage();

    await openGroup(wrapper);
    await openGroup(wrapper, 'Todos os clientes ativos');
    await openGroup(wrapper);

    expect(wrapper.findAllComponents(PanelStub)).toHaveLength(1);
    expect(PortalGroupsAPI.show).toHaveBeenCalledTimes(3);
  });

  it('never edits the automatic group', async () => {
    PortalGroupsAPI.show.mockResolvedValue({
      data: { ...groups[0], recipients: [] },
    });
    const wrapper = await mountPage();

    await openGroup(wrapper, 'Todos os clientes ativos');

    expect(panel(wrapper).props('canEdit')).toBe(false);
    expect(
      rowOf(wrapper, 'Todos os clientes ativos').findAllComponents({
        name: 'Button',
      })
    ).toHaveLength(0);
  });

  it('shows the Portal message and a retry when a group cannot be opened', async () => {
    PortalGroupsAPI.show.mockRejectedValueOnce({
      response: { data: { error: 'Portal fora do ar' } },
    });
    const wrapper = await mountPage();

    await openGroup(wrapper);
    expect(wrapper.text()).toContain('Portal fora do ar');

    await buttonByLabel(wrapper, 'PORTAL_GROUPS.RETRY').trigger('click');
    await flushPromises();
    expect(panel(wrapper).exists()).toBe(true);
  });

  it('links companies with the ones already in the group checked and saves the complete list', async () => {
    PortalGroupsAPI.update.mockResolvedValue({
      data: { ...detail, empresas_count: 2, recipients_count: 5 },
    });
    const wrapper = await mountPage();
    await openGroup(wrapper);

    panel(wrapper).vm.$emit('linkCompanies');
    await flushPromises();

    expect(pickerOpen).toHaveBeenCalledWith([1]);
    expect(PortalGroupsAPI.memberOptions).toHaveBeenCalledTimes(1);
    expect(picker(wrapper).props('title')).toBe(
      'PORTAL_GROUPS.PICKER.COMPANIES_TITLE'
    );
    expect(
      picker(wrapper)
        .props('items')
        .map(item => item.id)
    ).toEqual([1, 7]);

    picker(wrapper).vm.$emit('confirm', [1, 7]);
    await flushPromises();

    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(3, {
      empresa_ids: [1, 7],
    });
    expect(pickerClose).toHaveBeenCalled();
    expect(useAlert).toHaveBeenCalledWith('PORTAL_GROUPS.SAVE_SUCCESS');
    expect(rowOf(wrapper, 'Clientes VIP').text()).toContain('5');
  });

  it('adds contacts with the individual ones already checked', async () => {
    PortalGroupsAPI.update.mockResolvedValue({ data: detail });
    const wrapper = await mountPage();
    await openGroup(wrapper);

    panel(wrapper).vm.$emit('addContacts');
    await flushPromises();
    expect(pickerOpen).toHaveBeenCalledWith([20, 21]);
    expect(picker(wrapper).props('items')).toEqual([
      { id: 20, title: 'Dora', subtitle: '+55 · Zeta', info: '' },
    ]);

    picker(wrapper).vm.$emit('confirm', [20]);
    await flushPromises();
    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(3, {
      partner_ids: [20],
    });
  });

  it('keeps the window open with the Portal error when saving fails', async () => {
    PortalGroupsAPI.update.mockRejectedValue({
      response: { data: { errors: ['Empresa inválida'] } },
    });
    const wrapper = await mountPage();
    await openGroup(wrapper);
    panel(wrapper).vm.$emit('linkCompanies');
    await flushPromises();

    picker(wrapper).vm.$emit('confirm', [1]);
    await flushPromises();

    expect(picker(wrapper).props('errorMessage')).toBe('Empresa inválida');
    expect(pickerClose).not.toHaveBeenCalled();
  });

  it('removes an individual contact keeping the others', async () => {
    PortalGroupsAPI.update.mockResolvedValue({ data: detail });
    const wrapper = await mountPage();
    await openGroup(wrapper);

    panel(wrapper).vm.$emit('removeContact', 20);
    await flushPromises();

    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(3, {
      partner_ids: [21],
    });
    expect(useAlert).toHaveBeenCalledWith('PORTAL_GROUPS.PANEL.REMOVED');
  });

  it('creates a group with a name and the checked companies, then opens it', async () => {
    const created = {
      ...summary,
      id: 9,
      name: 'Feriado',
      empresas: [],
      contatos: [],
    };
    PortalGroupsAPI.create.mockResolvedValue({ data: created });
    PortalGroupsAPI.update.mockResolvedValue({
      data: { ...created, empresas_count: 2 },
    });
    PortalGroupsAPI.show.mockResolvedValue({ data: created });
    const wrapper = await mountPage();

    await buttonByLabel(wrapper, 'PORTAL_GROUPS.NEW').trigger('click');
    await flushPromises();
    expect(pickerOpen).toHaveBeenCalledWith([]);
    expect(picker(wrapper).props('canConfirm')).toBe(false);

    wrapper.findComponent(InputStub).vm.$emit('update:modelValue', ' Feriado ');
    await flushPromises();
    expect(picker(wrapper).props('canConfirm')).toBe(true);

    picker(wrapper).vm.$emit('confirm', [1, 7]);
    await flushPromises();

    expect(PortalGroupsAPI.create).toHaveBeenCalledWith({ name: 'Feriado' });
    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(9, {
      empresa_ids: [1, 7],
    });
    expect(useAlert).toHaveBeenCalledWith('PORTAL_GROUPS.CREATE.SUCCESS');
    expect(rowOf(wrapper, 'Feriado')).toBeTruthy();
    expect(panel(wrapper).exists()).toBe(true);
  });

  it('does not create a second group when linking the companies of a new one fails', async () => {
    PortalGroupsAPI.create.mockResolvedValue({
      data: { ...summary, id: 9, name: 'Feriado', empresas: [], contatos: [] },
    });
    PortalGroupsAPI.update
      .mockRejectedValueOnce({ response: { data: { error: 'Falhou' } } })
      .mockResolvedValueOnce({ data: { ...summary, id: 9, name: 'Feriado' } });
    const wrapper = await mountPage();
    await buttonByLabel(wrapper, 'PORTAL_GROUPS.NEW').trigger('click');
    wrapper.findComponent(InputStub).vm.$emit('update:modelValue', 'Feriado');
    await flushPromises();

    picker(wrapper).vm.$emit('confirm', [1]);
    await flushPromises();
    expect(picker(wrapper).props('errorMessage')).toBe('Falhou');

    picker(wrapper).vm.$emit('confirm', [1]);
    await flushPromises();
    expect(PortalGroupsAPI.create).toHaveBeenCalledTimes(1);
    expect(PortalGroupsAPI.update).toHaveBeenLastCalledWith(9, {
      empresa_ids: [1],
    });
  });

  it('edits name and active from the pencil without opening the group', async () => {
    PortalGroupsAPI.update.mockResolvedValue({
      data: { ...detail, name: 'VIP 2', active: false },
    });
    const wrapper = await mountPage();

    await rowOf(wrapper, 'Clientes VIP')
      .findComponent({ name: 'Button' })
      .trigger('click');
    expect(editOpen).toHaveBeenCalledWith(
      expect.objectContaining({ id: 3, name: 'Clientes VIP' })
    );
    expect(panel(wrapper).exists()).toBe(false);

    wrapper
      .findComponent(NameDialogStub)
      .vm.$emit('submit', { name: 'VIP 2', active: false });
    await flushPromises();

    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(3, {
      name: 'VIP 2',
      active: false,
    });
    expect(editClose).toHaveBeenCalled();
    expect(rowOf(wrapper, 'VIP 2')).toBeTruthy();
  });

  it('shows the Portal error in the edit window when the name is taken', async () => {
    PortalGroupsAPI.update.mockRejectedValue({
      response: { data: { errors: ['Nome já está em uso'] } },
    });
    const wrapper = await mountPage();
    await rowOf(wrapper, 'Clientes VIP')
      .findComponent({ name: 'Button' })
      .trigger('click');

    wrapper
      .findComponent(NameDialogStub)
      .vm.$emit('submit', { name: 'Outro', active: true });
    await flushPromises();

    expect(wrapper.findComponent(NameDialogStub).props('errorMessage')).toBe(
      'Nome já está em uso'
    );
    expect(editClose).not.toHaveBeenCalled();
  });

  it('is read only for an agent: no new group, no pencil, panel without edit', async () => {
    mockIsAdmin.value = false;
    const wrapper = await mountPage();
    await openGroup(wrapper);

    expect(buttonByLabel(wrapper, 'PORTAL_GROUPS.NEW')).toBeUndefined();
    expect(
      rowOf(wrapper, 'Clientes VIP').findAllComponents({ name: 'Button' })
    ).toHaveLength(0);
    expect(panel(wrapper).props('canEdit')).toBe(false);
  });

  it('shows the Portal error and retries the list', async () => {
    mockHasError.value = true;
    mockErrorMessage.value = 'Portal fora do ar';
    mockGroups.value = [];
    const wrapper = await mountPage();

    expect(wrapper.text()).toContain('Portal fora do ar');
    await buttonByLabel(wrapper, 'PORTAL_GROUPS.RETRY').trigger('click');
    expect(mockFetchGroups).toHaveBeenCalledTimes(2);
  });
});
