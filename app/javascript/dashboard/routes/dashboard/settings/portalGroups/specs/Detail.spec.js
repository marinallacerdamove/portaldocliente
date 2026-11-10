import { ref } from 'vue';
import { shallowMount, flushPromises } from '@vue/test-utils';
import PortalGroupDetail from '../Detail.vue';
import PortalGroupsAPI from 'dashboard/api/portalGroups';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import PortalGroupCompanyRow from 'dashboard/components-next/PortalGroups/PortalGroupCompanyRow.vue';
import PortalGroupContactRow from 'dashboard/components-next/PortalGroups/PortalGroupContactRow.vue';
import { useAlert } from 'dashboard/composables';

const mockIsAdmin = ref(true);

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) =>
      params?.count !== undefined ? `${key} ${params.count}` : key,
  }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1', groupId: '3' } }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: mockIsAdmin }),
}));
vi.mock('dashboard/api/portalGroups', () => ({
  default: { show: vi.fn(), memberOptions: vi.fn(), update: vi.fn() },
}));

const acme = {
  id: 1,
  nome: 'Acme',
  cnpj: '11.222.333/0001-81',
  active: true,
  contatos_count: 3,
  recebem_count: 2,
  contatos: [
    { id: 9, name: 'Ana', phone: '+5511999990000', status: 'recebe' },
    { id: 10, name: 'Beto', phone: null, status: 'sem_telefone' },
    { id: 11, name: 'Caio', phone: '+5511999991111', status: 'recebe' },
  ],
};

// Ana (9) está em duas empresas: no total entra uma vez só.
const delta = {
  id: 7,
  nome: 'Delta',
  cnpj: '55.666.777/0001-22',
  active: true,
  contatos_count: 2,
  recebem_count: 2,
  contatos: [
    { id: 30, name: 'Eva', phone: '+5511988880000', status: 'recebe' },
    { id: 9, name: 'Ana', phone: '+5511999990000', status: 'recebe' },
  ],
};

const omega = {
  id: 8,
  nome: 'Omega',
  cnpj: '',
  active: false,
  contatos_count: 1,
  recebem_count: 0,
  contatos: [
    { id: 40, name: 'Gil', phone: '+5511977770000', status: 'inativos' },
  ],
};

const group = {
  id: 3,
  name: 'Clientes VIP',
  automatic: false,
  active: true,
  empresas: [acme],
  contatos: [
    {
      id: 20,
      name: 'Dora',
      phone: '+5511966660000',
      active: true,
      empresas: ['Zeta'],
      status: 'recebe',
    },
  ],
  recipients_count: 3,
  excluded: { sem_telefone: 1, sem_contato_no_chatwoot: 0, inativos: 0 },
};

const options = {
  empresas: [acme, delta, omega],
  contatos: [
    {
      id: 20,
      name: 'Dora',
      email: 'dora@zeta.test',
      phone: '+5511966660000',
      active: true,
      empresas: ['Zeta'],
      status: 'recebe',
    },
    {
      id: 21,
      name: 'Fábio',
      email: null,
      phone: '+5511955550000',
      active: true,
      empresas: [],
      status: 'recebe',
    },
    {
      id: 22,
      name: 'Gus',
      email: null,
      phone: null,
      active: true,
      empresas: [],
      status: 'sem_telefone',
    },
  ],
};

const mountPage = async () => {
  const wrapper = shallowMount(PortalGroupDetail);
  await flushPromises();
  return wrapper;
};

const companyRows = wrapper => wrapper.findAllComponents(PortalGroupCompanyRow);
const contactRows = wrapper => wrapper.findAllComponents(PortalGroupContactRow);
const companyNames = wrapper =>
  companyRows(wrapper).map(row => row.props('empresa').nome);
const contactNames = wrapper =>
  contactRows(wrapper).map(row => row.props('contato').name);
const nameInput = wrapper =>
  wrapper.find('input[aria-label="PORTAL_GROUPS.DETAIL.NAME_LABEL"]');
