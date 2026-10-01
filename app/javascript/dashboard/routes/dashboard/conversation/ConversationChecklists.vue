<script setup>
// PATCH LOCAL (fork) - campos adicionais do tipo checklist num bloco no topo
// da conversa, igual o Movidesk (e o Portal, TicketChecklists.vue). Mesmas
// regras de exibição da lateral (useConversationCustomFields). Marcar grava na
// hora; quem marcou vira atividade da conversa e vai pro histórico do Portal
// (Conversations::ChecklistActivityService). Cada checklist recolhe; começa
// aberto enquanto falta item.
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useConversationCustomFields } from 'dashboard/composables/useConversationCustomFields';
import { isChecklistItem } from 'dashboard/helper/ticketFieldRules';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const { t } = useI18n();
const currentChat = useMapGetter('getSelectedChat');
const { items, values, load, saveValue } =
  useConversationCustomFields(currentChat);

const checklists = computed(() => items.value.filter(isChecklistItem));
// "conversa:campo" -> aberto/fechado escolhido pelo agente.
const openState = ref({});

const checkedOf = field => values.value[field.key] || [];
const doneCount = field =>
  field.options.filter(option => checkedOf(field).includes(option)).length;
const stateKey = field => `${currentChat.value?.id}:${field.id}`;
const isOpen = field =>
  openState.value[stateKey(field)] ?? doneCount(field) < field.options.length;
const toggleOpen = field => {
  openState.value = { ...openState.value, [stateKey(field)]: !isOpen(field) };
};

const toggleOption = async (field, option, checked) => {
  const selected = new Set(checkedOf(field));
  if (checked) selected.add(option);
  else selected.delete(option);
  try {
    await saveValue(
      field.key,
      field.options.filter(item => selected.has(item))
    );
  } catch (error) {
    useAlert(t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SAVE_ERROR'));
  }
};

onMounted(load);
</script>

<template>
  <div>
    <div
      v-if="checklists.length"
      class="mx-2 mt-2 max-h-[40vh] overflow-y-auto rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2"
    >
      <section
        v-for="{ field, editable_by_agents: editable } in checklists"
        :key="field.id"
        class="py-1.5"
      >
        <button
          type="button"
          class="flex w-full items-center gap-2 text-start"
          @click="toggleOpen(field)"
        >
          <span
            class="i-lucide-chevron-down size-3.5 shrink-0 text-n-slate-10 transition-transform"
            :class="isOpen(field) ? '' : '-rotate-90'"
          />
          <span
            class="min-w-0 flex-1 break-words text-sm font-medium text-n-slate-12"
          >
            {{ field.name }}
          </span>
          <span
            class="shrink-0 rounded-full px-2 py-0.5 text-xs"
            :class="
              doneCount(field) === field.options.length
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-alpha-2 text-n-slate-11'
            "
          >
            {{
              t('TICKET_CATALOG.CUSTOM_FIELDS.CHECKLIST.PROGRESS', {
                done: doneCount(field),
                total: field.options.length,
              })
            }}
          </span>
        </button>
        <div v-if="isOpen(field)" class="mt-1.5 flex flex-col gap-1 ps-5">
          <p
            v-if="field.hint"
            class="mb-1 flex items-start gap-1.5 text-xs text-n-slate-11"
          >
            <span class="i-lucide-info mt-px size-3.5 shrink-0" />
            <span class="break-words">{{ field.hint }}</span>
          </p>
          <label
            v-for="option in field.options"
            :key="option"
            class="mb-0 flex items-start gap-2 text-sm text-n-slate-12"
            :class="editable ? 'cursor-pointer' : 'cursor-default'"
          >
            <Checkbox
              class="mt-0.5 shrink-0"
              :model-value="checkedOf(field).includes(option)"
              :disabled="!editable"
              @update:model-value="
                checked => toggleOption(field, option, checked)
              "
            />
            <span
              class="break-words"
              :class="
                checkedOf(field).includes(option)
                  ? 'text-n-slate-10 line-through'
                  : ''
              "
            >
              {{ option }}
            </span>
          </label>
        </div>
      </section>
    </div>
  </div>
</template>
