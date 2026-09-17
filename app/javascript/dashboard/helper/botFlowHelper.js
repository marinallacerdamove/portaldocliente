export const BOT_FLOW_STEP_TYPES = {
  MENU: 'menu',
  ASK_AND_EXTRACT: 'ask_and_extract',
  MESSAGE: 'message',
};

export const BOT_FLOW_STEP_REQUIRED_FIELDS = {
  [BOT_FLOW_STEP_TYPES.MENU]: ['attribute_key', 'prompt_canned_response'],
  [BOT_FLOW_STEP_TYPES.ASK_AND_EXTRACT]: ['prompt_canned_response'],
  [BOT_FLOW_STEP_TYPES.MESSAGE]: ['canned_response'],
};

export const getDefaultBotFlowStep = type => {
  switch (type) {
    case BOT_FLOW_STEP_TYPES.MENU:
      return {
        type: BOT_FLOW_STEP_TYPES.MENU,
        attribute_key: '',
        prompt_canned_response: '',
        retry_canned_response: '',
      };
    case BOT_FLOW_STEP_TYPES.ASK_AND_EXTRACT:
      return {
        type: BOT_FLOW_STEP_TYPES.ASK_AND_EXTRACT,
        prompt_canned_response: '',
        extract: '',
        found_canned_response: '',
        not_found_canned_response: '',
      };
    case BOT_FLOW_STEP_TYPES.MESSAGE:
    default:
      return {
        type: BOT_FLOW_STEP_TYPES.MESSAGE,
        canned_response: '',
      };
  }
};

export const isBotFlowStepValid = step =>
  (BOT_FLOW_STEP_REQUIRED_FIELDS[step.type] || []).every(
    field => !!step[field]
  );
