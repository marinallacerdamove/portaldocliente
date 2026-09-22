<script setup>
defineProps({
  title: { type: String, required: true },
});
</script>

<template>
  <div class="flex flex-col gap-3">
    <h5 class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
      {{ title }}
    </h5>
    <div class="flex flex-col gap-4">
      <slot />
    </div>
  </div>
</template>
