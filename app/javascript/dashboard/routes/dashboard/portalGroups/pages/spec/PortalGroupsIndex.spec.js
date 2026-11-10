import { ref } from 'vue';
import { shallowMount } from '@vue/test-utils';
import PortalGroupsIndex from '../PortalGroupsIndex.vue';

const mockGroups = ref([]);
const mockIsLoading = ref(false);
const mockHasError = ref(false);
const mockErrorMessage = ref('');
const mockFetchGroups = vi.fn();

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));
vi.mock('dashboard/composables/usePortalGroups', () => ({
  usePortalGroups: () => ({
    groups: mockGroups,
    isLoading: mockIsLoading,
    hasError: mockHasError,
    errorMessage: mockErrorMessage,
    fetchGroups: mockFetchGroups,
  }),
}));

const mountPage = () =>
  shallowMount(PortalGroupsIndex, {
    global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
  });

describe('PortalGroupsIndex', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockGroups.value = [];
    mockIsLoading.value = false;
    mockHasError.value = false;
    mockErrorMessage.value = '';
  });

  it('loads the groups and says that the registration is done in the Portal', () => {
    const wrapper = mountPage();

    expect(mockFetchGroups).toHaveBeenCalledTimes(1);
    expect(wrapper.text()).toContain('PORTAL_GROUPS.SUBTITLE');
  });

  it('lists each group with companies, contacts and who receives now', () => {
    mockGroups.value = [
      {
        id: 'todos',
        name: 'Todos os clientes ativos',
        automatic: true,
        empresas_count: 5,
        contatos_count: 12,
        recipients_count: 9,
      },
      {
        id: 3,
        name: 'Clientes VIP',
        automatic: false,
        empresas_count: 2,
        contatos_count: 4,
        recipients_count: 3,
      },
    ];
    const wrapper = mountPage();
    const rows = wrapper.findAll('tbody tr');

    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('Todos os clientes ativos');
    expect(rows[0].text()).toContain('PORTAL_GROUPS.AUTOMATIC');
    expect(rows[0].findAll('td').map(td => td.text())).toEqual([
      expect.stringContaining('Todos os clientes ativos'),
      '5',
      '12',
      '9',
    ]);
    expect(rows[1].text()).not.toContain('PORTAL_GROUPS.AUTOMATIC');
  });

  it('shows the Portal message when loading fails', () => {
    mockHasError.value = true;
    mockErrorMessage.value = 'Grupos indisponíveis';
    const wrapper = mountPage();

    expect(wrapper.text()).toContain('Grupos indisponíveis');
    expect(wrapper.find('table').exists()).toBe(false);
  });

  it('shows the empty state when there is no active group', () => {
    const wrapper = mountPage();

    expect(wrapper.text()).toContain('PORTAL_GROUPS.EMPTY');
  });
});
