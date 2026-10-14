<template>
  <div
    class="tag-preview-tag" 
    :data-id="tag.id" 
    :data-category="tag.category" 
    :data-name="tag.name" 
    :data-resolved="tag.resolved"
    :data-alias="tag.alias"
    :data-implied="tag.impliedBy?.join(' ')"
    :data-count="tag.post_count"
  >
    <tag-link :name="tag.alias || tag.resolved || tag.name" :tagType="tag.category" :wrap="true"></tag-link>
    <span v-if="tag.id == null" class="new">new</span>
    <span v-else-if="isInvalid" class="invalid">invalid</span>
    <span v-else-if="tag.duplicate" class="duplicate">duplicate</span>
    <span v-else-if="tag.impliedBy && tag.impliedBy.length > 0" class="implied" :title="getImpliedTooltip(tag)">implied</span>
    <span v-else-if="tag.post_count === 0" class="empty">empty</span>
    <span v-else-if="tag.post_count != null" :class="{'post-count': true, 'underused': tag.post_count === 1 && isGeneral}">{{ formatTagCount(tag.post_count) }}</span>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import tagLink from "./tag_link.vue";
import TagCategories from "@/utility/TagCategories";
import type { PreviewTag } from "./types";

const props = defineProps<{ tag: PreviewTag }>();

const isInvalid = computed(() => props.tag.category === TagCategories.idFor("invalid"));
const isGeneral = computed(() => props.tag.category === TagCategories.idFor("general"));

function formatTagCount(count: number) {
  return new Intl.NumberFormat('en', { notation: 'compact', compactDisplay: 'short' }).format(count).toLowerCase();
}
function getImpliedTooltip(tag: PreviewTag) {
  return `Implied by ${tag.impliedBy.join(", ")}`;
}
</script>
