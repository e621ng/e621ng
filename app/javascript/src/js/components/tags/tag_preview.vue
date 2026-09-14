<template>
  <div class="tag-preview-area" :disabled="!enabled">
    <div class="tag-preview" v-if="tagRecords.length && enabled">
      <tag-preview-tag v-for="(tag, i) in tagRecords" :key="i" :tag="tag"></tag-preview-tag>
    </div>
    <a href="#" @click.prevent="togglePreview()">{{ enabled ? 'Hide' : 'Show' }} tag preview</a>
  </div>
</template>

<script>
import ToastManager from "@/utility/Toast";
import HTTP from "@/utility/HTTP";
import tagPreviewTag from './tag_preview_tag.vue';
import LStorage from '@/utility/storage/Local.js';

export default {
  props: ['tags'],
  components: {
    'tag-preview-tag': tagPreviewTag,
  },
  data() {
    return {
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
    async fetchTagPreview() {
      const missing = this.tagsArray.filter(t => !this.tagCache[t]);
      if (missing.length === 0) return;

      try {
        // Form-urlencoded so Rails reads params[:tags]; CSRF added by HTTP.post.
        const response = await HTTP.post('/tags/preview.json', new URLSearchParams({ tags: missing.join(' ') }));
        if (!response.ok) throw new Error(await response.text().catch(() => ""));
        const result = await response.json();
        for (const tag of result)
          this.tagCache[tag.name] = tag;
      } catch (error) {
        ToastManager.alert("Error loading tag preview: " + (error.message || "Unknown error"));
        console.error("Tag preview error:", error);
      }
    },
  },
};
</script>
