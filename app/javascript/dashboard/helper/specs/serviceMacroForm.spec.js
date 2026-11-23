import { macroFormChanges } from '../serviceMacroForm';

describe('macroFormChanges', () => {
  it('turns the service macro actions into form values', () => {
    const macro = {
      actions: [
        {
          action_name: 'set_subject',
          action_params: ['Backup {{contact.name}}'],
        },
        { action_name: 'fill_reply', action_params: ['**Empresa:**', 'note'] },
        { action_name: 'change_priority', action_params: ['high'] },
        { action_name: 'assign_team', action_params: [4] },
        { action_name: 'assign_agent', action_params: ['self'] },
        {
          action_name: 'set_custom_attribute',
          action_params: ['categoria', 'Instalação'],
        },
        {
          action_name: 'set_custom_attribute',
          action_params: ['status_atendimento', 'Novo'],
        },
        { action_name: 'resolve_conversation', action_params: [] },
      ],
    };

    expect(macroFormChanges(macro)).toEqual({
      subject: 'Backup {{contact.name}}',
      messages: ['**Empresa:**'],
      priority: 'high',
      teamId: 4,
      agentId: 'self',
      tipo: 'Instalação',
    });
  });

  it('accepts the current tipo de solicitação key and an empty macro', () => {
    expect(
      macroFormChanges({
        actions: [
          {
            action_name: 'set_custom_attribute',
            action_params: ['tipo_de_solicitao', 'Erro'],
          },
        ],
      })
    ).toEqual({ messages: [], tipo: 'Erro' });
    expect(macroFormChanges(null)).toEqual({ messages: [] });
  });
});
