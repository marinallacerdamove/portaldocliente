import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import AskAndExtractPanel from '../AskAndExtractPanel.vue';
import ExtractPatternPanel from '../ExtractPatternPanel.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

// Regressão B230: bloco antigo (sem o rótulo da variável) perdia o nome da
// variável ao ser selecionado, porque o painel zerava o identificador quando o
// rótulo passava a "undefined".
describe.each([
  {
    panel: AskAndExtractPanel,
    labelKey: 'variable_label',
    nameKey: 'variable_name',
  },
  {
    panel: ExtractPatternPanel,
    labelKey: 'target_variable_label',
    nameKey: 'target_variable',
  },
])('$panel.__name', ({ panel, labelKey, nameKey }) => {
  it('keeps the variable name of a legacy block that has no label', async () => {
    const newBlock = { [labelKey]: 'Nome do cliente', [nameKey]: 'nome' };
    const legacyBlock = { [nameKey]: 'cpf_cliente' };
    const wrapper = shallowMount(panel, { props: { modelValue: newBlock } });

    await wrapper.setProps({ modelValue: legacyBlock });
    await nextTick();

    expect(legacyBlock[nameKey]).toBe('cpf_cliente');
  });

  it('still generates the variable name from the label while typing', async () => {
    const block = { [labelKey]: 'Nome', [nameKey]: 'nome' };
    const wrapper = shallowMount(panel, { props: { modelValue: block } });

    block[labelKey] = 'CNPJ do cliente';
    await wrapper.setProps({ modelValue: { ...block } });
    await nextTick();

    expect(wrapper.props('modelValue')[nameKey]).toBe('cnpj_do_cliente');
  });
});
