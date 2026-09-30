import { shallowMount } from '@vue/test-utils';
import { withFullI18n } from 'test-i18n';
import MacroForm from '../MacroForm.vue';

withFullI18n();

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return {
    useMapGetter: () =>
      ref([
        { id: 1, name: 'Suporte' },
        { id: 2, name: 'Comercial' },
      ]),
  };
});

const baseMacro = overrides => ({
  name: 'Fiscal: Carta de Correção',
  visibility: 'personal',
  group_name: 'Fiscal',
  team_ids: [],
  actions: [{ action_name: 'fill_reply', action_params: ['Olá', 'reply'] }],
  ...overrides,
});

const mountForm = props =>
  shallowMount(MacroForm, {
    props: { macroData: baseMacro(), ...props },
    global: {
      provide: { macroActionTypes: { value: [] } },
      stubs: {
        InfoCard: { template: '<div><slot /><slot name="actions" /></div>' },
      },
    },
  });

const visibilityButton = (wrapper, index) =>
  wrapper.findAll('button[type="button"]')[index];

describe('MacroForm.vue', () => {
  it('keeps team and global sharing for administrators only', () => {
    const agent = mountForm({ canManagePublicMacros: false });
    expect(visibilityButton(agent, 0).attributes('disabled')).toBeUndefined();
    expect(visibilityButton(agent, 1).attributes('disabled')).toBeDefined();
    expect(visibilityButton(agent, 2).attributes('disabled')).toBeDefined();

    const admin = mountForm({ canManagePublicMacros: true });
    expect(visibilityButton(admin, 1).attributes('disabled')).toBeUndefined();
  });

  it('requires at least one team for team sharing', async () => {
    const wrapper = mountForm({
      canManagePublicMacros: true,
      macroData: baseMacro({ visibility: 'team' }),
    });

    await wrapper.vm.$.setupState.submit();
    expect(wrapper.emitted('submit')).toBeUndefined();

    wrapper.vm.$.setupState.toggleTeam(2);
    await wrapper.vm.$.setupState.submit();
    expect(wrapper.emitted('submit')[0][0]).toMatchObject({
      visibility: 'team',
      team_ids: [2],
    });
  });

  it('drops teams when the macro is not shared with teams', async () => {
    const wrapper = mountForm({
      macroData: baseMacro({ visibility: 'global', team_ids: [1] }),
    });

    await wrapper.vm.$.setupState.submit();
    expect(wrapper.emitted('submit')[0][0].team_ids).toEqual([]);
  });

  it('requires the reply text of a fill_reply action', async () => {
    const wrapper = mountForm({
      macroData: baseMacro({
        actions: [{ action_name: 'fill_reply', action_params: ['', 'note'] }],
      }),
    });

    await wrapper.vm.$.setupState.submit();
    expect(wrapper.emitted('submit')).toBeUndefined();
  });
});
