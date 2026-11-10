<script setup>
// PATCH LOCAL (fork) - tela Grupos (só leitura). Os grupos de clientes são
// cadastrados no Portal do Cliente; aqui só se consulta quem faz parte e
// quantos contatos recebem hoje (usado como público das campanhas de WhatsApp).
import { onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { usePortalGroups } from 'dashboard/composables/usePortalGroups';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const route = useRoute();
const { groups, isLoading, hasError, errorMessage, fetchGroups } =
  usePortalGroups();

const detailRoute = group => ({
  name: 'portal_groups_show',
  params: { accountId: route.params.accountId, groupId: group.id },
});

onMounted(fetchGroups);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 pt-7 pb-4">
      <h1 class="my-0 text-xl font-semibold text-n-slate-12">
        {{ t('PORTAL_GROUPS.TITLE') }}
      </h1>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('PORTAL_GROUPS.SUBTITLE') }}
      </p>
    </header>

    <main class="flex-1 px-6 pb-8 overflow-y-auto">
      <div class="flex flex-col w-full max-w-5xl gap-4">
        <div v-if="isLoading" class="flex items-center gap-2 text-n-slate-11">
          <Spinner :size="16" />
          <span class="text-sm">{{ t('PORTAL_GROUPS.LOADING') }}</span>
        </div>

        <div v-else-if="hasError" class="flex flex-col items-start gap-3">
          <p class="mb-0 text-sm text-n-ruby-11">
            {{ errorMessage || t('PORTAL_GROUPS.LOAD_ERROR') }}
          </p>
          <Button
            :label="t('PORTAL_GROUPS.RETRY')"
            variant="faded"
            color="slate"
            sm
            @click="fetchGroups"
          />
        </div>

        <p v-else-if="!groups.length" class="mb-0 text-sm text-n-slate-11">
          {{ t('PORTAL_GROUPS.EMPTY') }}
        </p>

        <div
          v-else
          class="overflow-x-auto border rounded-lg border-n-weak bg-n-solid-2"
        >
          <table class="w-full text-sm text-start border-collapse">
            <thead>
              <tr class="text-xs font-medium text-n-slate-11">
                <th class="px-3 py-2 text-start">
                  {{ t('PORTAL_GROUPS.TABLE.NAME') }}
                </th>
                <th class="px-3 py-2 text-start">
                  {{ t('PORTAL_GROUPS.TABLE.COMPANIES') }}
                </th>
                <th class="px-3 py-2 text-start">
                  {{ t('PORTAL_GROUPS.TABLE.CONTACTS') }}
                </th>
                <th class="px-3 py-2 text-start">
                  {{ t('PORTAL_GROUPS.TABLE.RECIPIENTS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="group in groups"
                :key="group.id"
                class="border-t border-n-weak"
              >
                <td class="px-3 py-2.5">
                  <router-link
                    :to="detailRoute(group)"
                    class="font-medium text-n-slate-12 hover:text-n-blue-11"
                  >
                    {{ group.name }}
                  </router-link>
                  <span
                    v-if="group.automatic"
                    class="px-2 py-0.5 ms-2 text-xs rounded-md bg-n-blue-3 text-n-blue-11"
                  >
                    {{ t('PORTAL_GROUPS.AUTOMATIC') }}
                  </span>
                </td>
                <td class="px-3 py-2.5 text-n-slate-11">
                  {{ group.empresas_count }}
                </td>
                <td class="px-3 py-2.5 text-n-slate-11">
                  {{ group.contatos_count }}
                </td>
                <td class="px-3 py-2.5 font-medium text-n-slate-12">
                  {{ group.recipients_count }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </main>
  </section>
</template>
