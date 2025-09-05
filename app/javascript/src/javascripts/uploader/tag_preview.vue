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
      const result = new Map();
      const aliases = new Set();

      for (const input of this.tagsArray) {
        const tag = this.tagCache[input];
        if (!tag) continue;

        result.set(input, tag);

        if (tag.alias) {
          aliases.add(tag.alias);
          const aliased = this.tagCache[tag.alias];
          if (aliased) {
            result.set(tag.alias, aliased);
          }
        }

        if (tag.implies && Array.isArray(tag.implies)) {
          for (const implied of tag.implies) {
            const impliedTag = this.tagCache[implied];
            if (impliedTag) {
              result.set(implied, impliedTag);
              if (impliedTag.alias) {
                aliases.add(impliedTag.alias);
              }
            }
          }
        }
      }

      for (const alias of aliases) {
        result.delete(alias);
      }

      return Array.from(result.values());
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
