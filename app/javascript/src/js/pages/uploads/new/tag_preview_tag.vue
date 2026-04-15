<template>
  <div class="tag-preview-tag" 
       :data-id="tag.id" 
       :data-category="tag.category" 
       :data-name="tag.name" 
       :data-resolved="tag.resolved"
       :data-alias="tag.alias"
       :data-implied="tag.impliedBy?.join(' ')"
       :data-count="tag.post_count">
    <tag-link :name="tag.alias || tag.resolved || tag.name" :tagType="tag.category" :wrap="true"></tag-link>
    <span v-if="tag.id == null" class="new">new</span>
    <span v-else-if="tag.category === 6" class="invalid">invalid</span>
    <span v-else-if="tag.duplicate" class="duplicate">duplicate</span>
    <span v-else-if="tag.impliedBy && tag.impliedBy.length > 0" class="implied" :title="getImpliedTooltip(tag)">implied</span>
    <span v-else-if="tag.post_count === 0" class="empty">empty</span>
    <span v-else-if="tag.post_count != null" :class="{'post-count': true, 'underused': tag.post_count === 1 && tag.category === 0}">{{ formatTagCount(tag.post_count) }}</span>
  </div>
</template>

<script>
import tagLink from "./tag_link.vue";

export default {
  props: ["tag"],
  components: {
    "tag-link": tagLink,
  },
  methods: {
    formatTagCount(count) {
      return new Intl.NumberFormat('en', { notation: 'compact', compactDisplay: 'short' }).format(count).toLowerCase();
    },
    getImpliedTooltip(tag) {
      return `Implied by ${tag.impliedBy.join(", ")}`;
    },
  },
};
</script>
