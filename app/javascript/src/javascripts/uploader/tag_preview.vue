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
      const result = [];
      const implications = new Map();

      for (const input of this.tagsArray) {
        const tag = this.tagCache[input];
        if (tag) {
          result.push(tag);

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
          const implied = this.tagCache[implication];
          if (!implied) continue;
          result.push({ ...implied, impliedBy: implications.get(implication) });
        }
      }

      return result;
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
