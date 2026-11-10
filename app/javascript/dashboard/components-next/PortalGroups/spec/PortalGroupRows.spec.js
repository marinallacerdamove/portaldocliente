import { mount } from '@vue/test-utils';
import PortalGroupCompanyRow from '../PortalGroupCompanyRow.vue';
import PortalGroupContactRow from '../PortalGroupContactRow.vue';
import PortalGroupContactStatusBadge from '../PortalGroupContactStatusBadge.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

const global = { stubs: { Avatar: true } };

const acme = {
  id: 1,
  nome: 'Acme',
  cnpj: '11.222.333/0001-81',
  active: true,
  contatos_count: 2,
  recebem_count: 1,
  contatos: [
    { id: 9, name: 'Ana', phone: '+5511999990000', status: 'recebe' },
    { id: 10, name: 'Beto', phone: null, status: 'sem_telefone' },
  ],
};

describe('PortalGroupCompanyRow', () => {
  const mountRow = props =>
    mount(PortalGroupCompanyRow, {
      props: { empresa: acme, ...props },
      global,
    });

  it('shows how many receive when the company is in the group', () => {
    const wrapper = mountRow({ checked: true, canEdit: true });

    expect(wrapper.text()).toContain('Acme');
    expect(wrapper.text()).toContain('11.222.333/0001-81');
    expect(wrapper.text()).toContain(
      'PORTAL_GROUPS.COMPANY.RECEIVE_OF {"receive":1,"total":2}'
    );
  });

  it('shows only how many contacts it has when it is out of the group', () => {
    const wrapper = mountRow({ checked: false, canEdit: true });

    expect(wrapper.text()).toContain(
      'PORTAL_GROUPS.COMPANY.CONTACTS {"count":2}'
    );
  });

  it('marks an inactive company', () => {
    const wrapper = mountRow({ empresa: { ...acme, active: false } });

    expect(wrapper.text()).toContain('PORTAL_GROUPS.COMPANY.INACTIVE');
  });

  it('asks to open when the row is clicked and lists the contacts when open', async () => {
    const wrapper = mountRow({ checked: true, canEdit: true });
    expect(wrapper.findAllComponents(PortalGroupContactRow)).toHaveLength(0);

    await wrapper.find('[role="button"]').trigger('click');
    expect(wrapper.emitted('expand')).toEqual([[1]]);
    expect(wrapper.emitted('toggle')).toBeUndefined();

    await wrapper.setProps({ expanded: true });
    const rows = wrapper.findAllComponents(PortalGroupContactRow);
    expect(rows.map(row => row.props('contato').name)).toEqual(['Ana', 'Beto']);
    expect(rows.every(row => row.props('nested'))).toBe(true);
    expect(rows.every(row => !row.props('canEdit'))).toBe(true);
  });

  it('says when an open company has no contacts', async () => {
    const wrapper = mountRow({
      empresa: { ...acme, contatos: [], contatos_count: 0, recebem_count: 0 },
      expanded: true,
    });

    expect(wrapper.text()).toContain('PORTAL_GROUPS.COMPANY.NO_CONTACTS');
  });

  it('toggles from the box without opening the row', async () => {
    const wrapper = mountRow({ checked: true, canEdit: true });

    await wrapper.find('input[type="checkbox"]').trigger('change');
    await wrapper.find('input[type="checkbox"]').trigger('click');

    expect(wrapper.emitted('toggle')).toEqual([[1]]);
    expect(wrapper.emitted('expand')).toBeUndefined();
  });

  it('has no box when it cannot edit', () => {
    const wrapper = mountRow({ checked: true, canEdit: false });

    expect(wrapper.find('input[type="checkbox"]').exists()).toBe(false);
  });
});

describe('PortalGroupContactRow', () => {
  const dora = {
    id: 20,
    name: 'Dora',
    phone: '+5511966660000',
    status: 'recebe',
  };
  const mountRow = props =>
    mount(PortalGroupContactRow, {
      props: { contato: dora, ...props },
      global,
    });

  it('shows name, subtitle, phone and the situation from the Portal', () => {
    const wrapper = mountRow({ subtitle: 'Zeta' });

    expect(wrapper.text()).toContain('Dora');
    expect(wrapper.text()).toContain('Zeta');
    expect(wrapper.text()).toContain('+5511966660000');
    expect(
      wrapper.findComponent(PortalGroupContactStatusBadge).props('status')
    ).toBe('recebe');
  });

  it('shows a dash instead of repeating "no phone"', () => {
    const wrapper = mountRow({
      contato: { ...dora, phone: null, status: 'sem_telefone' },
    });

    expect(wrapper.text()).toContain('—');
  });

  it('toggles from the row or the box when it can edit', async () => {
    const wrapper = mountRow({ canEdit: true });

    await wrapper.trigger('click');
    await wrapper.find('input[type="checkbox"]').trigger('change');

    expect(wrapper.emitted('toggle')).toEqual([[20], [20]]);
  });

  it('does nothing on click and has no box when it cannot edit', async () => {
    const wrapper = mountRow({ canEdit: false });

    await wrapper.trigger('click');

    expect(wrapper.find('input[type="checkbox"]').exists()).toBe(false);
    expect(wrapper.emitted('toggle')).toBeUndefined();
  });
});
