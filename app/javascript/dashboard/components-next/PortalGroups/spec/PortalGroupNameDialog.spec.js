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
    props: { title: 'Novo grupo', confirmLabel: 'Criar' },
    global: { stubs: { Dialog: DialogStub } },
  });

describe('PortalGroupNameDialog', () => {
  it('opens with an empty name', () => {
    const wrapper = mountDialog();
    wrapper.vm.name = 'sobra de antes';

    wrapper.vm.open();

    expect(wrapper.vm.name).toBe('');
  });

  it('submits the trimmed name', () => {
    const wrapper = mountDialog();
    wrapper.vm.open();
    wrapper.vm.name = '  Clientes VIP  ';

    wrapper.findComponent(DialogStub).vm.$emit('confirm');

    expect(wrapper.emitted('submit')).toEqual([['Clientes VIP']]);
  });

  it('does not submit an empty name and blocks the confirm button', () => {
    const wrapper = mountDialog();
    wrapper.vm.open();
    wrapper.vm.name = '   ';

    wrapper.findComponent(DialogStub).vm.$emit('confirm');

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(
      wrapper.findComponent(DialogStub).props('disableConfirmButton')
    ).toBe(true);
  });
});