const buttonByLabel = (wrapper, label) =>
  wrapper
    .findAllComponents({ name: 'Button' })
    .find(button => button.attributes('label') === label);
const isSaveEnabled = wrapper =>
  buttonByLabel(wrapper, 'PORTAL_GROUPS.DETAIL.SAVE').attributes('disabled') !==
  'true';
const recipients = count => `PORTAL_GROUPS.DETAIL.RECIPIENTS ${count}`;
const openTab = async (wrapper, key) => {
  wrapper.findComponent(TabBar).vm.$emit('tabChanged', { key });
  await flushPromises();
};
const search = async (wrapper, term) => {
  wrapper.findComponent(Input).vm.$emit('update:modelValue', term);
  await flushPromises();
};

describe('Settings > Group detail', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsAdmin.value = true;
    PortalGroupsAPI.show.mockResolvedValue({ data: group });
    PortalGroupsAPI.memberOptions.mockResolvedValue({ data: options });
  });

  it('asks the Portal for the group of the route and, for an administrator, for the options', async () => {
    await mountPage();

    expect(PortalGroupsAPI.show).toHaveBeenCalledWith('3');
    expect(PortalGroupsAPI.memberOptions).toHaveBeenCalledTimes(1);
  });

  it('lists only what is in the group on the first tab, companies first, all checked', async () => {
    const wrapper = await mountPage();

    expect(companyNames(wrapper)).toEqual(['Acme']);
    expect(contactNames(wrapper)).toEqual(['Dora']);
    expect(companyRows(wrapper)[0].props('checked')).toBe(true);
    expect(contactRows(wrapper)[0].props('checked')).toBe(true);
    expect(contactRows(wrapper)[0].props('subtitle')).toBe(
      'PORTAL_GROUPS.CONTACT.INDIVIDUAL · Zeta'
    );
    expect(wrapper.text()).toContain(recipients(3));
  });

  it('counts members and options on the tabs', async () => {
    const wrapper = await mountPage();

    expect(
      wrapper
        .findComponent(TabBar)
        .props('tabs')
        .map(tab => [tab.key, tab.count])
    ).toEqual([
      ['members', 2],
      ['companies', 3],
      ['contacts', 3],
    ]);
  });

  it('shows every company of the account on its tab, checked when in the group', async () => {
    const wrapper = await mountPage();
    await openTab(wrapper, 'companies');

    expect(companyNames(wrapper)).toEqual(['Acme', 'Delta', 'Omega']);
    expect(companyRows(wrapper).map(row => row.props('checked'))).toEqual([
      true,
      false,
      false,
    ]);
    expect(contactRows(wrapper)).toHaveLength(0);
  });

  it('checking a company puts it in the group and counts its contacts at once, without repeating a contact', async () => {
    const wrapper = await mountPage();
    await openTab(wrapper, 'companies');

    companyRows(wrapper)[1].vm.$emit('toggle', 7);
    await flushPromises();

    // Acme: Ana, Caio. Delta: Eva, Ana (repetida). Avulso: Dora. = 4
    expect(wrapper.text()).toContain(recipients(4));
    expect(companyRows(wrapper)[1].props('checked')).toBe(true);
    expect(PortalGroupsAPI.update).not.toHaveBeenCalled();

    await openTab(wrapper, 'members');
    expect(companyNames(wrapper)).toEqual(['Acme', 'Delta']);
  });

  it('counts nobody from an inactive company', async () => {
    const wrapper = await mountPage();
    await openTab(wrapper, 'companies');

    companyRows(wrapper)[2].vm.$emit('toggle', 8);
    await flushPromises();

    expect(wrapper.text()).toContain(recipients(3));
  });

  it('unchecking a company takes it out of the group and of the count', async () => {
    const wrapper = await mountPage();

    companyRows(wrapper)[0].vm.$emit('toggle', 1);
    await flushPromises();

    expect(companyNames(wrapper)).toEqual([]);
    // só o avulso Dora
    expect(wrapper.text()).toContain(recipients(1));
  });

  it('opens and closes the contacts of a company', async () => {
    const wrapper = await mountPage();

    companyRows(wrapper)[0].vm.$emit('expand', 1);
    await flushPromises();
    expect(companyRows(wrapper)[0].props('expanded')).toBe(true);

    companyRows(wrapper)[0].vm.$emit('expand', 1);
    await flushPromises();
    expect(companyRows(wrapper)[0].props('expanded')).toBe(false);
  });

  it('adds an individual contact to the count only when the Portal says it receives', async () => {
    const wrapper = await mountPage();
    await openTab(wrapper, 'contacts');

    expect(contactNames(wrapper)).toEqual(['Dora', 'Fábio', 'Gus']);

    contactRows(wrapper)[2].vm.$emit('toggle', 22);
    await flushPromises();
    expect(wrapper.text()).toContain(recipients(3));

    contactRows(wrapper)[1].vm.$emit('toggle', 21);
    await flushPromises();
    expect(wrapper.text()).toContain(recipients(4));
  });

  it('filters the open tab by the search and clears it when the tab changes', async () => {
    const wrapper = await mountPage();
    await openTab(wrapper, 'companies');

    await search(wrapper, 'delta');
    expect(companyNames(wrapper)).toEqual(['Delta']);

    await search(wrapper, '55.666');
    expect(companyNames(wrapper)).toEqual(['Delta']);

    await search(wrapper, 'nada disso');
    expect(companyRows(wrapper)).toHaveLength(0);
    expect(wrapper.text()).toContain('PORTAL_GROUPS.LIST.NO_MATCH');

    await openTab(wrapper, 'contacts');
    expect(wrapper.findComponent(Input).props('modelValue')).toBe('');
    expect(contactNames(wrapper)).toEqual(['Dora', 'Fábio', 'Gus']);
  });

  it('finds a contact by the name of a company of theirs', async () => {
    const wrapper = await mountPage();
    await openTab(wrapper, 'contacts');

    await search(wrapper, 'zeta');
    expect(contactNames(wrapper)).toEqual(['Dora']);
  });

  it('keeps Save disabled while nothing changed or the name is empty', async () => {
    const wrapper = await mountPage();
    expect(isSaveEnabled(wrapper)).toBe(false);

    await nameInput(wrapper).setValue('Novo nome');
    expect(isSaveEnabled(wrapper)).toBe(true);

    await nameInput(wrapper).setValue('   ');
    expect(isSaveEnabled(wrapper)).toBe(false);
  });

  it('saves everything in a single PATCH with the complete lists', async () => {
    PortalGroupsAPI.update.mockResolvedValue({
      data: {
        ...group,
        name: 'VIP 2',
        active: false,
        empresas: [acme, delta],
        contatos: [],
        recipients_count: 3,
      },
    });
    const wrapper = await mountPage();

    await nameInput(wrapper).setValue('  VIP 2 ');
    wrapper.findComponent(Switch).vm.$emit('update:modelValue', false);
    contactRows(wrapper)[0].vm.$emit('toggle', 20);
    await openTab(wrapper, 'companies');
    companyRows(wrapper)[1].vm.$emit('toggle', 7);
    await flushPromises();
    await wrapper.vm.save();
    await flushPromises();

    expect(PortalGroupsAPI.update).toHaveBeenCalledTimes(1);
    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(3, {
      name: 'VIP 2',
      active: false,
      empresa_ids: [1, 7],
      partner_ids: [],
    });
    expect(useAlert).toHaveBeenCalledWith('PORTAL_GROUPS.DETAIL.SAVE_SUCCESS');
    expect(wrapper.text()).toContain(recipients(3));
    expect(wrapper.vm.isDirty).toBe(false);
  });

  it('sends an empty complete list when the last company is unchecked', async () => {
    PortalGroupsAPI.update.mockResolvedValue({ data: group });
    const wrapper = await mountPage();

    companyRows(wrapper)[0].vm.$emit('toggle', 1);
    await flushPromises();
    await wrapper.vm.save();

    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(3, {
      name: 'Clientes VIP',
      active: true,
      empresa_ids: [],
      partner_ids: [20],
    });
  });

  it('shows the Portal error and keeps what was typed when the name is repeated', async () => {
    PortalGroupsAPI.update.mockRejectedValue({
      response: { data: { errors: ['Nome já está em uso'] } },
    });
    const wrapper = await mountPage();

    await nameInput(wrapper).setValue('Outro');
    await wrapper.vm.save();
    await flushPromises();

    expect(wrapper.text()).toContain('Nome já está em uso');
    expect(useAlert).toHaveBeenCalledWith('Nome já está em uso');
    expect(nameInput(wrapper).element.value).toBe('Outro');
    expect(wrapper.vm.isDirty).toBe(true);
  });

  it('discards the changes and goes back to the saved group', async () => {
    const wrapper = await mountPage();

    companyRows(wrapper)[0].vm.$emit('toggle', 1);
    await nameInput(wrapper).setValue('Outro');
    await buttonByLabel(wrapper, 'PORTAL_GROUPS.DETAIL.DISCARD').vm.$emit(
      'click'
    );
    await flushPromises();

    expect(companyNames(wrapper)).toEqual(['Acme']);
    expect(nameInput(wrapper).element.value).toBe('Clientes VIP');
    expect(wrapper.text()).toContain(recipients(3));
  });

  it('is the same list without tabs, boxes or Save for an agent', async () => {
    mockIsAdmin.value = false;
    const wrapper = await mountPage();

    expect(PortalGroupsAPI.memberOptions).not.toHaveBeenCalled();
    expect(companyNames(wrapper)).toEqual(['Acme']);
    expect(contactNames(wrapper)).toEqual(['Dora']);
    expect(companyRows(wrapper)[0].props('canEdit')).toBe(false);
    expect(contactRows(wrapper)[0].props('canEdit')).toBe(false);
    expect(wrapper.findComponent(TabBar).exists()).toBe(false);
    expect(nameInput(wrapper).exists()).toBe(false);
    expect(wrapper.findComponent(Switch).exists()).toBe(false);
    expect(buttonByLabel(wrapper, 'PORTAL_GROUPS.DETAIL.SAVE')).toBeUndefined();
    expect(wrapper.text()).toContain('PORTAL_GROUPS.DETAIL.READ_ONLY');
    expect(wrapper.text()).toContain('Clientes VIP');
  });

  it('is read only for the automatic group even for an administrator', async () => {
    PortalGroupsAPI.show.mockResolvedValue({
      data: {
        ...group,
        id: 'todos',
        automatic: true,
        empresas: [],
        contatos: [],
        recipients_count: 120,
      },
    });
    const wrapper = await mountPage();

    expect(PortalGroupsAPI.memberOptions).not.toHaveBeenCalled();
    expect(companyRows(wrapper)).toHaveLength(0);
    expect(nameInput(wrapper).exists()).toBe(false);
    expect(buttonByLabel(wrapper, 'PORTAL_GROUPS.DETAIL.SAVE')).toBeUndefined();
    expect(wrapper.text()).toContain('PORTAL_GROUPS.DETAIL.AUTOMATIC_HINT');
    expect(wrapper.text()).toContain(recipients(120));
  });

  it('shows the Portal message when the group cannot be loaded', async () => {
    PortalGroupsAPI.show.mockRejectedValue({
      response: { data: { error: 'Grupo não encontrado.' } },
    });
    const wrapper = await mountPage();

    expect(wrapper.text()).toContain('Grupo não encontrado.');
    expect(companyRows(wrapper)).toHaveLength(0);
  });

  it('keeps the group usable when only the options fail to load', async () => {
    PortalGroupsAPI.memberOptions.mockRejectedValue({
      response: { data: { error: 'Portal fora do ar' } },
    });
    const wrapper = await mountPage();

    expect(companyNames(wrapper)).toEqual(['Acme']);

    await openTab(wrapper, 'companies');
    expect(wrapper.text()).toContain('Portal fora do ar');
    expect(companyRows(wrapper)).toHaveLength(0);
  });
});
