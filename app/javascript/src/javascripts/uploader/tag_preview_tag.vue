<template>
  <span v-if="tag.type === 'alias'" class="tag-preview tag-preview-alias">
    <del><tag-link :name="tag.a" :tagType="tag.tagTypeA"></tag-link></del>
    → <tag-link :name="tag.b" :tagType="tag.tagTypeB"></tag-link>
  </span>
  <span v-else-if="tag.type === 'implication'" class="tag-preview tag-preview-implication">
    <tag-link :name="tag.a" :tagType="tag.tagTypeA"></tag-link>
    ⇒ <tag-link :name="tag.b" :tagType="tag.tagTypeB"></tag-link>
  </span>
  <span v-else class="tag-preview">
    <tag-link :name="tag.a" :tagType="tag.tagTypeA"></tag-link>
  </span>
</template>

<script>
import tagLink from "./tag_link.vue";

export default {
  components: {
    "tag-link": tagLink,
  },
  props: ["tag"],
}
</script>
