<template>
  <textarea
    class="tag-textarea"
    rows="2"
    v-model="model"
    :id="fieldId"
    :placeholder="placeholder"
    data-autocomplete="tag-edit"
  ></textarea>
</template>

<script setup lang="ts">
  // A role-tagged free-text tag source (character / species / content). Registers
  // with the coordinator; contributes its tokens and accepts role-routed imports.
  import { ref, inject, onMounted, onBeforeUnmount } from "vue";
  import * as TagField from "@/components/tags/tag_field.js";
  import { tagRegistryKey, type TagSource } from "./registry";

  const props = withDefaults(defineProps<{
    role: string;
    fieldId?: string;
    placeholder?: string;
    order?: number;
  }>(), { fieldId: "", placeholder: "", order: 0 });

  const model = ref("");
  const registry = inject(tagRegistryKey)!;

  const descriptor: TagSource = {
    role: props.role,
    order: props.order,
    currentTags: () => TagField.splitTags(model.value),
    addTags: (tags) => { model.value = TagField.addTags(model.value, tags); },
    removeTag: (tag) => { model.value = TagField.removeTag(model.value, tag); },
  };

  onMounted(() => registry.register(descriptor));
  onBeforeUnmount(() => registry.unregister(descriptor));
</script>
