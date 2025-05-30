<template>
  <div>
    <div v-show="loading">Fetching tags...</div>
    <div class="tag-preview">
      <tag-preview-tag
        v-for="(tag, i) in tags"
        :key="i"
        :tag="tag"
      ></tag-preview-tag>
    </div>
  </div>
</template>

<script>
import tagPreviewTag from './tag_preview_tag.vue';

export default {
  props: ['tags', 'loading'],
  components: {
    'tag-preview-tag': tagPreviewTag,
  },
  computed: {
    splitTags() {
      const sorted = [...this.tags].sort((a, b) =>
        a.name.localeCompare(b.name)
      );

      const chunkArray = (arr, size) => {
        const chunks = [];
        for (let i = 0; i < arr.length; i += size) {
          chunks.push(arr.slice(i, i + size));
        }
        return chunks;
      };

      return chunkArray(sorted, 15);
    },
  },
};
</script>
