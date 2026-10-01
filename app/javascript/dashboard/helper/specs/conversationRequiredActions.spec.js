import { missingConversationActions } from '../conversationRequiredActions';

const attributes = [
  { attributeKey: 'empresa', attributeDisplayName: 'Empresa' },
  {
    attributeKey: 'tipo_de_solicitao',
    attributeDisplayName: 'Tipo de solicitação',
  },
  { attributeKey: 'servico', attributeDisplayName: 'Serviço' },
];
const nativeLabels = {
  priority: 'Prioridade',
  assignee: 'Agente',
  team: 'Time',
};

const filled = {
  priority: 'high',
  custom_attributes: {
    empresa: 'ACME',
    tipo_de_solicitao: 'Dúvida',
    servico: 'ERP',
  },
  meta: { assignee: { id: 1 }, team: { id: 2 } },
};

describe('missingConversationActions', () => {
  it('não cobra nada com tudo preenchido', () => {
    expect(
      missingConversationActions(filled, {
        attributes,
        hasTeams: true,
        nativeLabels,
      })
    ).toEqual([]);
  });

  it('lista o que falta na ordem da lateral', () => {
    const conversation = {
      priority: null,
      custom_attributes: { empresa: ' ' },
      meta: {},
    };
    const labels = missingConversationActions(conversation, {
      attributes,
      hasTeams: true,
      nativeLabels,
    }).map(item => item.label);
    expect(labels).toEqual([
      'Empresa',
      'Tipo de solicitação',
      'Serviço',
      'Prioridade',
      'Agente',
      'Time',
    ]);
  });

  it('ignora atributo não cadastrado na conta e time quando a conta não tem time', () => {
    const conversation = {
      ...filled,
      custom_attributes: {},
      meta: { assignee: { id: 1 } },
    };
    expect(
      missingConversationActions(conversation, {
        attributes: [],
        hasTeams: false,
        nativeLabels,
      })
    ).toEqual([]);
  });
});
