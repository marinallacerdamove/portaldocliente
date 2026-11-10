<script setup>
// PATCH LOCAL (fork) - detalhe de um Grupo (só leitura): empresas, contatos
// avulsos, quantos recebem hoje e quantos ficaram de fora e por quê. Quem
// recebe é calculado pelo Portal na hora; o cadastro do grupo é feito lá.
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import PortalGroupsAPI from 'dashboard/api/portalGroups';
import { portalGroupsErrorMessage } from 'dashboard/composables/usePortalGroups';
import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PortalGroupActiveBadge from 'dashboard/components-next/PortalGroups/PortalGroupActiveBadge.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const group = ref(null);
const isLoading = ref(false);
const errorMessage = ref('');

const breadcrumbItems = computed(() => [
  { label: t('PORTAL_GROUPS.TITLE') },
  ...(group.value ? [{ label: group.value.name }] : []),
]);

const excludedItems = computed(() => {
  const excluded = group.value?.excluded || {};
  return [
    {
      key: 'sem_telefone',
      count: excluded.sem_telefone ?? 0,
      label: t('PORTAL_GROUPS.DETAIL.EXCLUDED.NO_PHONE'),
    },
    {
      key: 'sem_contato_no_chatwoot',
      count: excluded.sem_contato_no_chatwoot ?? 0,
      label: t('PORTAL_GROUPS.DETAIL.EXCLUDED.NO_CHATWOOT_CONTACT'),
    },
    {
      key: 'inativos',
      count: excluded.inativos ?? 0,
      label: t('PORTAL_GROUPS.DETAIL.EXCLUDED.INACTIVE'),
    },
  ];
});

const goToIndex = () =>
  router.push({
    name: 'portal_groups_index',
    params: { accountId: route.params.accountId },
  });

