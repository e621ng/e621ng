<template>
    <div>
        <div v-show="loading">Fetching tags...</div>
        <div class="related-tags flex-wrap">
            <div class="related-items" v-for="sTags, i in splitTags" :key="i">
                <tag-preview-tag v-for="tag, $idx in sTags" :key="$idx" :tag="tag"></tag-preview-tag>
            </div>
        </div>
        <div>
            <a href="#" @click.prevent="close">Close Preview</a>
        </div>
    </div>
</template>

<script>
  import tagPreviewTag from './tag_preview_tag.vue';

  export default {
    props: ['tags', 'loading'],
    components: {
      'tag-preview-tag': tagPreviewTag
    },
    methods: {
      close: function () {
        this.$emit('close');
      }
    },
    computed: {
      splitTags: function () {
        var newTags = this.tags.concat([]);
        newTags.sort(function (a, b) {
          return a.a === b.a ? 0 : (a.a < b.a ? -1 : 1);
        });
        var chunkArray = function (arr, size) {
          var chunks = [];
          for (var i = 0; i < arr.length; i += size) {
            chunks.push(arr.slice(i, i + size));
          }
          return chunks;
        };
        return chunkArray(newTags, 15);
      }
    }
  }
</script>
