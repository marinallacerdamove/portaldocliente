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
const mockPush = vi.fn();

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: mockPush }) }));
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
  default: { create: vi.fn() },
}));
// O cabeçalho real puxa o roteador inteiro (BackButton); aqui só interessa o slot de ações.
vi.mock('../../components/BaseSettingsHeader.vue', () => ({
  default: { template: '<div><slot name="actions" /></div>' },
}));

const DialogStub = {
  name: 'PortalGroupNameDialog',
  props: ['errorMessage', 'isLoading'],
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div />',
};

const mountPage = () =>
  mount(PortalGroupsIndex, {
    global: {
      stubs: {
        PortalGroupNameDialog: DialogStub,
        SettingsLayout: {
          template:
            '<div><slot name="header" /><slot name="preBody" /><slot name="body" /><slot /></div>',
        },
      },
    },
  });

const groups = [
  {
    id: 'todos',
    name: 'Todos os clientes ativos',
    automatic: true,
    active: true,
    empresas_count: 5,
    contatos_count: 12,
    recipients_count: 9,
  },
  {
    id: 3,
    name: 'Clientes VIP',
    automatic: false,
    active: true,
    empresas_count: 2,
    contatos_count: 4,
    recipients_count: 3,
  },
  {
    id: 4,
    name: 'Antigos',
    automatic: false,
    active: false,
    empresas_count: 1,
    contatos_count: 0,
    recipients_count: 0,
  },
];

describe('Settings > Groups list', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockGroups.value = groups;
    mockIsLoading.value = false;
    mockHasError.value = false;
    mockErrorMessage.value = '';
    mockIsAdmin.value = true;
  });

  it('loads the groups including the inactive ones', () => {
    mountPage();

    expect(mockFetchGroups).toHaveBeenCalledWith({ all: true });
  });

  it('lists each group with its numbers and status, the inactive ones too', () => {
    const wrapper = mountPage();
    const rows = wrapper.findAll('tbody tr');

    expect(rows).toHaveLength(3);
    expect(rows[0].text()).toContain('Todos os clientes ativos');
    expect(rows[0].text()).toContain('PORTAL_GROUPS.AUTOMATIC');
    expect(rows[1].findAll('td').map(td => td.text())).toEqual([
      'Clientes VIP',
      '2',
      '4',
      '3',
      'PORTAL_GROUPS.STATUS.ACTIVE',
      '',
    ]);
    expect(rows[2].text()).toContain('PORTAL_GROUPS.STATUS.INACTIVE');
  });

  it('shows the new group button to administrators only', () => {
    expect(mountPage().text()).toContain('PORTAL_GROUPS.NEW');

    mockIsAdmin.value = false;
    expect(mountPage().text()).not.toContain('PORTAL_GROUPS.NEW');
  });

  it('opens the group when the row button is clicked', async () => {
    const wrapper = mountPage();

    await wrapper.findAll('tbody tr')[1].find('button').trigger('click');

    expect(mockPush).toHaveBeenCalledWith({
      name: 'portal_groups_show',
      params: { groupId: 3 },
    });
  });

  it('creates the group and goes to its page to choose companies and contacts', async () => {
    PortalGroupsAPI.create.mockResolvedValue({ data: { id: 8 } });
    const wrapper = mountPage();

    await wrapper.vm.createGroup('Novo');
    await flushPromises();

    expect(PortalGroupsAPI.create).toHaveBeenCalledWith({ name: 'Novo' });
    expect(useAlert).toHaveBeenCalledWith('PORTAL_GROUPS.CREATE.SUCCESS');
    expect(mockPush).toHaveBeenCalledWith({
      name: 'portal_groups_show',
      params: { groupId: 8 },
    });
  });

  it('keeps the dialog open and shows the Portal error when the name is repeated', async () => {
    PortalGroupsAPI.create.mockRejectedValue({
      response: { data: { errors: ['Nome já está em uso'] } },
    });
    const wrapper = mountPage();

    await wrapper.vm.createGroup('Clientes VIP');
    await flushPromises();

    expect(wrapper.vm.nameError).toBe('Nome já está em uso');
    expect(mockPush).not.toHaveBeenCalled();
    expect(
      wrapper.findComponent({ name: 'PortalGroupNameDialog' }).props()
        .errorMessage
    ).toBe('Nome já está em uso');
  });

  it('shows the Portal message with a retry when loading fails', async () => {
    mockGroups.value = [];
    mockHasError.value = true;
    mockErrorMessage.value = 'Grupos indisponíveis';
    const wrapper = mountPage();

    expect(wrapper.text()).toContain('Grupos indisponíveis');
    expect(wrapper.find('table').exists()).toBe(false);

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'PORTAL_GROUPS.RETRY')
      .trigger('click');
    expect(mockFetchGroups).toHaveBeenLastCalledWith({ all: true });
  });
});
