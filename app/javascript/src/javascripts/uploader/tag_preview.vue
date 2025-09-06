<template>
  <div class="tag-preview-area" :disabled="!enabled">
    <div class="tag-preview" v-if="tagRecords.length && enabled">
      <tag-preview-tag v-for="(tag, i) in tagRecords" :key="i" :tag="tag"></tag-preview-tag>
    </div>
    <a href="#" @click.prevent="togglePreview()">{{ enabled ? 'Hide' : 'Show' }} tag preview</a>
  </div>
</template>

<script>
import tagPreviewTag from './tag_preview_tag.vue';
import LStorage from '../utility/storage';

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
      enabled: LStorage.Posts.TagPreview,
    };
  },
  computed: {
    tagsArray() {
      return [...new Set(this.tags.toLowerCase().replace(/\r?\n|\r/g, ' ').trim().split(/\s+/).filter(Boolean))];
    },
    tagRecords() {
      const result = new Map();
      const aliases = new Set();
      const implications = new Set();

      for (const input of this.tagsArray) {
        const tag = this.tagCache[input];
        if (!tag) continue;

        // Delete previous instance to update order.
        if (result.has(input)) result.delete(input);
        result.set(input, tag);

        if (tag.alias) {
          aliases.add(tag.alias);
        }

        if (tag.implies && Array.isArray(tag.implies)) {
          implications.add(...tag.implies);
          // This allows implications to be ordered right after the tag that implies them.
          // If the tag is in the input, we delete it to defer to original order.
          for (const implication of tag.implies) {
            const implied = this.tagCache[implication];
            if (!implied) continue;
            result.set(implication, implied);
          }
        }
      }

      for (const alias of aliases) {
        // Aliases will be displayed by their original input via the alias field.
        result.delete(alias);
      }

      for (const implication of implications) {
        const implied = result.get(implication);
        if (!implied) continue;
        // Any tag implied by any other is always marked as implied. 
        // This is more useful for quick relation mapping and discovery of the existence of implications.
        result.set(implication, { ...implied, implied: true });
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
          if (this.enabled) {
            this.fetchTagPreview();
          }
        }, 1000);
      }
    }
  },
  methods: {
    togglePreview() {
      this.enabled = !this.enabled;
      LStorage.Posts.TagPreview = this.enabled;
      if (this.enabled) {
        this.fetchTagPreview();
      }
    },
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
          let details = result.responseText || "Unknown error";
          Danbooru.error("Error loading tag preview: " + details);
          console.error("Tag preview error:", result);
        },
      });
    },
  },
};
</script>
