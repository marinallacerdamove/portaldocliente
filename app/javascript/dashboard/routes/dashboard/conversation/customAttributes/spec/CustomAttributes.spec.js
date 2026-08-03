import { shallowMount } from '@vue/test-utils';
import CustomAttributes from '../CustomAttributes.vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';

vi.mock('dashboard/composables/store');
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: {} }),
}));

const attributeDefinitions = [
  { id: 1, attribute_key: 'issue_jira', attribute_display_type: 'text' },
  { id: 2, attribute_key: 'categoria', attribute_display_type: 'text' },
  { id: 3, attribute_key: 'liberacoes', attribute_display_type: 'text' },
  { id: 4, attribute_key: 'not_curated', attribute_display_type: 'text' },
];

const mountComponent = props => {
  const store = { dispatch: vi.fn(), getters: {} };
  const getters = {
    getSelectedChat: { value: { id: 1, custom_attributes: {} } },
    getUISettings: { value: {} },
    'attributes/getAttributesByModel': { value: () => attributeDefinitions },
    'contacts/getContact': { value: () => ({ custom_attributes: {} }) },
  };
  useStore.mockReturnValue(store);
  useStoreGetters.mockReturnValue(getters);

  return shallowMount(CustomAttributes, {
    props: { attributeFrom: 'test', ...props },
  });
};

const draggableList = wrapper =>
  wrapper.findComponent({ name: 'draggable' }).props('list');

describe('CustomAttributes', () => {
  it('shows every attribute in store order when includeKeys/excludeKeys are unset', () => {
    const wrapper = mountComponent();

    expect(draggableList(wrapper).map(el => el.key)).toEqual([
      'issue_jira',
      'categoria',
      'liberacoes',
      'not_curated',
    ]);
  });

  it('filters to and reorders by includeKeys, ignoring any saved drag order', () => {
    const wrapper = mountComponent({
      includeKeys: ['categoria', 'liberacoes', 'issue_jira'],
    });

    expect(draggableList(wrapper).map(el => el.key)).toEqual([
      'categoria',
      'liberacoes',
      'issue_jira',
    ]);
  });

  it('hides attributes listed in excludeKeys', () => {
    const wrapper = mountComponent({ excludeKeys: ['not_curated'] });

    expect(draggableList(wrapper).map(el => el.key)).toEqual([
      'issue_jira',
      'categoria',
      'liberacoes',
    ]);
  });

  it('prefers includeKeys over excludeKeys when both are passed', () => {
    const wrapper = mountComponent({
      includeKeys: ['liberacoes'],
      excludeKeys: ['liberacoes'],
    });

    expect(draggableList(wrapper).map(el => el.key)).toEqual(['liberacoes']);
  });
});
