import { useSaveConversationAttributes } from '../useSaveConversationAttributes';
import { useAlert } from 'dashboard/composables';

const dispatch = vi.fn();

vi.mock('vuex', () => ({ useStore: () => ({ dispatch }) }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

describe('useSaveConversationAttributes', () => {
  // Regressão B227: gravar atributos mandava a cópia inteira dos
  // custom_attributes da conversa (de uma lista/busca sem custom_attributes,
  // ou desatualizada) e apagava os dados que o servidor tinha.
  it('sends only the changed keys, never a copy of the whole custom_attributes', async () => {
    const save = useSaveConversationAttributes();
    const conversation = {
      id: 7,
      custom_attributes: { empresa: 'Acme', ticket_pai_id: '3', assunto: 'X' },
    };

    await save(conversation, { servico: 'Suporte', status_atendimento: '' });

    expect(dispatch).toHaveBeenCalledWith('mergeCustomAttributes', {
      conversationId: 7,
      changes: { servico: 'Suporte', status_atendimento: '' },
    });
  });

  it('works on a conversation that came without custom_attributes', async () => {
    const save = useSaveConversationAttributes();

    await save({ id: 8 }, { servico: 'Suporte' });

    expect(dispatch).toHaveBeenCalledWith('mergeCustomAttributes', {
      conversationId: 8,
      changes: { servico: 'Suporte' },
    });
  });

  it('warns about the success and returns true', async () => {
    dispatch.mockResolvedValue();
    const save = useSaveConversationAttributes();

    expect(await save({ id: 7 }, { servico: 'Suporte' })).toBe(true);
    expect(useAlert).toHaveBeenCalledWith(
      'CUSTOM_ATTRIBUTES.FORM.UPDATE.SUCCESS'
    );
  });

  it('warns about the error and returns false when the server refuses', async () => {
    dispatch.mockRejectedValue(new Error('422'));
    const save = useSaveConversationAttributes();

    expect(await save({ id: 7 }, { servico: 'Suporte' })).toBe(false);
    expect(useAlert).toHaveBeenCalledWith(
      'CUSTOM_ATTRIBUTES.FORM.UPDATE.ERROR'
    );
  });
});
