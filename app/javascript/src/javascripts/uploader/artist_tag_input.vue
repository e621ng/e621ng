<template>
  <div>
    <textarea
      class="tag-textarea"
      :value="modelValue"
      @input="handleInput"
      id="post_artist"
      rows="2"
      placeholder="Ex: artist_name unknown_artist anonymous_artist etc."
      data-autocomplete="tag-edit"
    ></textarea>
    <div v-if="notices.length" class="artist-tag-notices">
      <div class="artist-tag-label">Click to select an option:</div>
      <div v-for="(notice, index) in notices" :key="`${notice.type}:${notice.tag}:${index}`" class="artist-tag-notice" :data-type="notice.type">
        <template v-if="notice.type === 'make_artist'">
          <a href="#" @click.prevent="makeArtistTag(notice.tag)">
            <div><b>{{ notice.tag }}</b> can be made into an artist tag</div>
          </a>
        </template>
        <template v-else>
          <a href="#" @click.prevent="removeWrongTag(notice.tag)">
            <div><b>{{ notice.tag }}</b> is a {{ notice.detail }}</div>
          </a>
        </template>
      </div>
    </div>
  </div>
</template>

<script>
const CATEGORY_NAMES = ['general', 'artist', 'contributor', 'copyright', 'character', 'species', 'invalid', 'meta', 'lore'];

export default {
  name: 'ArtistTagInput',
  props: {
    modelValue: {
      type: String,
      default: '',
    },
  },
  emits: ['update:modelValue'],
  data() {
    return {
      notices: [],
      debounceTimer: null,
    };
  },
  watch: {
    modelValue() {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = setTimeout(() => this.checkTags(), 1000);
    },
  },
  beforeUnmount() {
    clearTimeout(this.debounceTimer);
    this.debounceTimer = null;
  },
  methods: {
    handleInput(event) {
      this.$emit('update:modelValue', event.target.value);
    },

    async checkTags() {
      const tags = (this.modelValue || '').trim().split(/\s+/).filter(t => t && !t.startsWith('artist:'));
      if (tags.length === 0) {
        this.notices = [];
        return;
      }

      let data;
      try {
        const params = new URLSearchParams({ 'search[name]': tags.join(','), 'search[hide_empty]': 'false' });
        const response = await fetch(`/tags.json?${params}`);
        if (!response.ok) {
          this.notices = [];
          return;
        }
        data = await response.json();
      } catch (_) {
        this.notices = [];
        return;
      }

      const tagMap = Object.create(null);
      for (const tag of data) {
        tagMap[tag.name] = tag;
      }

      const notices = [];
      for (const tagName of tags) {
        const tag = tagMap[tagName.toLowerCase()];
        if (!tag || (tag.category === 0 && tag.post_count === 0)) {
          notices.push({ tag: tagName, type: 'make_artist' });
        } else if (tag.category === 1) {
          // Already an artist tag — nothing to show
        } else if (tag.category === 0) {
          notices.push({ tag: tagName, type: 'wrong', detail: `a populated general tag` });
        } else {
          const categoryName = CATEGORY_NAMES[tag.category] || 'unknown';
          notices.push({ tag: tagName, type: 'wrong', detail: `a ${categoryName} tag` });
        }
      }
      this.notices = notices;
    },

    makeArtistTag(tagName) {
      const parts = (this.modelValue || '').trim().split(/\s+/).filter(t => t);
      const idx = parts.indexOf(tagName);
      if (idx !== -1) {
        parts[idx] = `artist:${tagName}`;
      }
      this.$emit('update:modelValue', parts.join(' ') + ' ');
    },

    removeWrongTag(tagName) {
      const parts = (this.modelValue || '').trim().split(/\s+/).filter(t => t && t !== tagName);
      this.$emit('update:modelValue', parts.join(' ') + ' ');
    },
  },
};
</script>
