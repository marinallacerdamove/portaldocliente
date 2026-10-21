import { shallowMount, flushPromises } from '@vue/test-utils';
import Editor from '../Index.vue';
import { BOT_FLOW_NODE_TYPES } from 'dashboard/helper/botFlowHelper';

const testState = vi.hoisted(() => ({ getters: {} }));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: {} }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useStore: () => ({ dispatch: vi.fn(), getters: {} }),
    useMapGetter: key => computed(() => testState.getters[key] ?? []),
  };
});

let wrapper;

const mountEditor = async () => {
  wrapper = shallowMount(Editor);
  await flushPromises();
};

const pressKey = key =>
  window.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true }));

describe('bot flow Editor', () => {
  afterEach(() => wrapper.unmount());

  // Regressão B219: adicionar/desfazer/organizar/excluir bloco quebravam
  // porque o histórico fazia structuredClone em objetos reativos do Vue.
  describe('history of structural changes', () => {
    it('adds a block and undoes/redoes it without crashing on reactive objects', async () => {
      await mountEditor();
      expect(wrapper.vm.nodes).toHaveLength(1);

      wrapper.vm.addNode({ id: BOT_FLOW_NODE_TYPES.SEND_MESSAGE });
      expect(wrapper.vm.nodes).toHaveLength(2);

      wrapper.vm.undo();
      expect(wrapper.vm.nodes).toHaveLength(1);

      wrapper.vm.redo();
      expect(wrapper.vm.nodes).toHaveLength(2);
      expect(wrapper.vm.nodes[1].type).toBe(BOT_FLOW_NODE_TYPES.SEND_MESSAGE);
    });

    it('organizes the layout and removes a selected block, both undoable', async () => {
      await mountEditor();
      wrapper.vm.addNode({ id: BOT_FLOW_NODE_TYPES.SEND_MESSAGE });

      wrapper.vm.organizeLayout();
      expect(wrapper.vm.undoStack).toHaveLength(2);

      wrapper.vm.selectedNodeId = wrapper.vm.nodes[1].id;
      wrapper.vm.removeSelectedNode();
      expect(wrapper.vm.nodes).toHaveLength(1);

      wrapper.vm.undo();
      expect(wrapper.vm.nodes).toHaveLength(2);
    });

    it('duplicates a block copying its data', async () => {
      await mountEditor();
      wrapper.vm.addNode({ id: BOT_FLOW_NODE_TYPES.SEND_MESSAGE });
      const [, original] = wrapper.vm.nodes;
      original.data.message = 'Olá';
      wrapper.vm.selectedNodeId = original.id;

      wrapper.vm.duplicateSelectedNode();

      expect(wrapper.vm.nodes).toHaveLength(3);
      const copy = wrapper.vm.nodes[2];
      expect(copy.id).not.toBe(original.id);
      expect(copy.data).toEqual(original.data);
      expect(copy.data).not.toBe(original.data);
    });
  });

  // Regressão B220: a tecla Delete não removia a conexão (linha) selecionada.
  describe('Delete key', () => {
    it('removes the selected connection and keeps the blocks', async () => {
      await mountEditor();
      wrapper.vm.addNode({ id: BOT_FLOW_NODE_TYPES.SEND_MESSAGE });
      const [start, message] = wrapper.vm.nodes;
      wrapper.vm.edges = [
        { id: 'e1', source: start.id, target: message.id, selected: true },
        { id: 'e2', source: message.id, target: start.id },
      ];

      pressKey('Delete');

      expect(wrapper.vm.edges.map(edge => edge.id)).toEqual(['e2']);
      expect(wrapper.vm.nodes).toHaveLength(2);
    });

    it('removes the selected block when no connection is selected', async () => {
      await mountEditor();
      wrapper.vm.addNode({ id: BOT_FLOW_NODE_TYPES.SEND_MESSAGE });
      wrapper.vm.selectedNodeId = wrapper.vm.nodes[1].id;

      pressKey('Delete');

      expect(wrapper.vm.nodes).toHaveLength(1);
    });
  });
});
