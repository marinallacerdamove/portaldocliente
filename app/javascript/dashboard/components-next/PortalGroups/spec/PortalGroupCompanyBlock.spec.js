import { mount } from '@vue/test-utils';
import PortalGroupCompanyBlock from '../PortalGroupCompanyBlock.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

const empresa = {
  id: 1,
  nome: 'Acme',
  cnpj: '11.222.333/0001-81',
  active: true,
  contatos_count: 4,
  recebem_count: 1,
  contatos: [
    { id: 9, name: 'Ana', phone: '+5511999990000', status: 'recebe' },
    { id: 10, name: 'Beto', phone: '+5511999991111', status: 'inativos' },
    { id: 11, name: 'Caio', phone: null, status: 'sem_telefone' },
    {
      id: 12,
      name: 'Dani',
      phone: '+5511999992222',
      status: 'sem_contato_no_chatwoot',
    },
  ],
};

const mountBlock = (props = {}) =>
  mount(PortalGroupCompanyBlock, {
    props: { empresa, canEdit: true, ...props },
  });

describe('PortalGroupCompanyBlock', () => {
  it('shows the company, how many of its contacts receive and its CNPJ', () => {
    const wrapper = mountBlock();

    expect(wrapper.find('h3').text()).toBe('Acme');
    expect(wrapper.text()).toContain('11.222.333/0001-81');
    expect(wrapper.text()).toContain('"receive":1,"total":4');
  });

  it('lists every contact with its phone and its situation', () => {
    const items = mountBlock().findAll('li');

    expect(items).toHaveLength(4);
    expect(items[0].text()).toContain('Ana');
    expect(items[0].text()).toContain('+5511999990000');
    expect(items.map(item => item.text())).toEqual([
      expect.stringContaining('PORTAL_GROUPS.CONTACT_STATUS.RECEIVES'),
      expect.stringContaining('PORTAL_GROUPS.CONTACT_STATUS.INACTIVE'),
      expect.stringContaining('PORTAL_GROUPS.CONTACT_STATUS.NO_PHONE'),
      expect.stringContaining('PORTAL_GROUPS.CONTACT_STATUS.NO_CHATWOOT'),
    ]);
    expect(items[2].text()).toContain('PORTAL_GROUPS.COMPANY.NO_PHONE');
  });

  it('marks an inactive company', () => {
    const wrapper = mountBlock({ empresa: { ...empresa, active: false } });

    expect(wrapper.text()).toContain('PORTAL_GROUPS.COMPANY.INACTIVE');
    expect(mountBlock().text()).not.toContain('PORTAL_GROUPS.COMPANY.INACTIVE');
  });

  it('asks to remove the company', async () => {
    const wrapper = mountBlock();

    await wrapper.find('header button').trigger('click');

    expect(wrapper.emitted('remove')).toEqual([[1]]);
  });

  it('has no remove button when the user cannot edit', () => {
    expect(mountBlock({ canEdit: false }).find('header button').exists()).toBe(
      false
    );
  });

  it('says when the company has no contacts', () => {
    const wrapper = mountBlock({
      empresa: {
        ...empresa,
        contatos: [],
        contatos_count: 0,
        recebem_count: 0,
      },
    });

    expect(wrapper.text()).toContain('PORTAL_GROUPS.COMPANY.NO_CONTACTS');
  });
});
