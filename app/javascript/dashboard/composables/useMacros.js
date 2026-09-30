import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';
import { PRIORITY_CONDITION_VALUES } from 'dashboard/constants/automation';
import {
  generateLabelOptions,
  generateTeamOptions,
} from 'dashboard/helper/automationHelper';
import {
  resolveActionName,
  getFileName,
} from 'dashboard/routes/dashboard/settings/macros/macroHelper';

// PATCH LOCAL (fork) - status que a macro pode aplicar (change_status).
const MACRO_STATUSES = ['open', 'pending', 'snoozed', 'resolved'];

/**
 * Composable for handling macro-related functionality
 * @returns {Object} An object containing the getMacroDropdownValues and resolveMacroActions functions
 */
export const useMacros = () => {
  const { t } = useI18n();
  const getters = useStoreGetters();

  const labels = computed(() => getters['labels/getLabels'].value);
  const teams = computed(() => getters['teams/getTeams'].value);
  const agents = computed(() => getters['agents/getVerifiedAgents'].value);

  const withNoneOption = options => [
    { id: 'nil', name: t('AUTOMATION.NONE_OPTION') },
    ...(options || []),
  ];

  /**
   * Get dropdown values based on the specified type
   * @param {string} type - The type of dropdown values to retrieve
   * @returns {Array} An array of dropdown values
   */
  const getMacroDropdownValues = type => {
    switch (type) {
      case 'assign_team':
        return withNoneOption(generateTeamOptions(teams.value));
      case 'assign_agent':
        return [
          ...withNoneOption(),
          { id: 'self', name: t('MACROS.EDITOR.SELF_AGENT') }, // PATCH LOCAL (fork)
          ...agents.value,
        ];
      case 'add_label':
      case 'remove_label':
      case 'replace_labels': // PATCH LOCAL (fork)
        return generateLabelOptions(labels.value);
      // PATCH LOCAL (fork)
      case 'change_status':
        return MACRO_STATUSES.map(status => ({
          id: status,
          name: t(`MACROS.STATUS_TYPES.${status.toUpperCase()}`),
        }));
      case 'change_priority':
        return PRIORITY_CONDITION_VALUES.map(item => ({
          id: item.id,
          name: t(`MACROS.PRIORITY_TYPES.${item.i18nKey}`),
        }));
      default:
        return [];
    }
  };

  const resolveActionValue = (
    { action_name: name, action_params: params },
    files
  ) => {
    if (!params?.length) return '';

    // PATCH LOCAL (fork) - "Serviço: Ticket Cancelado".
    if (name === 'set_custom_attribute') {
      const [key, value] = params;
      const attributes =
        getters['attributes/getConversationAttributes']?.value || [];
      const attribute = attributes.find(attr => attr.attributeKey === key);
      return `${attribute?.attributeDisplayName || key}: ${value}`;
    }

    const options = getMacroDropdownValues(name);
    if (options.length) {
      return params
        .map(id => options.find(option => option.id === id)?.name)
        .filter(Boolean)
        .join(', ');
    }

    if (name === 'send_attachment') return getFileName(params[0], name, files);

    return params[0];
  };

  /**
   * Resolve a macro into the action name and value pairs shown in its preview.
   * Actions that store option ids are looked up in the same dropdown values the
   * macro builder offers, so the preview never drifts from what can be built.
   * @param {Object} macro - The macro to resolve
   * @returns {Array} An array of { actionName, actionValue } pairs
   */
  const resolveMacroActions = macro =>
    macro.actions.map(action => ({
      actionName: resolveActionName(action.action_name),
      actionValue: resolveActionValue(action, macro.files),
    }));

  return {
    getMacroDropdownValues,
    resolveMacroActions,
  };
};
