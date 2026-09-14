<template>
  <div>
    <artist-tag-input v-model="model"></artist-tag-input>
    <div v-if="verifiedArtistTags.length" class="upload-artist-tags">
      <div>Linked artist tags:</div>
      <button
        v-for="name in verifiedArtistTags"
        :key="name"
        type="button"
        class="toggle-button"
        @click="toggle(name)"
      >{{ name }}</button>
    </div>
  </div>
</template>

<script setup lang="ts">
  // The artist field as a self-registering tag source. Wraps the (untouched)
  // artist_tag_input and renders the linked-artist buttons declaratively.
  import { ref, inject, onMounted, onBeforeUnmount } from "vue";
  import artistTagInput from "./artist_tag_input.vue";
  import * as TagField from "@/components/tags/tag_field.js";
  import UploadData from "@/models/UploadData";
  import { tagRegistryKey, type TagSource } from "./registry";

  const props = withDefaults(defineProps<{ order?: number }>(), { order: 0 });

  const model = ref("");
  const verifiedArtistTags: string[] = UploadData.verifiedArtistTags;
  const registry = inject(tagRegistryKey)!;

  function toggle (name: string): void {
    model.value = TagField.splitTags(model.value).includes(name)
      ? TagField.removeTag(model.value, name)
      : TagField.addTags(model.value, [name]);
  }

  const descriptor: TagSource = {
    role: "artist",
    order: props.order,
    currentTags: () => TagField.splitTags(model.value),
    addTags: (tags) => { model.value = TagField.addTags(model.value, tags); },
    removeTag: (tag) => { model.value = TagField.removeTag(model.value, tag); },
  };

  onMounted(() => registry.register(descriptor));
  onBeforeUnmount(() => registry.unregister(descriptor));
</script>
