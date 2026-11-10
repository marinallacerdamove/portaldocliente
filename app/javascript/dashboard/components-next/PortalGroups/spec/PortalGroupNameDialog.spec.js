import { shallowMount } from '@vue/test-utils';
import PortalGroupNameDialog from '../PortalGroupNameDialog.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const DialogStub = {
  name: 'Dialog',
  props: ['disableConfirmButton'],
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /></div>',
};

const mountDialog = () =>
  shallowMount(PortalGroupNameDialog, {
    global: { stubs: { Dialog: DialogStub } },
  });

describe('PortalGroupNameDialog', () => {
  it('opens with the name and status of the group', () => {
    const wrapper = mountDialog();

    wrapper.vm.open({ name: 'Clientes VIP', active: false });

    expect(wrapper.vm.name).toBe('Clientes VIP');
    expect(wrapper.vm.active).toBe(false);
  });

  it('submits the trimmed name and the status', () => {
    const wrapper = mountDialog();
    wrapper.vm.open({ name: 'Clientes VIP', active: true });
    wrapper.vm.name = '  VIP 2  ';
    wrapper.vm.active = false;

    wrapper.findComponent(DialogStub).vm.$emit('confirm');

    expect(wrapper.emitted('submit')).toEqual([
      [{ name: 'VIP 2', active: false }],
    ]);
  });

  it('does not submit an empty name and blocks the confirm button', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open({ name: 'Clientes VIP', active: true });
    wrapper.vm.name = '   ';
    await wrapper.vm.$nextTick();

    wrapper.findComponent(DialogStub).vm.$emit('confirm');

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(
      wrapper.findComponent(DialogStub).props('disableConfirmButton')
    ).toBe(true);
  });
});
