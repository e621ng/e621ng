<template>
  <div>
    <textarea class="tag-textarea" id="post_tag_string" v-model="tags" rows="5" data-autocomplete="tag-edit"
      ref="otherTags" name="post[tag_string]" :spellcheck="false"></textarea>
    <tag-preview :tags="tags" />
    <div class="related-tag-functions">
      Related:
      <a href="#" @click.prevent="findRelated()">Tags</a> |
      <a href="#" @click.prevent="findRelated('artist')">Artists</a> |
      <a href="#" @click.prevent="findRelated('contributor')">Contributors</a> |
      <a href="#" @click.prevent="findRelated('copyright')">Copyrights</a> |
      <a href="#" @click.prevent="findRelated('character')">Characters</a> |
      <a href="#" @click.prevent="findRelated('species')">Species</a> |
      <a href="#" @click.prevent="findRelated('meta')">Metatags</a>
    </div>
    <div>
      <h3>Related Tags <a href="#" @click.prevent="toggleRelated">{{ relatedText }}</a></h3>
      <related-tags v-show="expandRelated" :tags="tagsArray" :related="relatedTags" :loading="loadingRelated"
        @tag-active="pushTag"></related-tags>
    </div>
  </div>
</template>

<script>
import relatedTags from "@/pages/uploads/new/related.vue";
import tagPreview from "@/pages/uploads/new/tag_preview.vue";
import { addTagGrouped, removeTagGrouped } from "@/pages/uploads/new/tag_field.js";
import Post from '../posts';
import Autocomplete from "@/components/autocomplete";
import CurrentUser from "@/models/CurrentUser";
import TagCategories from "@/utility/TagCategories";
import { fetchRelatedTags, selectedText } from "@/utility/RelatedTags";

export default {
  components: {
    'related-tags': relatedTags,
    'tag-preview': tagPreview
  },
  data() {
    return {
      expandRelated: true,
      tags: window.uploaderSettings.postTags,
      relatedTags: [],
      lastRelatedCategoryId: undefined,
      loadingRelated: false,
    };
  },
  mounted() {
    setTimeout(() => {
      // Work around that browsers seem to take a few frames to acknowledge that the element is there before it can be focused.
      const el = this.$refs.otherTags;
      el.style.height = el.scrollHeight + "px";
      el.focus();
    }, 20);
    if (!CurrentUser.settings.autocomplete)
      return;
    Autocomplete.initialize_autocomplete('tag-edit');
  },
  computed: {
    tagsArray() {
      return this.tags.toLowerCase().replace(/\r?\n|\r/g, ' ').split(' ');
    },
    relatedText() {
      return this.expandRelated ? "<<" : ">>";
    }
  },
  watch: {
    // Covers typing, autocomplete inserts (mouse included), paste, and pushTag.
    // Not immediate: the initial count is triggered by the e6ng:vue-mounted
    // handshake in posts.js.
    tags() {
      Post.update_tag_count();
    }
  },
  methods: {
    toggleRelated() {
      this.expandRelated = !this.expandRelated;
    },
    pushTag(tag, add) {
      this.tags = add ? addTagGrouped(this.tags, tag) : removeTagGrouped(this.tags, tag);
    },
    async findRelated(categoryName) {
      const categoryId = categoryName ? TagCategories.idFor(categoryName) : undefined;
      if (this.loadingRelated)
        return;
      if (this.relatedTags.length > 0 && this.lastRelatedCategoryId === categoryId) {
        this.relatedTags = [];
        return;
      }
      this.expandRelated = true;
      this.loadingRelated = true;
      this.relatedTags = [];
      const query = selectedText(this.$refs.otherTags) ?? this.tags;
      try {
        this.relatedTags = await fetchRelatedTags(query, categoryId);
        this.lastRelatedCategoryId = categoryId;
      } catch {
        // A failed lookup just shows no related tags (relatedTags stays []).
      } finally {
        this.loadingRelated = false;
      }
    }
  }
};
</script>
