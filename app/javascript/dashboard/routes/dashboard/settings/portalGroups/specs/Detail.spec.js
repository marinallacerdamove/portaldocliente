import { ref } from 'vue';
import { shallowMount, flushPromises } from '@vue/test-utils';
import PortalGroupDetail from '../Detail.vue';
import PortalGroupsAPI from 'dashboard/api/portalGroups';
import Input from 'dashboard/components-next/input/Input.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import PortalGroupCompanyBlock from 'dashboard/components-next/PortalGroups/PortalGroupCompanyBlock.vue';
import PortalGroupIndividualContacts from 'dashboard/components-next/PortalGroups/PortalGroupIndividualContacts.vue';
import PortalGroupMemberSearch from 'dashboard/components-next/PortalGroups/PortalGroupMemberSearch.vue';
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

const blocks = wrapper => wrapper.findAllComponents(PortalGroupCompanyBlock);
const companySearch = wrapper => wrapper.findComponent(PortalGroupMemberSearch);
const individual = wrapper =>
  wrapper.findComponent(PortalGroupIndividualContacts);
const nameInput = wrapper => wrapper.findComponent(Input);
const footerButtons = wrapper =>
  wrapper
    .findAllComponents({ name: 'Button' })
    .filter(button => button.attributes('label') !== undefined);
const buttonByLabel = (wrapper, label) =>
  footerButtons(wrapper).find(button => button.attributes('label') === label);
const isSaveEnabled = wrapper =>
  buttonByLabel(wrapper, 'PORTAL_GROUPS.DETAIL.SAVE').attributes('disabled') !==
  'true';
