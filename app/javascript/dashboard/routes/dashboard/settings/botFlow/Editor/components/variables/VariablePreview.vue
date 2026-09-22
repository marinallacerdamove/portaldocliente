<script setup>
defineProps({
  entry: { type: Object, required: true },
});

const hasSampleValue = entry =>
  entry.sampleValue !== undefined &&
  entry.sampleValue !== null &&
  entry.sampleValue !== '';
</script>

<template>
  <span class="text-xs text-n-slate-10 truncate w-full">
    {{ hasSampleValue(entry) ? entry.sampleValue : entry.originLabel }}
  </span>
</template>
