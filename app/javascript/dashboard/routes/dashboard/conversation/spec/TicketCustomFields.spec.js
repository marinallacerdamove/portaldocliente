import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import TicketCustomFields from '../TicketCustomFields.vue';

const testState = vi.hoisted(() => ({ refs: {} }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  testState.refs.currentChat = ref({ id: 1 });
  return { useMapGetter: () => testState.refs.currentChat };
});
vi.mock('dashboard/composables/useConversationCustomFields', async () => {
  const { ref } = await import('vue');
  testState.refs.values = ref({});
  return {
    useConversationCustomFields: () => ({
      items: ref([]),
      values: testState.refs.values,
      load: vi.fn(),
      saveValue: vi.fn(),
    }),
  };
});

describe('TicketCustomFields drafts', () => {
  let wrapper;

  beforeEach(() => {
    testState.refs.currentChat.value = { id: 1 };
    testState.refs.values.value = { causa: 'Bug', observacao: 'antiga' };
    wrapper = shallowMount(TicketCustomFields);
  });

  // Regressão B232: o rascunho de texto/data se perdia quando outro campo da
  // mesma conversa era atualizado em tempo real.
  it('starts from the saved values', () => {
    expect(wrapper.vm.drafts).toEqual({ causa: 'Bug', observacao: 'antiga' });
  });

  it('keeps what the agent is typing when another field is updated in real time', async () => {
    wrapper.vm.drafts.observacao = 'texto ainda sendo digitado';

    testState.refs.values.value = { causa: 'Infra', observacao: 'antiga' };
    await nextTick();

    expect(wrapper.vm.drafts.causa).toBe('Infra');
    expect(wrapper.vm.drafts.observacao).toBe('texto ainda sendo digitado');
  });

  it('takes the real-time value of the field that really changed', async () => {
    wrapper.vm.drafts.observacao = 'rascunho';

    testState.refs.values.value = {
      causa: 'Bug',
      observacao: 'nova do servidor',
    };
    await nextTick();

    expect(wrapper.vm.drafts.observacao).toBe('nova do servidor');
  });

  it('starts over from the saved values when the agent changes conversation', async () => {
    wrapper.vm.drafts.observacao = 'rascunho da conversa 1';

    testState.refs.values.value = { causa: 'Outra' };
    testState.refs.currentChat.value = { id: 2 };
    await nextTick();

    expect(wrapper.vm.drafts).toEqual({ causa: 'Outra' });
  });
});
