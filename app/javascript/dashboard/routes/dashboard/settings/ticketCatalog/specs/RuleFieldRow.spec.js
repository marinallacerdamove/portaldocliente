// PATCH LOCAL (fork) - campo da regra: equipes que editam (Movidesk: "somente
// as equipes"). Vazio = todas; nome comparado sem diferenciar maiúsculas.
import { shallowMount } from '@vue/test-utils';
import { withFullI18n } from 'test-i18n';
import RuleFieldRow from '../RuleFieldRow.vue';
import ToggleChips from '../ToggleChips.vue';

withFullI18n('pt_BR');

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return {
    useMapGetter: () =>
      ref([
        { id: 1, name: 'tecnologia e infraestrutura' },
        { id: 2, name: 'suporte' },
      ]),
  };
});

const mountRow = teamNames => {
  const item = {
    field_id: 10,
    columns: 12,
    required_on: 'nao_exigir',
    visible_to_clients: false,
    editable_by_clients: false,
    editable_by_agents: true,
    ...(teamNames ? { team_names: teamNames } : {}),
  };
  const wrapper = shallowMount(RuleFieldRow, {
    props: {
      fieldName: 'Criticidade do cliente',
      item,
      'onUpdate:item': value => wrapper.setProps({ item: value }),
    },
  });
  return { wrapper, item };
};

describe('RuleFieldRow teams', () => {
  it('lists the teams of the account and starts with none picked (all teams)', () => {
    const { wrapper } = mountRow();
    const chips = wrapper.findComponent(ToggleChips);

    expect(chips.props('options').map(option => option.name)).toEqual([
      'tecnologia e infraestrutura',
      'suporte',
    ]);
    expect(chips.props('modelValue')).toEqual([]);
  });

  it('marks the team saved with another case and keeps its spelling when another is added', async () => {
    const { wrapper, item } = mountRow(['Tecnologia e Infraestrutura']);
    const chips = wrapper.findComponent(ToggleChips);

    expect(chips.props('modelValue')).toEqual(['tecnologia e infraestrutura']);
    await chips.vm.$emit('update:modelValue', [
      'tecnologia e infraestrutura',
      'suporte',
    ]);

    expect(item.team_names).toEqual(['Tecnologia e Infraestrutura', 'suporte']);
  });

  it('shows a saved team this account does not have, so it can be removed', () => {
    const { wrapper } = mountRow(['Financeiro']);
    const chips = wrapper.findComponent(ToggleChips);

    expect(chips.props('options').map(option => option.name)).toContain(
      'Financeiro'
    );
    expect(chips.props('modelValue')).toEqual(['Financeiro']);
  });
});
