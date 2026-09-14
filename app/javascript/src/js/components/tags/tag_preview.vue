<template>
  <div class="tag-preview-area" :disabled="!enabled">
    <div class="tag-preview" v-if="tagRecords.length && enabled">
      <tag-preview-tag v-for="(tag, i) in tagRecords" :key="i" :tag="tag"></tag-preview-tag>
    </div>
    <a href="#" @click.prevent="togglePreview()">{{ enabled ? 'Hide' : 'Show' }} tag preview</a>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch } from "vue";
import ToastManager from "@/utility/Toast";
import HTTP from "@/utility/HTTP";
import tagPreviewTag from './tag_preview_tag.vue';
import LStorage from '@/utility/storage/Local';
import type { PreviewTag } from "./types";

const props = defineProps<{ tags: string }>();

const tagCache = reactive<Record<string, PreviewTag>>({});
const enabled = ref(LStorage.Posts.TagPreview);
let debounceHandle: ReturnType<typeof setTimeout>;

const tagsArray = computed(() =>
  [...new Set(props.tags.toLowerCase().replace(/\r?\n|\r/g, ' ').trim().split(/\s+/).filter(Boolean))]);

const tagRecords = computed<PreviewTag[]>(() => {
  const result: PreviewTag[] = [];
  const implications = new Map<string, string[]>();

  for (const input of tagsArray.value) {
    const tag = tagCache[input];
    if (tag) {
      // Copy so the duplicate/impliedBy flags below never write through to the cache.
      result.push({ ...tag });

      if (tag.implies && Array.isArray(tag.implies)) {
        for (const implication of tag.implies) {
          if (!implications.has(implication)) {
            implications.set(implication, []);
          }
          implications.get(implication).push(tag.name);
        }
      }
    } else {
      result.push({
        id: -1,
        name: input,
        category: 0,
      });
    }
  }

  const seen = new Set();
  for (const tag of result) {
    const name = tag.alias || tag.resolved || tag.name;
    if (seen.has(name)) {
      tag.duplicate = true;
    } else {
      seen.add(name);
    }
  }

  // Aliases do not need to be added. They will be displayed by their original input via the alias field.

  for (const implication of implications.keys()) {
    // Any tag implied by any other is always marked as implied.
    // This is more useful for quick relation mapping and discovery of the existence of implications.
    const current = result.find(tag => tag.name === implication);
    if (current) {
      current.impliedBy = implications.get(implication);
    } else {
      const implied = tagCache[implication];
      if (!implied) continue;
      result.push({ ...implied, impliedBy: implications.get(implication) });
    }
  }

  return result;
});

watch(() => props.tags, () => {
  clearTimeout(debounceHandle);
  debounceHandle = setTimeout(() => {
    if (enabled.value) {
      fetchTagPreview();
    }
  }, 1000);
}, { immediate: true });

function togglePreview() {
  enabled.value = !enabled.value;
  LStorage.Posts.TagPreview = enabled.value;
  if (enabled.value) {
    fetchTagPreview();
  }
}

async function fetchTagPreview() {
  const missing = tagsArray.value.filter(t => !tagCache[t]);
  if (missing.length === 0) return;

  try {
    // Form-urlencoded so Rails reads params[:tags]; CSRF added by HTTP.post.
    const response = await HTTP.post('/tags/preview.json', new URLSearchParams({ tags: missing.join(' ') }));
    if (!response.ok) throw new Error(await response.text().catch(() => ""));
    const result = await response.json();
    for (const tag of result)
      tagCache[tag.name] = tag;
  } catch (error) {
    ToastManager.alert("Error loading tag preview: " + (error.message || "Unknown error"));
    console.error("Tag preview error:", error);
  }
}
</script>
