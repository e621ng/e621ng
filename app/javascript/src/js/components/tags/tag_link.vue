<template>
  <a :class="'tag-type-' + tagType" :href="'/wiki_pages/show_or_new?title=' + name" target="_blank">
    {{ displayName }}
  </a>
</template>

<script setup lang="ts">
  import { computed } from "vue";

  const props = defineProps<{ tagType: number; name: string; wrap?: boolean }>();

  const displayName = computed(() =>
    props.wrap ? props.name.replace(/_/g, "_\u200B") : props.name);
</script>
