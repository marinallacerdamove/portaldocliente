// PATCH LOCAL (fork) - modo do "Texto da resposta" (fill_reply): action_params
// = [texto em markdown, modo].
export const FILL_REPLY_MODES = { REPLY: 'reply', NOTE: 'note' };

export const MACRO_ACTION_TYPES = [
  // PATCH LOCAL (fork) - preenche o editor pro atendente completar (não envia).
  {
    key: 'fill_reply',
    label: 'FILL_REPLY',
    inputType: 'fill_reply',
  },
  {
    key: 'set_subject',
    label: 'SET_SUBJECT',
    inputType: 'text',
  },
  {
    key: 'change_status',
    label: 'CHANGE_STATUS',
    inputType: 'search_select',
  },
  // PATCH LOCAL (fork) - serviço, categoria, motivo de encerramento...
  {
    key: 'set_custom_attribute',
    label: 'SET_CUSTOM_ATTRIBUTE',
    inputType: 'custom_attribute',
  },
  {
    key: 'assign_team',
    label: 'ASSIGN_TEAM',
    inputType: 'search_select',
  },
  {
    key: 'assign_agent',
    label: 'ASSIGN_AGENT',
    inputType: 'search_select',
  },
  {
    key: 'add_label',
    label: 'ADD_LABEL',
    inputType: 'multi_select',
  },
  {
    key: 'remove_label',
    label: 'REMOVE_LABEL',
    inputType: 'multi_select',
  },
  // PATCH LOCAL (fork) - substitui todas as etiquetas / remove todas.
  {
    key: 'replace_labels',
    label: 'REPLACE_LABELS',
    inputType: 'multi_select',
  },
  {
    key: 'remove_all_labels',
    label: 'REMOVE_ALL_LABELS',
    inputType: null,
  },
  {
    key: 'remove_assigned_agent',
    label: 'REMOVE_ASSIGNED_AGENT',
    inputType: null,
  },
  {
    key: 'remove_assigned_team',
    label: 'REMOVE_ASSIGNED_TEAM',
    inputType: null,
  },
  {
    key: 'send_email_transcript',
    label: 'SEND_EMAIL_TRANSCRIPT',
    inputType: 'email',
  },
  {
    key: 'mute_conversation',
    label: 'MUTE_CONVERSATION',
    inputType: null,
  },
  {
    key: 'snooze_conversation',
    label: 'SNOOZE_CONVERSATION',
    inputType: null,
  },
  {
    key: 'resolve_conversation',
    label: 'RESOLVE_CONVERSATION',
    inputType: null,
  },
  {
    key: 'send_attachment',
    label: 'SEND_ATTACHMENT',
    inputType: 'attachment',
  },
  {
    key: 'send_message',
    label: 'SEND_MESSAGE',
    inputType: 'textarea',
  },
  {
    key: 'add_private_note',
    label: 'ADD_PRIVATE_NOTE',
    inputType: 'textarea',
  },
  {
    key: 'change_priority',
    label: 'CHANGE_PRIORITY',
    inputType: 'search_select',
  },
  {
    key: 'send_webhook_event',
    label: 'SEND_WEBHOOK_EVENT',
    inputType: 'url',
  },
];
