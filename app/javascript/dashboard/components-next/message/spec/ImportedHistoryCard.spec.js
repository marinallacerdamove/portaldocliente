import { shallowMount } from '@vue/test-utils';
import ImportedHistoryCard from '../ImportedHistoryCard.vue';

const testState = vi.hoisted(() => ({ context: {} }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useMessageEditing', async () => {
  const { ref } = await import('vue');
  return {
    useMessageEditing: () => ({
      editingMessage: ref(null),
      startEditing: vi.fn(),
    }),
  };
});
vi.mock('../provider.js', async () => {
  const { ref } = await import('vue');
  return {
    useMessageContext: () =>
      Object.fromEntries(
        Object.entries(testState.context).map(([key, value]) => [
          key,
          ref(value),
        ])
      ),
  };
});

const baseContext = {
  id: 1,
  content: 'Texto importado',
  attachments: [],
  contentAttributes: {},
  sender: { name: 'Ana' },
  messageType: 1,
  private: false,
  createdAt: 1700000000,
  conversationId: 9,
  isAdmin: false,
  isOwnMessage: false,
  isMessageDeleted: false,
};

const hasEditPencil = context => {
  testState.context = { ...baseContext, ...context };
  const wrapper = shallowMount(ImportedHistoryCard, {
    global: { mocks: { $t: key => key } },
  });
  return wrapper.find('button').exists();
};

// Regressão B235: o lápis de editar da mensagem importada seguia a regra de
// permissão errada (aparecia para quem não é admin nem autor, e em mensagem
// apagada). Regra certa: só saída (agente/nota), admin ou autor, não apagada.
describe('ImportedHistoryCard edit pencil', () => {
  it('shows for the administrator on an agent message', () => {
    expect(hasEditPencil({ isAdmin: true })).toBe(true);
  });

  it('shows for the author of the message', () => {
    expect(hasEditPencil({ isOwnMessage: true })).toBe(true);
  });

  it('shows on an internal note of the author', () => {
    expect(hasEditPencil({ isOwnMessage: true, private: true })).toBe(true);
  });

  it('does not show for someone who is neither admin nor author', () => {
    expect(hasEditPencil({ isAdmin: false, isOwnMessage: false })).toBe(false);
  });

  it('does not show on a deleted message, even for the administrator', () => {
    expect(hasEditPencil({ isAdmin: true, isMessageDeleted: true })).toBe(
      false
    );
  });

  it('does not show on a message written by the customer, even for the administrator', () => {
    expect(hasEditPencil({ isAdmin: true, messageType: 0 })).toBe(false);
  });
});
