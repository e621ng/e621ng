<template>
  <input :list="listId" v-bind="$attrs" v-model="modelValue">
  <datalist :id="listId">
    <option v-for="(entry, index) in entries" :value="entry" :key="index"></option>
  </datalist>
</template>

<script>
import LS from "./local_storage";
export default {
  props: ["listId", "addToList", "modelValue"],
  data() {
    return {
      entries: this.currentEntries(),
    }
  },
  methods: {
    currentEntries() {
      return LS.getObject(`autocomplete-${this.listId}`) || [];
    },
  },
  watch: {
    addToList(value) {
      const maxEntries = 20;
      const entries = new Set([value, ...this.currentEntries()]);
      LS.putObject(`autocomplete-${this.listId}`, [...entries].slice(0, maxEntries));
    }
  },
}
</script>
