<template>
  <div class="related-tags flex-wrap">
    <div class="related-section" v-for="group in tagGroups" :key="group.title">
      <div class="related-items" v-for="tags, i in chunkTags(group.tags)" :key="i">
        <div class="related-title" v-if="i === 0">{{group.title}}</div>
        <div class="related-item" v-for="tag in tags" :key="tag.name">
          <a :class="tagClasses(tag)" :href="tagLink(tag)" @click.prevent="toggle(tag)">{{tag.name}}</a>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
  import { computed } from "vue";
  import { tagSorter } from './tag_field';
  import type { RelatedTag, RelatedTagGroup } from "@/utility/RelatedTags";

  const props = withDefaults(defineProps<{
    tags: string[];
    related?: RelatedTagGroup[];
    loading?: boolean;
    uploadedTags?: RelatedTag[];
    recentTags?: RelatedTag[];
  }>(), { related: () => [], loading: false, uploadedTags: () => [], recentTags: () => [] });

  const emit = defineEmits<{ "tag-active": [name: string, active: boolean] }>();

  // Both consumers pass these as props (uploads#new from the UploadData model,
  // posts#show from the bootstrap). Sort a copy so the source array is untouched.
  const uploaded = props.uploadedTags ?? [];
  const recent = (props.recentTags ?? []).slice().sort(tagSorter);

  function tagActive(tag: RelatedTag) {
    return props.tags.indexOf(tag.name) !== -1;
  }
  function toggle(tag: RelatedTag) {
    emit('tag-active', tag.name, !tagActive(tag));
  }
  function tagLink(tag: RelatedTag) {
    return '/wiki_pages/show_or_new?title=' + encodeURIComponent(tag.name);
  }
  function tagClasses(tag: RelatedTag) {
    const classes: Record<string, boolean> = { 'tag-active': tagActive(tag) };
    classes['tag-type-' + tag.category_id] = true;
    return classes;
  }
  function chunkTags(tags: RelatedTag[]) {
    const chunks: RelatedTag[][] = [];
    for (let i = 0; i < tags.length; i += 15) {
      chunks.push(tags.slice(i, i + 15));
    }
    return chunks;
  }

  const tagGroups = computed<RelatedTagGroup[]>(() => {
    const groups: RelatedTagGroup[] = [];
    if (uploaded && uploaded.length) {
      groups.push({ title: "Quick Tags", tags: uploaded });
    }
    if (recent && recent.length) {
      groups.push({ title: "Recent", tags: recent });
    }
    if (props.related && props.related.length) {
      for (let i = 0; i < props.related.length; i++) {
        groups.push(props.related[i]);
      }
    }
    if (props.loading) {
      // Legacy skeleton row: one empty related-item under the loading title.
      groups.push({ title: 'Loading Related Tags', tags: [['', '', '']] as unknown as RelatedTag[] });
    }
    return groups;
  });
</script>
