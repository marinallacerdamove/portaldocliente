import { shallowMount, flushPromises } from '@vue/test-utils';
import PortalGroupDetail from '../PortalGroupDetail.vue';
import PortalGroupsAPI from 'dashboard/api/portalGroups';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${params.count}` : key),
  }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1', groupId: '3' } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('dashboard/api/portalGroups', () => ({ default: { show: vi.fn() } }));

const group = {
  id: 3,
  name: 'Clientes VIP',
  automatic: false,
  empresas: [{ id: 1, nome: 'Acme', active: true, contatos_count: 2 }],
  contatos: [
    {
      id: 9,
      name: 'Ana',
      phone: '+5511999990000',
      active: true,
      empresas: ['Acme', 'Beta'],
    },
    { id: 10, name: 'Beto', phone: null, active: false, empresas: [] },
  ],
  recipients_count: 2,
  excluded: { sem_telefone: 1, sem_contato_no_chatwoot: 2, inativos: 3 },
};

const mountPage = async () => {
  const wrapper = shallowMount(PortalGroupDetail);
  await flushPromises();
  return wrapper;
};

describe('PortalGroupDetail', () => {
  beforeEach(() => vi.clearAllMocks());

  it('asks the Portal for the group of the route', async () => {
    PortalGroupsAPI.show.mockResolvedValue({ data: group });
    await mountPage();

    expect(PortalGroupsAPI.show).toHaveBeenCalledWith('3');
  });

  it('shows how many receive now and why the others were left out', async () => {
    PortalGroupsAPI.show.mockResolvedValue({ data: group });
    const wrapper = await mountPage();
    const text = wrapper.text();

    expect(text).toContain('Clientes VIP');
    expect(text).toContain('PORTAL_GROUPS.DETAIL.RECIPIENTS');
    const excluded = wrapper
      .findAll('li')
      .map(li => li.findAll('span').map(span => span.text()));
    expect(excluded).toEqual([
      ['1', 'PORTAL_GROUPS.DETAIL.EXCLUDED.NO_PHONE'],
      ['2', 'PORTAL_GROUPS.DETAIL.EXCLUDED.NO_CHATWOOT_CONTACT'],
      ['3', 'PORTAL_GROUPS.DETAIL.EXCLUDED.INACTIVE'],
    ]);
  });

  it('lists the companies and the individual contacts with their companies', async () => {
    PortalGroupsAPI.show.mockResolvedValue({ data: group });
    const wrapper = await mountPage();
    const [companiesTable, contactsTable] = wrapper.findAll('table');

    expect(companiesTable.text()).toContain('Acme');
    expect(contactsTable.text()).toContain('Ana');
    expect(contactsTable.text()).toContain('Acme, Beta');
    expect(contactsTable.text()).toContain('PORTAL_GROUPS.DETAIL.NO_PHONE');
  });

  it('shows the Portal message when the group is not found', async () => {
    PortalGroupsAPI.show.mockRejectedValue({
      response: { data: { error: 'Grupo não encontrado.' } },
    });
    const wrapper = await mountPage();

    expect(wrapper.text()).toContain('Grupo não encontrado.');
    expect(wrapper.find('table').exists()).toBe(false);
  });
});
