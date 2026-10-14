<template>
  <div>
    <div class="header">
      <label for="post_tag_string">Tags</label>
      <tag-counter :tags="tags" />
    </div>
    <textarea
      class="tag-textarea"
      id="post_tag_string"
      v-model="tags"
      rows="5"
      data-autocomplete="tag-edit"
      ref="otherTags"
      name="post[tag_string]"
      :spellcheck="false"
    ></textarea>
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
      <related-tags
        v-show="expandRelated"
        :tags="tagsArray"
        :related="relatedTags"
        :loading="loadingRelated"
        :uploaded-tags="uploadTags"
        :recent-tags="recentTags"
        @tag-active="pushTag"
      ></related-tags>
    </div>
  </div>
</template>

<script setup lang="ts">
  import { computed, onMounted, ref } from "vue";
  import RelatedTags from "@/components/tags/related.vue";
  import TagPreview from "@/components/tags/tag_preview.vue";
  import TagCounter from "@/components/tags/tag_counter.vue";
  import { addTagGrouped, removeTagGrouped, splitTags } from "@/components/tags/tag_field";
  import { fetchRelatedTags, selectedText } from "@/components/tags/related_tags";
  import type { RelatedTag, RelatedTagGroup } from "@/components/tags/types";
  import Autocomplete from "@/components/autocomplete";
  import CurrentUser from "@/models/CurrentUser";
  import TagCategories from "@/utility/TagCategories";

  // Root props, provided by the TagEditor.ts bootstrap (postTags from the
  // mount div's data attribute, the tag lists from /users/upload_tags.json).
  const props = withDefaults(defineProps<{
    postTags?: string;
    uploadTags?: RelatedTag[];
    recentTags?: RelatedTag[];
  }>(), { postTags: "", uploadTags: () => [], recentTags: () => [] });

  const tags = ref(props.postTags);
  const expandRelated = ref(true);
  const relatedTags = ref<RelatedTagGroup[]>([]);
  const loadingRelated = ref(false);
  let lastRelatedCategoryId: number | undefined;

  const otherTags = ref<HTMLTextAreaElement>();

  onMounted(() => {
    setTimeout(() => {
      // Work around that browsers seem to take a few frames to acknowledge that the element is there before it can be focused.
      const el = otherTags.value;
      if (!el) return; // unmounted before the timer fired
      el.style.height = el.scrollHeight + "px";
      el.focus();
    }, 20);
    if (!CurrentUser.settings.autocomplete)
      return;
    Autocomplete.initialize_autocomplete("tag-edit");
  });

  const tagsArray = computed(() => splitTags(tags.value.toLowerCase()));
  const relatedText = computed(() => expandRelated.value ? "<<" : ">>");

  function toggleRelated () {
    expandRelated.value = !expandRelated.value;
  }

  function pushTag (tag: string, add: boolean) {
    tags.value = add ? addTagGrouped(tags.value, tag) : removeTagGrouped(tags.value, tag);
  }

  async function findRelated (categoryName?: string) {
    const categoryId = categoryName ? TagCategories.idFor(categoryName) : undefined;
    if (loadingRelated.value)
      return;
    if (relatedTags.value.length > 0 && lastRelatedCategoryId === categoryId) {
      relatedTags.value = [];
      return;
    }
    expandRelated.value = true;
    loadingRelated.value = true;
    relatedTags.value = [];
    const query = selectedText(otherTags.value!) ?? tags.value;
    try {
      relatedTags.value = await fetchRelatedTags(query, categoryId);
      lastRelatedCategoryId = categoryId;
    } catch {
      // A failed lookup just shows no related tags (relatedTags stays []).
    } finally {
      loadingRelated.value = false;
    }
  }
</script>
