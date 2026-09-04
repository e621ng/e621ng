<template>
    <div class="related-tags flex-wrap">
        <div class="related-section" v-for="group in tagGroups" :key="group.title">
            <div class="related-items" v-for="tags, i in splitTags(group.tags)" :key="i">
                <div class="related-title" v-if="i === 0">{{group.title}}</div>
                <div class="related-item" v-for="tag in tags" :key="tag.name">
                    <a :class="tagClasses(tag)" :href="tagLink(tag)" @click.prevent="toggle(tag)">{{tag.name}}</a>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
  import { tagSorter } from './tag_field.js';

  export default {
    props: ['tags', 'related', 'loading', 'uploadedTags', 'recentTags'],
    data: function () {
      // uploads#new passes these as props (from the UploadData model). On posts#show the
      // component is mounted without them and falls back to the legacy global, which
      // RelatedTag.ts populates before mount. Sort a copy so the source array is untouched.
      return {
        uploaded: this.uploadedTags ?? (window.uploaderSettings?.uploadTags || []),
        recent: (this.recentTags ?? (window.uploaderSettings?.recentTags || [])).slice().sort(tagSorter),
      };
    },
    methods: {
      toggle: function (tag) {
        this.$emit('tag-active', tag.name, !this.tagActive(tag));
      },
      tagLink: function (tag) {
        return '/wiki_pages/show_or_new?title=' + encodeURIComponent(tag.name);
      },
      tagActive: function (tag) {
        return this.tags.indexOf(tag.name) !== -1;
      },
      tagClasses: function (tag) {
        var classes = {'tag-active': this.tagActive(tag)};
        classes['tag-type-' + tag.category_id] = true;
        return classes;
      },
      splitTags: function (tags) {
        var chunkArray = function (arr, size) {
          var chunks = [];
          for (var i = 0; i < arr.length; i += size) {
            chunks.push(arr.slice(i, i + size));
          }
          return chunks;
        };
        return chunkArray(tags, 15);
      }
    },
    computed: {
      tagGroups: {
        get: function () {
          const groups = [];
          if (this.uploaded && this.uploaded.length) {
            groups.push({
              title: "Quick Tags",
              tags: this.uploaded
            });
          }
          if (this.recent && this.recent.length) {
            groups.push({
              title: "Recent",
              tags: this.recent
            });
          }
          if (this.related && this.related.length) {
            for (let i = 0; i < this.related.length; i++) {
              groups.push(this.related[i]);
            }
          }
          if (this.loading) {
            groups.push({title: 'Loading Related Tags', tags: [['', '', '']]});
          }
          return groups;
        }
      }
    }
  }
</script>
