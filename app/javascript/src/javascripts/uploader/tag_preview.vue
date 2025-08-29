<template>
  <div>
    <div v-if="loading && tagRecords.length === 0">Fetching tags...</div>
    <div class="tag-preview">
      <tag-preview-tag v-for="(tag, i) in tagRecords" :key="i" :tag="tag"></tag-preview-tag>
    </div>
  </div>
</template>

<script>
import tagPreviewTag from './tag_preview_tag.vue';

export default {
  props: ['tags'],
  components: {
    'tag-preview-tag': tagPreviewTag,
  },
  data() {
    return {
      loading: false,
      tagCache: {},
      _tagPreviewDebounce: null,
    };
  },
  computed: {
    tagsArray() {
      return [...new Set(this.tags.toLowerCase().replace(/\r?\n|\r/g, ' ').trim().split(/\s+/).filter(Boolean))];
    },
    tagRecords() {
      return this.tagsArray.map(t => this.tagCache[t]).filter(Boolean);
    },
  },
  watch: {
    tags: {
      immediate: true,
      handler() {
        clearTimeout(this._tagPreviewDebounce);
        this._tagPreviewDebounce = setTimeout(() => {
          this.fetchTagPreview();
        }, 1000);
      }
    }
  },
  methods: {
    fetchTagPreview() {
      const missing = this.tagsArray.filter(t => !this.tagCache[t]);
      if (missing.length === 0) return;

      this.loading = true;
      $.ajax('/tags/preview.json', {
        method: 'POST',
        data: { tags: missing.join(' ') },
        success: (result) => {
          for (const tag of result) {
            this.tagCache[tag.name] = tag;
          }
          this.loading = false;
        },
        error: (result) => {
          this.loading = false;
          Danbooru.error("Error loading tag preview " + JSON.stringify(result));
        },
      });
    },
  },
};
</script>
