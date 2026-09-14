<template>
  <div class="upload-source-row" v-bind:index="index">
    <input
      type="text"
      size="50"
      placeholder="Ex: https://example.com/artist/post/12345"
      v-model="model"
      @keyup.enter="fadd"
      @keyup.up="focusPrev"
      @keyup.down="focusNext"
      @paste="paste"
    />
    <button @click="remove">&times;</button>
  </div>
</template>

<script setup lang="ts">
  const model = defineModel<string>();
  const props = defineProps<{ index: number }>();
  const emit = defineEmits<{
    fadd: [];
    delete: [];
    madd: [event: ClipboardEvent];
    navigate: [index: number];
  }>();

  function fadd() { emit("fadd"); }
  function remove() { emit("delete"); }
  function paste($event: ClipboardEvent) { emit("madd", $event); }
  function focusNext() { emit("navigate", props.index + 1); }
  function focusPrev() { emit("navigate", props.index - 1); }
</script>
