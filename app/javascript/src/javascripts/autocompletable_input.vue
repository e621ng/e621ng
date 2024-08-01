<template>
  <input :list="listId" v-bind="$attrs" v-model="value">
  <datalist :id="listId">
    <option v-for="(entry, index) in entries" :value="entry" :key="index"></option>
  </datalist>
</template>

<script>
import LStorage from "./utility/storage";
export default {
  props: ["listId", "addToList", "modelValue"],
  computed: {
    value: {
      get() {
        return this.modelValue;
      },
      set(value) {
        this.$emit("update:modelValue", value);
      }
    }
  },
  data() {
    return {
      entries: this.currentEntries(),
    }
  },
  methods: {
    currentEntries() {
      return LStorage.getObject(`autocomplete-${this.listId}`) || [];
    },
  },
  watch: {
    addToList(value) {
      const maxEntries = 50;
      const entries = new Set([value.trim(), ...this.currentEntries()]);
      LStorage.putObject(`autocomplete-${this.listId}`, [...entries].slice(0, maxEntries));
    }
  },
}
</script>
