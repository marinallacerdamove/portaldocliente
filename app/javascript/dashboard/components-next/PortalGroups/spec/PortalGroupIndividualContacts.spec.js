import { shallowMount } from '@vue/test-utils';
import PortalGroupIndividualContacts from '../PortalGroupIndividualContacts.vue';
import PortalGroupMemberSearch from '../PortalGroupMemberSearch.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${params.count}` : key),
  }),
}));

const rows = [
  { id: 20, primary: 'Dora', secondary: '+5511966660000 · Zeta', active: true },
  { id: 21, primary: 'Fábio', secondary: '', active: false },
];

const mountSection = (props = {}) =>
  shallowMount(PortalGroupIndividualContacts, {
    props: {
      rows,
      candidates: [{ id: 30, primary: 'Gus', secondary: '' }],
      canEdit: true,
      ...props,
    },
  });

describe('PortalGroupIndividualContacts', () => {
  it('lists the individual contacts with a count in the discreet title', () => {
    const wrapper = mountSection();

    expect(wrapper.find('h3').text()).toBe('PORTAL_GROUPS.INDIVIDUAL.TITLE 2');
    expect(wrapper.findAll('li')).toHaveLength(2);
  });

  it('keeps the search closed behind a link until it is asked for', async () => {
    const wrapper = mountSection();

    expect(wrapper.findComponent(PortalGroupMemberSearch).exists()).toBe(false);

    await wrapper.find('button').trigger('click');

    const search = wrapper.findComponent(PortalGroupMemberSearch);
    expect(search.exists()).toBe(true);
    expect(search.props('excludedIds')).toEqual([20, 21]);
  });

  it('forwards add, remove and retry', async () => {
    const wrapper = mountSection();

    await wrapper
      .findAll('li')[0]
      .findAllComponents({ name: 'Button' })[0]
      .vm.$emit('click');
    await wrapper.find('button').trigger('click');
    wrapper.findComponent(PortalGroupMemberSearch).vm.$emit('add', 30);
    wrapper.findComponent(PortalGroupMemberSearch).vm.$emit('retry');

    expect(wrapper.emitted('remove')).toEqual([[20]]);
    expect(wrapper.emitted('add')).toEqual([[30]]);
    expect(wrapper.emitted('retry')).toHaveLength(1);
  });

  it('has no remove button and no add link when the user cannot edit', () => {
    const wrapper = mountSection({ canEdit: false });

    expect(wrapper.findAllComponents({ name: 'Button' })).toHaveLength(0);
    expect(wrapper.find('button').exists()).toBe(false);
    expect(wrapper.findAll('li')).toHaveLength(2);
  });
});