const fetchGroup = async id => {
  isLoading.value = true;
  errorMessage.value = '';
  group.value = null;
  try {
    ({ data: group.value } = await PortalGroupsAPI.show(id));
  } catch (error) {
    errorMessage.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => route.params.groupId,
  id => id && fetchGroup(id),
  { immediate: true }
);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 pt-7 pb-4">
      <Breadcrumb :items="breadcrumbItems" @click="goToIndex" />
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('PORTAL_GROUPS.SUBTITLE') }}
      </p>
    </header>

    <main class="flex-1 px-6 pb-8 overflow-y-auto">
      <div class="flex flex-col w-full max-w-5xl gap-6">
        <div v-if="isLoading" class="flex items-center gap-2 text-n-slate-11">
          <Spinner :size="16" />
          <span class="text-sm">{{ t('PORTAL_GROUPS.LOADING') }}</span>
        </div>

        <div v-else-if="errorMessage" class="flex flex-col items-start gap-3">
          <p class="mb-0 text-sm text-n-ruby-11">{{ errorMessage }}</p>
          <Button
            :label="t('PORTAL_GROUPS.BACK')"
            variant="faded"
            color="slate"
            sm
            @click="goToIndex"
          />
        </div>

        <template v-else-if="group">
          <div class="flex flex-col gap-1">
            <h1 class="my-0 text-xl font-semibold text-n-slate-12">
              {{ group.name }}
            </h1>
            <p v-if="group.automatic" class="mb-0 text-sm text-n-slate-11">
              {{ t('PORTAL_GROUPS.DETAIL.AUTOMATIC_HINT') }}
            </p>
          </div>

          <div class="flex flex-wrap gap-3">
            <div
              class="flex flex-col gap-1 px-4 py-3 border rounded-lg border-n-weak bg-n-solid-2 min-w-48"
            >
              <span class="text-xs text-n-slate-11">
                {{ t('PORTAL_GROUPS.DETAIL.RECIPIENTS') }}
              </span>
              <span class="text-2xl font-semibold text-n-slate-12">
                {{ group.recipients_count }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ t('PORTAL_GROUPS.DETAIL.RECIPIENTS_HINT') }}
              </span>
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <h2 class="my-0 text-sm font-medium text-n-slate-12">
              {{ t('PORTAL_GROUPS.DETAIL.EXCLUDED_TITLE') }}
            </h2>
            <ul class="flex flex-col gap-1 pl-0 mb-0 list-none">
              <li
                v-for="item in excludedItems"
                :key="item.key"
                class="flex items-center gap-2 text-sm text-n-slate-11"
              >
                <span class="font-medium text-n-slate-12">
                  {{ item.count }}
                </span>
                <span>{{ item.label }}</span>
              </li>
            </ul>
          </div>

          <div v-if="group.empresas?.length" class="flex flex-col gap-2">
            <h2 class="my-0 text-sm font-medium text-n-slate-12">
              {{
                t('PORTAL_GROUPS.DETAIL.COMPANIES_TITLE', {
                  count: group.empresas.length,
                })
              }}
            </h2>
            <div
              class="overflow-x-auto border rounded-lg border-n-weak bg-n-solid-2"
            >
              <table class="w-full text-sm border-collapse">
                <thead>
                  <tr class="text-xs font-medium text-n-slate-11">
                    <th class="px-3 py-2 text-start">
                      {{ t('PORTAL_GROUPS.DETAIL.COMPANY_NAME') }}
                    </th>
                    <th class="px-3 py-2 text-start">
                      {{ t('PORTAL_GROUPS.DETAIL.STATUS') }}
                    </th>
                    <th class="px-3 py-2 text-start">
                      {{ t('PORTAL_GROUPS.TABLE.CONTACTS') }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="company in group.empresas"
                    :key="company.id"
                    class="border-t border-n-weak"
                  >
                    <td class="px-3 py-2.5 font-medium text-n-slate-12">
                      {{ company.nome }}
                    </td>
                    <td class="px-3 py-2.5">
                      <PortalGroupActiveBadge :active="company.active" />
                    </td>
                    <td class="px-3 py-2.5 text-n-slate-11">
                      {{ company.contatos_count }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div v-if="group.contatos?.length" class="flex flex-col gap-2">
            <h2 class="my-0 text-sm font-medium text-n-slate-12">
              {{
                t('PORTAL_GROUPS.DETAIL.CONTACTS_TITLE', {
                  count: group.contatos.length,
                })
              }}
            </h2>
            <div
              class="overflow-x-auto border rounded-lg border-n-weak bg-n-solid-2"
            >
              <table class="w-full text-sm border-collapse">
                <thead>
                  <tr class="text-xs font-medium text-n-slate-11">
                    <th class="px-3 py-2 text-start">
                      {{ t('PORTAL_GROUPS.DETAIL.CONTACT_NAME') }}
                    </th>
                    <th class="px-3 py-2 text-start">
                      {{ t('PORTAL_GROUPS.DETAIL.PHONE') }}
                    </th>
                    <th class="px-3 py-2 text-start">
                      {{ t('PORTAL_GROUPS.DETAIL.COMPANIES_OF_CONTACT') }}
                    </th>
                    <th class="px-3 py-2 text-start">
                      {{ t('PORTAL_GROUPS.DETAIL.STATUS') }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="contact in group.contatos"
                    :key="contact.id"
                    class="border-t border-n-weak"
                  >
                    <td class="px-3 py-2.5 font-medium text-n-slate-12">
                      {{ contact.name }}
                    </td>
                    <td class="px-3 py-2.5 text-n-slate-11">
                      {{ contact.phone || t('PORTAL_GROUPS.DETAIL.NO_PHONE') }}
                    </td>
                    <td class="px-3 py-2.5 text-n-slate-11">
                      {{ (contact.empresas || []).join(', ') }}
                    </td>
                    <td class="px-3 py-2.5">
                      <PortalGroupActiveBadge :active="contact.active" />
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <p
            v-if="!group.empresas?.length && !group.contatos?.length"
            class="mb-0 text-sm text-n-slate-11"
          >
            {{ t('PORTAL_GROUPS.DETAIL.NO_MEMBERS') }}
          </p>
        </template>
      </div>
    </main>
  </section>
</template>
