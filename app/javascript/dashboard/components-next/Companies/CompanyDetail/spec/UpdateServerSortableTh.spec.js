import { mount } from '@vue/test-utils';
import UpdateServerSortableTh from '../UpdateServerSortableTh.vue';

const mountTh = props =>
  mount(UpdateServerSortableTh, {
    props: { label: 'ID', sortKey: 'id', ...props },
    attachTo: document.createElement('tr'),
  });

describe('UpdateServerSortableTh', () => {
  it('aligns a numeric column to the end and a text column to the start', () => {
    expect(mountTh({ numeric: true }).find('th').classes()).toContain(
      'ltr:text-right'
    );
    expect(mountTh().find('th').classes()).toContain('text-left');
  });

  it('reports the sort state and emits the key on click', async () => {
    const wrapper = mountTh({ activeKey: 'id', direction: 'desc' });

    expect(wrapper.find('th').attributes('aria-sort')).toBe('descending');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('sort')[0]).toEqual(['id']);
  });
});
