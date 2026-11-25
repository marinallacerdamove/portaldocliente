import {
  agentCanEditItem,
  missingRequiredFields,
  visibleCustomFields,
  STATUS_NOT_CONCLUDED,
  teamLockedFieldKeys,
} from '../ticketFieldRules';
import parity from '../../../../../spec/fixtures/fork_parity/ticket_field_rules_cases.json';
import teamCases from '../../../../../spec/fixtures/fork_parity/ticket_field_team_cases.json';

const field = (id, key, extra = {}) => ({
  id,
  key,
  name: key,
  field_type: 'list',
  active: true,
  ...extra,
});
const ruleField = (fieldId, extra = {}) => ({
  field_id: fieldId,
  columns: 12,
  visible_to_clients: true,
  editable_by_clients: false,
  editable_by_agents: true,
  required_on: 'nao_exigir',
  ...extra,
});

// Cascata do Movidesk: Serviço + Tipo -> Classificação -> Checklist.
const fields = [
  field(1, 'classificacao_com'),
  field(2, 'checklist_tintometrico', { field_type: 'multi_select' }),
  field(3, 'inativo', { active: false }),
];
const rules = [
  {
    id: 10,
    active: true,
    conditions: [
      {
        group: 'all',
        attribute: 'servico',
        operator: 'equal_to',
        value: 'ALBATROSS › 04. Comercial',
      },
      {
        group: 'any',
        attribute: 'tipo_de_solicitacao',
        operator: 'equal_to',
        value: 'Dúvida',
      },
      {
        group: 'any',
        attribute: 'tipo_de_solicitacao',
        operator: 'equal_to',
        value: 'Configuração',
      },
    ],
    fields: [ruleField(1, { required_on: 'conclusao' }), ruleField(3)],
  },
  {
    id: 11,
    active: true,
    conditions: [
      {
        group: 'all',
        attribute: 'campo',
        field_id: 1,
        operator: 'equal_to',
        value: 'Tintométrico',
      },
    ],
    fields: [ruleField(2, { required_on: 'conclusao' })],
  },
];
const keys = items => items.map(item => item.field.key);

describe('visibleCustomFields', () => {
  const base = {
    servico: 'ALBATROSS › 04. Comercial',
    tipo_de_solicitacao: 'Dúvida',
    values: {},
  };

  it('mostra a classificação quando serviço (all) e um tipo (any) batem', () => {
    expect(keys(visibleCustomFields({ rules, fields, context: base }))).toEqual(
      ['classificacao_com']
    );
  });

  it('não mostra quando nenhuma condição "any" bate', () => {
    const context = { ...base, tipo_de_solicitacao: 'Bug' };
    expect(visibleCustomFields({ rules, fields, context })).toEqual([]);
  });

  it('abre o checklist pelo valor da classificação (cascata)', () => {
    const context = { ...base, values: { classificacao_com: 'Tintométrico' } };
    expect(keys(visibleCustomFields({ rules, fields, context }))).toEqual([
      'classificacao_com',
      'checklist_tintometrico',
    ]);
  });

  it('valor de campo escondido não mantém a cascata aberta', () => {
    const context = {
      ...base,
      servico: 'Outro',
      values: { classificacao_com: 'Tintométrico' },
    };
    expect(visibleCustomFields({ rules, fields, context })).toEqual([]);
  });

  it('ignora regra inativa', () => {
    const inactive = rules.map(rule => ({ ...rule, active: false }));
    expect(
      visibleCustomFields({ rules: inactive, fields, context: base })
    ).toEqual([]);
  });

  it('"diferente de", "informada" e seleção múltipla', () => {
    const extraRules = [
      {
        id: 20,
        active: true,
        conditions: [
          {
            group: 'all',
            attribute: 'servico',
            operator: 'not_equal_to',
            value: 'Z. DynamicRD',
          },
          {
            group: 'all',
            attribute: 'campo',
            field_id: 2,
            operator: 'equal_to',
            value: 'Opção B',
          },
        ],
        fields: [ruleField(4)],
      },
      {
        id: 21,
        active: true,
        conditions: [
          {
            group: 'all',
            attribute: 'campo',
            field_id: 4,
            operator: 'is_present',
          },
        ],
        fields: [ruleField(5)],
      },
    ];
    const allFields = [...fields, field(4, 'extra'), field(5, 'final')];
    const context = {
      ...base,
      values: {
        classificacao_com: 'Tintométrico',
        checklist_tintometrico: ['Opção A', 'Opção B'],
        extra: 'x',
      },
    };
    expect(
      keys(
        visibleCustomFields({
          rules: [...rules, ...extraRules],
          fields: allFields,
          context,
        })
      )
    ).toEqual([
      'classificacao_com',
      'checklist_tintometrico',
      'extra',
      'final',
    ]);
  });

  it('status "não concluído"', () => {
    const statusRules = [
      {
        id: 30,
        active: true,
        conditions: [
          {
            group: 'all',
            attribute: 'status',
            operator: 'equal_to',
            value: STATUS_NOT_CONCLUDED,
          },
        ],
        fields: [ruleField(1)],
      },
    ];
    expect(
      visibleCustomFields({
        rules: statusRules,
        fields,
        context: { concluded: false },
      })
    ).toHaveLength(1);
    expect(
      visibleCustomFields({
        rules: statusRules,
        fields,
        context: { concluded: true },
      })
    ).toEqual([]);
  });
});

