<template>
  <span class="tag-counter">
    <!-- eslint-disable-next-line vue/no-v-html -->
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      :class="['face', 'face-' + face]"
      v-html="faceIcon"
    ></svg>
    <span class="count">{{ countLabel }}</span>
  </span>
</template>

<script setup lang="ts">
import { computed } from "vue";
import SVGIcon from "@/utility/SVGIcon";
import { splitTags } from "./tag_field";

// The tag counter for a tag-string input, styled by specific/tags.scss (.tag-counter / .face / .count).
const props = withDefaults(defineProps<{ tags?: string }>(), { tags: "" });

// Unique raw tokens, no case folding — matches the retired Post.update_tag_count.
const count = computed(() => new Set(splitTags(props.tags)).size);
const countLabel = computed(() => count.value === 1 ? "1 tag" : count.value + " tags");
const face = computed(() => {
  if (count.value < 15) return "frown";
  if (count.value < 25) return "meh";
  return "smile";
});
const faceIcon = computed(() => SVGIcon.ICONS["face_" + face.value]);
</script>
