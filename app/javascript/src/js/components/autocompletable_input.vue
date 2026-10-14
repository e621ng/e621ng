<template>
  <input :list="listId" v-bind="$attrs" v-model="value">
  <datalist :id="listId">
    <option v-for="(entry, index) in entries" :value="entry" :key="index"></option>
  </datalist>
</template>

<script setup lang="ts">
import { ref, computed, watch } from "vue";
import LStorage from "@/utility/storage/Local";

const props = defineProps<{
  listId: string;
  addToList?: string;
  modelValue?: string;
}>();
const emit = defineEmits<{ "update:modelValue": [value: string] }>();

const value = computed({
  get: () => props.modelValue,
  set: (newValue: string) => emit("update:modelValue", newValue),
});

function currentEntries (): string[] {
  return (LStorage.Raw.getObject(`autocomplete-${props.listId}`) as string[]) || [];
}

const entries = ref<string[]>(currentEntries());

watch(() => props.addToList, (newValue) => {
  if (!newValue || !newValue.trim()) return;
  const maxEntries = 50;
  const updated = new Set([newValue.trim(), ...currentEntries()]);
  LStorage.Raw.putObject(`autocomplete-${props.listId}`, [...updated].slice(0, maxEntries));
});
</script>
