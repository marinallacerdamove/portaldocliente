import { useAlert } from 'dashboard/composables';
import ConversationAction from '../ConversationAction.vue';

vi.mock('dashboard/composables');

const { runServicoMacro } = ConversationAction.methods;
const macro = { id: 5, name: 'Triagem' };
const service = { full_name: 'Suporte', macro_id: 5 };

describe('ConversationAction runServicoMacro', () => {
  const dispatch = vi.fn();
  const executeMacro = vi.fn();
  const dismissPendingAttributes = vi.fn();
  const $t = (key, params) => `${key}${params ? JSON.stringify(params) : ''}`;

  const buildContext = macros => ({
    $store: { dispatch, getters: { 'macros/getMacros': macros } },
    $t,
    executeMacro,
    dismissPendingAttributes,
  });

  beforeEach(() => {
    dispatch.mockResolvedValue();
    executeMacro.mockReturnValue(null);
  });

  // Regressão B237: a macro do serviço rodava sem mensagem de sucesso e, quando
  // a macro não existia, ficava em silêncio.
  it('runs the macro of the service with the success message', async () => {
    await runServicoMacro.call(buildContext([macro]), service, 42);

    expect(dispatch).not.toHaveBeenCalled();
    expect(executeMacro).toHaveBeenCalledWith(macro, 42, {
      silent: true,
      successMessage: 'MACROS.EXECUTE.APPLIED_BY_SERVICE{"name":"Triagem"}',
    });
  });

  it('refetches the macros once when the macro is not in the store yet', async () => {
    const macros = [];
    dispatch.mockImplementation(async () => macros.push(macro));

    await runServicoMacro.call(buildContext(macros), service, 42);

    expect(dispatch).toHaveBeenCalledTimes(1);
    expect(dispatch).toHaveBeenCalledWith('macros/get');
    expect(executeMacro).toHaveBeenCalledTimes(1);
  });

  it('warns the agent when the macro of the service does not exist', async () => {
    await runServicoMacro.call(buildContext([]), service, 42);

    expect(useAlert).toHaveBeenCalledWith(
      'MACROS.EXECUTE.SERVICE_MACRO_NOT_FOUND'
    );
    expect(executeMacro).not.toHaveBeenCalled();
  });

  it('runs the macro without resolving when it asks for required attributes', async () => {
    executeMacro.mockReturnValue({ missing: [], customAttributes: {} });

    await runServicoMacro.call(buildContext([macro]), service, 42);

    expect(dismissPendingAttributes).toHaveBeenCalledTimes(1);
  });
});
