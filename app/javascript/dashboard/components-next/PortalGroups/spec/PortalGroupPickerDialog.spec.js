import { mount } from '@vue/test-utils';
import PortalGroupPickerDialog from '../PortalGroupPickerDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

const DialogStub = {
  name: 'Dialog',
  props: ['disableConfirmButton', 'isLoading'],
  emits: ['confirm'],
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /></div>',
};

const items = [
  { id: 1, title: 'Acme', subtitle: '11.222', info: '2 contatos' },
  { id: 2, title: 'Delta', subtitle: '55.666', info: '1 contato' },
  { id: 3, title: 'Omega', subtitle: '', info: '' },
];

const mountDialog = props =>
  mount(PortalGroupPickerDialog, {
    props: { title: 'T', confirmLabel: 'Salvar', items, ...props },
    global: { stubs: { Dialog: DialogStub, Avatar: true } },
  });

const boxes = wrapper => wrapper.findAll('input[type="checkbox"]');
const selectAll = wrapper => boxes(wrapper)[0];
const rowBoxes = wrapper => boxes(wrapper).slice(1);
const search = async (wrapper, term) => {
  wrapper.findComponent({ name: 'Input' }).vm.$emit('update:modelValue', term);
  await wrapper.vm.$nextTick();
};
const confirm = async wrapper => {
  wrapper.findComponent(DialogStub).vm.$emit('confirm');
  await wrapper.vm.$nextTick();
  return wrapper.emitted('confirm')?.at(-1)?.[0];
};

describe('PortalGroupPickerDialog', () => {
  it('opens with only what is already in the group checked', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open([2]);
    await wrapper.vm.$nextTick();

    expect(rowBoxes(wrapper).map(box => box.element.checked)).toEqual([
      false,
      true,
      false,
    ]);
    expect(wrapper.text()).toContain(
      'PORTAL_GROUPS.PICKER.SELECTED {"count":1}'
    );
    expect(await confirm(wrapper)).toEqual([2]);
  });

  it('selects all and then clears all', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open([]);
    await wrapper.vm.$nextTick();

    await selectAll(wrapper).trigger('change');
    expect(rowBoxes(wrapper).every(box => box.element.checked)).toBe(true);
    expect((await confirm(wrapper)).sort()).toEqual([1, 2, 3]);

    await selectAll(wrapper).trigger('change');
    expect(await confirm(wrapper)).toEqual([]);
  });

  it('marks select all as partial when only some are checked', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open([1]);
    await wrapper.vm.$nextTick();

    expect(selectAll(wrapper).element.indeterminate).toBe(true);
    expect(selectAll(wrapper).element.checked).toBe(false);
  });

  it('select all only touches what the search shows and keeps the rest', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open([3]);
    await wrapper.vm.$nextTick();

    await search(wrapper, 'delta');
    expect(rowBoxes(wrapper)).toHaveLength(1);
    await selectAll(wrapper).trigger('change');

    expect((await confirm(wrapper)).sort()).toEqual([2, 3]);
  });

  it('toggles one row', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open([1]);
    await wrapper.vm.$nextTick();

    await rowBoxes(wrapper)[0].trigger('change');
    await rowBoxes(wrapper)[2].trigger('change');

    expect(await confirm(wrapper)).toEqual([3]);
  });

  it('says nothing was found for a search with no match', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open([]);
    await search(wrapper, 'zzz');

    expect(wrapper.text()).toContain('PORTAL_GROUPS.PICKER.NO_MATCH');
    expect(selectAll(wrapper).element.disabled).toBe(true);
  });

  it('starts clean every time it opens', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open([1]);
    await search(wrapper, 'delta');
    wrapper.vm.open([2]);
    await wrapper.vm.$nextTick();

    expect(rowBoxes(wrapper)).toHaveLength(3);
    expect(await confirm(wrapper)).toEqual([2]);
  });

  it('does not confirm when it cannot', async () => {
    const wrapper = mountDialog({ canConfirm: false });
    wrapper.vm.open([1]);

    expect(
      wrapper.findComponent(DialogStub).props('disableConfirmButton')
    ).toBe(true);
    expect(await confirm(wrapper)).toBeUndefined();
  });

  it('shows loading and errors of the list with a retry', async () => {
    const loading = mountDialog({ isLoadingItems: true });
    expect(loading.text()).toContain('PORTAL_GROUPS.PICKER.LOADING');
    expect(boxes(loading)).toHaveLength(0);

    const failed = mountDialog({ itemsError: 'Portal fora do ar' });
    expect(failed.text()).toContain('Portal fora do ar');
    await failed.findComponent({ name: 'Button' }).trigger('click');
    expect(failed.emitted('retry')).toHaveLength(1);
  });
});
