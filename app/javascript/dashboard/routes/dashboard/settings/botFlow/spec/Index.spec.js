import { mount, flushPromises } from '@vue/test-utils';
import BotFlowList from '../Index.vue';

const testState = vi.hoisted(() => ({ getters: {}, dispatch: vi.fn() }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useStore: () => ({ dispatch: testState.dispatch }),
    useMapGetter: key => computed(() => testState.getters[key]),
    useStoreGetters: () => ({
      'botFlows/getUIFlags': computed(() => testState.getters.uiFlags),
      getCurrentRole: computed(() => 'administrator'),
    }),
  };
});

const SettingsLayoutStub = {
  template: '<div><slot name="body" /></div>',
};

describe('bot flow list', () => {
  // Regressão B229: a chave "Ativo" da lista mandava o valor antigo (o
  // v-model alterava o fluxo antes do clique ser tratado).
  it('sends the new active value when the switch is clicked', async () => {
    const flow = {
      id: 7,
      name: 'Atendimento',
      active: true,
      trigger_type: 'conversation_created',
      inbox_ids: [],
    };
    testState.getters = {
      'botFlows/getBotFlows': [flow],
      'inboxes/getInboxes': [{ id: 1, name: 'WhatsApp' }],
      uiFlags: { isFetching: false },
    };
    const wrapper = mount(BotFlowList, {
      global: {
        stubs: {
          SettingsLayout: SettingsLayoutStub,
          BaseSettingsHeader: true,
          RouterLink: true,
          'woot-confirm-delete-modal': true,
        },
      },
    });
    testState.dispatch.mockClear();

    await wrapper.find('button[role="switch"]').trigger('click');
    await flushPromises();

    expect(testState.dispatch).toHaveBeenCalledWith('botFlows/update', {
      id: 7,
      active: false,
    });
  });
});
