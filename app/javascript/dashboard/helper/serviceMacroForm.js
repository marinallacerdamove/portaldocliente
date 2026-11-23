// PATCH LOCAL (fork) - macro do serviço no "Novo ticket interno": igual ao
// Movidesk, escolher o serviço ao abrir o ticket roda a macro ligada a ele
// (ticket_services.macro_id). O ticket ainda não existe, então as ações viram
// valores do formulário; ação que só vale num ticket existente (status,
// etiqueta, resolver...) fica de fora.
import { TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY } from 'dashboard/constants/ticketDetailAttributes';

// Macros importadas do Movidesk gravaram o tipo de solicitação como "categoria".
const TIPO_KEYS = [TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY, 'categoria'];

const APPLY = {
  set_subject: (changes, [subject]) => ({ ...changes, subject }),
  fill_reply: (changes, [text]) => ({
    ...changes,
    messages: [...changes.messages, text],
  }),
  change_priority: (changes, [priority]) => ({ ...changes, priority }),
  assign_team: (changes, [teamId]) => ({ ...changes, teamId }),
  assign_agent: (changes, [agentId]) => ({ ...changes, agentId }),
  set_custom_attribute: (changes, [key, value]) =>
    TIPO_KEYS.includes(key) ? { ...changes, tipo: value } : changes,
};

export const macroFormChanges = macro =>
  (macro?.actions || []).reduce(
    (changes, { action_name: name, action_params: params = [] }) =>
      APPLY[name] ? APPLY[name](changes, params) : changes,
    { messages: [] }
  );
