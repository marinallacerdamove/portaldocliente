import { mount } from '@vue/test-utils';
import PortalGroupContactsPanel from '../PortalGroupContactsPanel.vue';
import PortalGroupContactStatusBadge from '../PortalGroupContactStatusBadge.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

const group = {
  id: 3,
  automatic: false,
  empresas: [
    {
      id: 1,
      nome: 'Acme',
      contatos: [
        { id: 9, name: 'Ana', phone: '+551199', status: 'recebe' },
        { id: 10, name: 'Beto', phone: null, status: 'sem_telefone' },
      ],
    },
    {
      id: 8,
      nome: 'Omega',
      contatos: [{ id: 9, name: 'Ana', phone: '+551199', status: 'inativos' }],
    },
  ],
  contatos: [
    { id: 20, name: 'Caio', phone: '+551188', status: 'recebe', empresas: [] },
  ],
};

const mountPanel = props =>
  mount(PortalGroupContactsPanel, {
    props: { group, canEdit: true, ...props },
    global: { stubs: { Avatar: true } },
  });

const rows = wrapper => wrapper.findAll('li');
const names = wrapper => rows(wrapper).map(row => row.find('span').text());
const buttonByLabel = (wrapper, label) =>
  wrapper
    .findAllComponents({ name: 'Button' })
    .find(button => button.props('label') === label);

describe('PortalGroupContactsPanel', () => {
  it('lists each contact once by name, with their companies and the best situation', () => {
    const wrapper = mountPanel();

    expect(names(wrapper)).toEqual(['Ana', 'Beto', 'Caio']);
    expect(rows(wrapper)[0].text()).toContain('Acme, Omega');
    expect(
      rows(wrapper)[0]
        .findComponent(PortalGroupContactStatusBadge)
        .props('status')
    ).toBe('recebe');
    expect(rows(wrapper)[1].text()).toContain('—');
    expect(rows(wrapper)[2].text()).toContain('PORTAL_GROUPS.PANEL.INDIVIDUAL');
  });

  it('shows the linked companies', () => {
    expect(mountPanel().text()).toContain(
      'PORTAL_GROUPS.PANEL.COMPANIES {"names":"Acme, Omega"}'
    );
  });

  it('has the remove button only on individual contacts', async () => {
    const wrapper = mountPanel();

    expect(rows(wrapper)[0].findAllComponents({ name: 'Button' })).toHaveLength(
      0
    );
    await rows(wrapper)[2].findComponent({ name: 'Button' }).trigger('click');

    expect(wrapper.emitted('removeContact')).toEqual([[20]]);
  });

  it('asks to link companies and add contacts', async () => {
    const wrapper = mountPanel();

    await buttonByLabel(wrapper, 'PORTAL_GROUPS.PANEL.LINK_COMPANIES').trigger(
      'click'
    );
    await buttonByLabel(wrapper, 'PORTAL_GROUPS.PANEL.ADD_CONTACTS').trigger(
      'click'
    );

    expect(wrapper.emitted('linkCompanies')).toHaveLength(1);
    expect(wrapper.emitted('addContacts')).toHaveLength(1);
  });

  it('has no edit controls when it cannot edit', () => {
    const wrapper = mountPanel({ canEdit: false });

    expect(wrapper.findAllComponents({ name: 'Button' })).toHaveLength(0);
  });

  it('says how to start when the group is empty', () => {
    const wrapper = mountPanel({
      group: { ...group, empresas: [], contatos: [] },
    });

    expect(wrapper.text()).toContain('PORTAL_GROUPS.PANEL.EMPTY');
    expect(wrapper.text()).toContain('PORTAL_GROUPS.PANEL.NO_COMPANIES');
  });

  it('lists who receives in the automatic group, without edit controls', () => {
    const wrapper = mountPanel({
      canEdit: false,
      group: {
        id: 'todos',
        automatic: true,
        recipients: [
          { partner_id: 5, name: 'Zé', phone: '+5511', chatwoot_contact_id: 1 },
          {
            partner_id: 4,
            name: 'Bia',
            phone: '+5512',
            chatwoot_contact_id: 2,
          },
        ],
      },
    });

    expect(names(wrapper)).toEqual(['Bia', 'Zé']);
    expect(wrapper.text()).not.toContain('PORTAL_GROUPS.PANEL.LINK_COMPANIES');
  });
});
