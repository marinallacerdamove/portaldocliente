import { shallowMount } from '@vue/test-utils';
import PropertyPanel from '../PropertyPanel.vue';
import AskAndExtractPanel from '../panels/AskAndExtractPanel.vue';
import { BOT_FLOW_NODE_TYPES } from 'dashboard/helper/botFlowHelper';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('../composables/useVariableRegistry', async () => {
  const { ref } = await import('vue');
  return {
    useVariableRegistry: () => ({
      catalog: ref([]),
      recentIds: ref([]),
      recordUsage: vi.fn(),
    }),
  };
});

const askNode = (id, data) => ({
  id,
  type: BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT,
  data,
});

describe('bot flow PropertyPanel', () => {
  // Regressão B230: o painel de propriedades não era recriado a cada bloco, e o
  // estado do bloco anterior vazava para o seguinte (blocos antigos perdiam o
  // nome da variável).
  it('recreates the panel of the block when another block of the same type is selected', async () => {
    const first = askNode('a', {
      variable_label: 'Nome',
      variable_name: 'nome',
    });
    const second = askNode('b', { variable_name: 'cpf_cliente' });
    const wrapper = shallowMount(PropertyPanel, {
      props: { node: first, nodes: [first, second], edges: [] },
    });
    const firstInstance = wrapper.findComponent(AskAndExtractPanel).vm.$.uid;

    await wrapper.setProps({ node: second });

    const secondPanel = wrapper.findComponent(AskAndExtractPanel);
    expect(secondPanel.vm.$.uid).not.toBe(firstInstance);
    expect(secondPanel.props('modelValue')).toEqual(second.data);
    expect(second.data.variable_name).toBe('cpf_cliente');
  });
});