const total = wrapper => wrapper.find('span.text-2xl').text();

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

  it('shows the saved companies with their contacts and the total calculated by the Portal', async () => {
    const wrapper = await mountPage();

    expect(blocks(wrapper)).toHaveLength(1);
    expect(blocks(wrapper)[0].props('empresa')).toEqual(acme);
    expect(total(wrapper)).toBe('PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL 3');
    expect(wrapper.text()).toContain('PORTAL_GROUPS.DETAIL.RECIPIENTS_HINT');
    expect(wrapper.text()).toContain(
      '1 PORTAL_GROUPS.DETAIL.EXCLUDED.NO_PHONE'
    );
    expect(individual(wrapper).props('rows')).toMatchObject([
      { id: 20, primary: 'Dora', active: true },
    ]);
  });

  it('shows the contacts of a company as soon as it is added, before saving', async () => {
    const wrapper = await mountPage();

    companySearch(wrapper).vm.$emit('add', 7);
    await flushPromises();

    expect(blocks(wrapper).map(block => block.props('empresa').nome)).toEqual([
      'Delta',
      'Acme',
    ]);
    expect(PortalGroupsAPI.update).not.toHaveBeenCalled();
  });

  it('estimates the total before saving without repeating a contact that is in two companies', async () => {
    const wrapper = await mountPage();

    companySearch(wrapper).vm.$emit('add', 7);
    await flushPromises();

    // Acme: Ana, Caio. Delta: Eva, Ana (repetida). Avulso: Dora. = 4
    expect(total(wrapper)).toBe('PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL 4');
    expect(wrapper.text()).toContain('PORTAL_GROUPS.DETAIL.ESTIMATE_HINT');
    expect(wrapper.text()).not.toContain('PORTAL_GROUPS.DETAIL.EXCLUDED_TITLE');
  });

  it('counts nobody from an inactive company', async () => {
    const wrapper = await mountPage();

    companySearch(wrapper).vm.$emit('add', 8);
    await flushPromises();

    expect(total(wrapper)).toBe('PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL 3');
    expect(blocks(wrapper)[0].props('empresa').active).toBe(false);
  });

  it('updates the estimate when a company is removed', async () => {
    const wrapper = await mountPage();

    blocks(wrapper)[0].vm.$emit('remove', 1);
    await flushPromises();

    expect(blocks(wrapper)).toHaveLength(0);
    // só o avulso Dora
    expect(total(wrapper)).toBe('PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL 1');
    expect(wrapper.text()).toContain('PORTAL_GROUPS.COMPANY.EMPTY');
  });

  it('adds an individual contact to the estimate only when the Portal says it receives', async () => {
    const wrapper = await mountPage();

    individual(wrapper).vm.$emit('add', 22);
    await flushPromises();
    expect(total(wrapper)).toBe('PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL 3');

    individual(wrapper).vm.$emit('add', 21);
    await flushPromises();
    expect(total(wrapper)).toBe('PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL 4');
    expect(
      individual(wrapper)
        .props('rows')
        .map(row => row.id)
    ).toEqual([21, 22, 20]);
  });

  it('keeps Save disabled while nothing changed or the name is empty', async () => {
    const wrapper = await mountPage();
    expect(isSaveEnabled(wrapper)).toBe(false);

    nameInput(wrapper).vm.$emit('update:modelValue', 'Novo nome');
    await flushPromises();
    expect(isSaveEnabled(wrapper)).toBe(true);

    nameInput(wrapper).vm.$emit('update:modelValue', '   ');
    await flushPromises();
    expect(isSaveEnabled(wrapper)).toBe(false);
  });

  it('saves everything in a single PATCH with the complete lists and goes back to the Portal numbers', async () => {
    PortalGroupsAPI.update.mockResolvedValue({
      data: {
        ...group,
        name: 'VIP 2',
        active: false,
        empresas: [delta, acme],
        recipients_count: 4,
      },
    });
    const wrapper = await mountPage();

    nameInput(wrapper).vm.$emit('update:modelValue', '  VIP 2 ');
    wrapper
      .findComponent(SettingsToggleSection)
      .vm.$emit('update:modelValue', false);
    companySearch(wrapper).vm.$emit('add', 7);
    individual(wrapper).vm.$emit('remove', 20);
    await flushPromises();
    await wrapper.vm.save();
    await flushPromises();

    expect(PortalGroupsAPI.update).toHaveBeenCalledTimes(1);
    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(3, {
      name: 'VIP 2',
      active: false,
      empresa_ids: [7, 1],
      partner_ids: [],
    });
    expect(useAlert).toHaveBeenCalledWith('PORTAL_GROUPS.DETAIL.SAVE_SUCCESS');
    expect(total(wrapper)).toBe('PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL 4');
    expect(wrapper.text()).toContain('PORTAL_GROUPS.DETAIL.RECIPIENTS_HINT');
    expect(wrapper.vm.isDirty).toBe(false);
  });

  it('sends an empty complete list when the last company is removed', async () => {
    PortalGroupsAPI.update.mockResolvedValue({ data: group });
    const wrapper = await mountPage();

    blocks(wrapper)[0].vm.$emit('remove', 1);
    await flushPromises();
    await wrapper.vm.save();

    expect(PortalGroupsAPI.update).toHaveBeenCalledWith(3, {
      name: 'Clientes VIP',
      active: true,
      empresa_ids: [],
      partner_ids: [20],
    });
  });

  it('shows the Portal errors next to Save and keeps what was typed when the name is repeated', async () => {
    PortalGroupsAPI.update.mockRejectedValue({
      response: { data: { errors: ['Nome já está em uso'] } },
    });
    const wrapper = await mountPage();

    nameInput(wrapper).vm.$emit('update:modelValue', 'Outro');
    await flushPromises();
    await wrapper.vm.save();
    await flushPromises();

    expect(wrapper.text()).toContain('Nome já está em uso');
    expect(useAlert).toHaveBeenCalledWith('Nome já está em uso');
    expect(nameInput(wrapper).props('modelValue')).toBe('Outro');
    expect(wrapper.vm.isDirty).toBe(true);
  });

  it('discards the changes and goes back to the saved group', async () => {
    const wrapper = await mountPage();

    companySearch(wrapper).vm.$emit('add', 7);
    nameInput(wrapper).vm.$emit('update:modelValue', 'Outro');
    await flushPromises();
    await buttonByLabel(wrapper, 'PORTAL_GROUPS.DETAIL.DISCARD').vm.$emit(
      'click'
    );
    await flushPromises();

    expect(blocks(wrapper)).toHaveLength(1);
    expect(nameInput(wrapper).props('modelValue')).toBe('Clientes VIP');
    expect(total(wrapper)).toBe('PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL 3');
  });

  it('is the same screen without edit controls for an agent', async () => {
    mockIsAdmin.value = false;
    const wrapper = await mountPage();

    expect(PortalGroupsAPI.memberOptions).not.toHaveBeenCalled();
    expect(blocks(wrapper)).toHaveLength(1);
    expect(blocks(wrapper)[0].props('canEdit')).toBe(false);
    expect(companySearch(wrapper).exists()).toBe(false);
    expect(nameInput(wrapper).exists()).toBe(false);
    expect(wrapper.findComponent(SettingsToggleSection).exists()).toBe(false);
    expect(wrapper.find('footer').exists()).toBe(false);
    expect(wrapper.text()).toContain('PORTAL_GROUPS.DETAIL.READ_ONLY');
    expect(wrapper.text()).toContain('Clientes VIP');
    expect(individual(wrapper).props('canEdit')).toBe(false);
  });

  it('hides the individual contacts section for an agent when there is none', async () => {
    mockIsAdmin.value = false;
    PortalGroupsAPI.show.mockResolvedValue({
      data: { ...group, contatos: [] },
    });
    const wrapper = await mountPage();

    expect(individual(wrapper).exists()).toBe(false);
  });

  it('is read only for the automatic group even for an administrator', async () => {
    PortalGroupsAPI.show.mockResolvedValue({
      data: {
        ...group,
        id: 'todos',
        automatic: true,
        empresas: [],
        contatos: [],
      },
    });
    const wrapper = await mountPage();

    expect(PortalGroupsAPI.memberOptions).not.toHaveBeenCalled();
    expect(blocks(wrapper)).toHaveLength(0);
    expect(nameInput(wrapper).exists()).toBe(false);
    expect(wrapper.find('footer').exists()).toBe(false);
    expect(wrapper.text()).toContain('PORTAL_GROUPS.DETAIL.AUTOMATIC_HINT');
  });

  it('shows the Portal message when the group cannot be loaded', async () => {
    PortalGroupsAPI.show.mockRejectedValue({
      response: { data: { error: 'Grupo não encontrado.' } },
    });
    const wrapper = await mountPage();

    expect(wrapper.text()).toContain('Grupo não encontrado.');
    expect(blocks(wrapper)).toHaveLength(0);
  });

  it('keeps the page usable when only the options fail to load', async () => {
    PortalGroupsAPI.memberOptions.mockRejectedValue({
      response: { data: { error: 'Portal fora do ar' } },
    });
    const wrapper = await mountPage();

    expect(companySearch(wrapper).props('error')).toBe('Portal fora do ar');
    expect(blocks(wrapper)).toHaveLength(1);
  });
});