describe('missingRequiredFields', () => {
  it('lista só os obrigatórios do momento que estão vazios', () => {
    const items = visibleCustomFields({
      rules,
      fields,
      context: {
        servico: 'ALBATROSS › 04. Comercial',
        tipo_de_solicitacao: 'Dúvida',
        values: { classificacao_com: 'Tintométrico' },
      },
    });
    const values = {
      classificacao_com: 'Tintométrico',
      checklist_tintometrico: [],
    };
    expect(keys(missingRequiredFields(items, values, ['conclusao']))).toEqual([
      'checklist_tintometrico',
    ]);
    expect(missingRequiredFields(items, values, ['abertura'])).toEqual([]);
  });
});

// Mesmo arquivo lido por spec/services/ticket_field_rules_evaluator_spec.rb: os
// dois avaliadores (este e o do servidor) têm que dar o mesmo resultado nos
// mesmos casos.
describe('shared parity cases', () => {
  it('evaluates every case like the server does', () => {
    parity.cases.forEach(example => {
      const items = visibleCustomFields({
        rules: parity.rules,
        fields: parity.fields,
        context: example.context,
      });
      const missing = missingRequiredFields(items, example.context.values, [
        'conclusao',
      ]);

      expect(
        items.map(item => item.field.key),
        example.name
      ).toEqual(example.visible);
      expect(
        missing.map(item => item.field.key),
        example.name
      ).toEqual(example.missing_on_conclusao);
    });
  });
});

// Mesmo arquivo lido por TicketFieldRulesEvaluator.agent_can_edit? (servidor).
describe('agentCanEditItem', () => {
  it('decide quem edita o campo pela equipe igual ao servidor', () => {
    teamCases.cases.forEach(example => {
      const editor = {
        isAdmin: example.editor.admin,
        teamNames: example.editor.team_names,
      };
      expect(agentCanEditItem(example.item, editor), example.name).toBe(
        example.can_edit
      );
    });
  });
});

// Revisão do campo restrito (25/11): o que o agente não grava por equipe, igual a
// ResolveRequirementsService#team_locked_field_keys. Campo escondido também trava.
describe('teamLockedFieldKeys', () => {
  const teamFields = [
    { id: 1, key: 'decisao_po', active: true },
    { id: 2, key: 'issue_jira', active: true },
  ];
  const teamRules = [
    {
      active: true,
      conditions: [
        {
          group: 'all',
          attribute: 'servico',
          operator: 'equal_to',
          value: 'PO',
        },
      ],
      fields: [
        {
          field_id: 1,
          editable_by_agents: true,
          team_names: ['Desenvolvimento'],
        },
        { field_id: 2, editable_by_agents: true },
      ],
    },
  ];
  const outsider = { isAdmin: false, teamNames: ['suporte técnico'] };

  it('locks the restricted field for an agent outside the team, even while hidden', () => {
    expect([
      ...teamLockedFieldKeys({
        rules: teamRules,
        fields: teamFields,
        visible: [],
        editor: outsider,
      }),
    ]).toEqual(['decisao_po']);
  });

  it('locks nothing for the team member or the administrator', () => {
    expect(
      teamLockedFieldKeys({
        rules,
        fields,
        visible: [],
        editor: { isAdmin: false, teamNames: ['desenvolvimento'] },
      }).size
    ).toBe(0);
    expect(
      teamLockedFieldKeys({
        rules,
        fields,
        visible: [],
        editor: { isAdmin: true, teamNames: [] },
      }).size
    ).toBe(0);
  });
});
