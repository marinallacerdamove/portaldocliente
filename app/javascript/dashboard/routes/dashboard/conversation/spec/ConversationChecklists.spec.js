import { shallowMount } from '@vue/test-utils';
import ConversationChecklists from '../ConversationChecklists.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return { useMapGetter: () => ref({ id: 1 }) };
});
vi.mock('dashboard/composables/useConversationCustomFields', async () => {
  const { ref } = await import('vue');
  const checklist = (id, key, extra = {}) => ({
    field: { id, key, name: key, field_type: 'checklist', options: ['A'] },
    editable_by_agents: true,
    ...extra,
  });
  return {
    useConversationCustomFields: () => ({
      items: ref([
        checklist(1, 'livre'),
        checklist(2, 'infra', { team_names: ['Infra'] }),
      ]),
      values: ref({}),
      canEdit: item => !item.team_names,
      load: vi.fn(),
      saveValue: vi.fn(),
    }),
  };
});

// Movidesk: "somente as equipes". Checklist de outra equipe aparece, mas não
// dá pra marcar (canEdit do composable, agentCanEditItem).
describe('ConversationChecklists', () => {
  it('disables the checklist the agent cannot edit', () => {
    const wrapper = shallowMount(ConversationChecklists);

    const disabled = wrapper
      .findAllComponents(Checkbox)
      .map(checkbox => checkbox.props('disabled'));
    expect(disabled).toEqual([false, true]);
  });
});
