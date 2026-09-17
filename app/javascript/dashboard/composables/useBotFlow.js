import { ref } from 'vue';
import {
  BOT_FLOW_STEP_TYPES,
  getDefaultBotFlowStep,
} from 'dashboard/helper/botFlowHelper';

export function useBotFlow(initialSteps = []) {
  const steps = ref(initialSteps.map(step => ({ ...step })));

  const setSteps = newSteps => {
    steps.value = newSteps.map(step => ({ ...step }));
  };

  const addStep = () => {
    steps.value = [
      ...steps.value,
      getDefaultBotFlowStep(BOT_FLOW_STEP_TYPES.MESSAGE),
    ];
  };

  const removeStep = index => {
    steps.value = steps.value.filter((_, i) => i !== index);
  };

  const moveStep = (index, direction) => {
    const newIndex = index + direction;
    if (newIndex < 0 || newIndex >= steps.value.length) return;

    const newSteps = [...steps.value];
    [newSteps[index], newSteps[newIndex]] = [
      newSteps[newIndex],
      newSteps[index],
    ];
    steps.value = newSteps;
  };

  const setStepType = (index, type) => {
    const newSteps = [...steps.value];
    newSteps[index] = getDefaultBotFlowStep(type);
    steps.value = newSteps;
  };

  const updateStep = (index, updatedStep) => {
    const newSteps = [...steps.value];
    newSteps[index] = updatedStep;
    steps.value = newSteps;
  };

  return {
    steps,
    setSteps,
    addStep,
    removeStep,
    moveStep,
    setStepType,
    updateStep,
  };
}
