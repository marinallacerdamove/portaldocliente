import { mount } from '@vue/test-utils';
import PortalGroupMemberSearch from '../PortalGroupMemberSearch.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const candidates = [
  { id: 1, primary: 'Acme', secondary: '11222333000181' },
  { id: 7, primary: 'Delta Sistemas', secondary: '55666777000122' },
  { id: 8, primary: 'Delfos', secondary: '99888777000133' },
];

const mountSearch = (props = {}) =>
  mount(PortalGroupMemberSearch, {
    props: { candidates, excludedIds: [1], ...props },
    global: {
      stubs: {
        Input: {
          props: ['modelValue', 'size', 'type', 'placeholder', 'disabled'],
          emits: ['update:modelValue'],
          template:
            '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
        },
      },
    },
  });

const search = (wrapper, term) => wrapper.find('input').setValue(term);

describe('PortalGroupMemberSearch', () => {
  it('suggests candidates by the search, never the ones already in the group', async () => {
    const wrapper = mountSearch();

    await search(wrapper, 'de');
    const texts = wrapper.findAll('li').map(li => li.text());

    expect(texts).toHaveLength(2);
    expect(texts.join(' ')).toContain('Delta Sistemas');
    expect(texts.join(' ')).toContain('Delfos');

    await search(wrapper, 'acme');
    expect(wrapper.text()).toContain('PORTAL_GROUPS.SEARCH.NO_MATCH');
  });

  it('finds a candidate by its secondary text (CNPJ, e-mail or phone)', async () => {
    const wrapper = mountSearch();

    await search(wrapper, '55666777');

    expect(wrapper.findAll('li')).toHaveLength(1);
  });

  it('shows nothing until something is typed', () => {
    expect(mountSearch().findAll('li')).toHaveLength(0);
  });

  it('asks to add the chosen candidate and clears the search', async () => {
    const wrapper = mountSearch();

    await search(wrapper, 'delta');
    await wrapper.find('li button').trigger('click');

    expect(wrapper.emitted('add')).toEqual([[7]]);
    expect(wrapper.find('input').element.value).toBe('');
  });

  it('shows the loading and the error with retry', async () => {
    expect(mountSearch({ isLoading: true }).text()).toContain(
      'PORTAL_GROUPS.SEARCH.LOADING'
    );

    const failed = mountSearch({ error: 'Portal fora do ar' });
    expect(failed.text()).toContain('Portal fora do ar');
    await failed
      .findAll('button')
      .find(button => button.text() === 'PORTAL_GROUPS.RETRY')
      .trigger('click');
    expect(failed.emitted('retry')).toHaveLength(1);
  });
});
