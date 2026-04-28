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
            <div><b>{{ notice.tag }}</b> is {{ notice.detail }}</div>
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
      checkId: 0,
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

    async fetchTagsByName(tagNames) {
      try {
        const params = new URLSearchParams({ 'search[name]': tagNames.join(','), 'search[hide_empty]': 'false' });
        const response = await fetch(`/tags.json?${params}`);
        if (!response.ok) return {};
        const data = await response.json();
        const map = Object.create(null);
        for (const tag of data) map[tag.name] = tag;
        return map;
      } catch (_) {
        return {};
      }
    },

    async fetchAliases(tagNames) {
      try {
        const params = new URLSearchParams({ 'search[status]': 'active', 'search[antecedent_name]': tagNames.join(',') });
        const response = await fetch(`/tag_aliases.json?${params}`);
        if (!response.ok) return {};
        const data = await response.json();
        const map = Object.create(null);
        for (const alias of data) map[alias.antecedent_name] = alias.consequent_name;
        return map;
      } catch (_) {
        return {};
      }
    },

    async checkTags() {
      const id = ++this.checkId;

      const tags = (this.modelValue || '')
        .trim()
        .split(/\s+/)
        .filter((t) => {
          t = t.toLowerCase();
          return t && !(t.startsWith("artist:") || t.startsWith("art:"))
        });
      if (tags.length === 0) {
        this.notices = [];
        return;
      }

      const tagMap = await this.fetchTagsByName(tags);
      if (id !== this.checkId) return;

      // For zero-post tags, check if they're aliased away and use the consequent's data instead
      const zeroPostTags = tags.filter(t => { const tag = tagMap[t.toLowerCase()]; return !tag || tag.post_count === 0; });
      if (zeroPostTags.length > 0) {
        const aliasMap = await this.fetchAliases(zeroPostTags);
        if (id !== this.checkId) return;
        const consequentNames = Object.values(aliasMap);
        if (consequentNames.length > 0) {
          const consequentTagMap = await this.fetchTagsByName(consequentNames);
          if (id !== this.checkId) return;
          for (const [antecedent, consequent] of Object.entries(aliasMap)) {
            if (consequentTagMap[consequent]) tagMap[antecedent.toLowerCase()] = consequentTagMap[consequent];
          }
        }
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
