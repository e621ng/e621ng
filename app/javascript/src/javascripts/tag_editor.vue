<template>
    <div>
        <div v-show="!preview.show">
            <textarea class="tag-textarea" id="post_tag_string" v-model="tags" rows="5" data-autocomplete="tag-edit"
                      ref="otherTags" name="post[tag_string]" :spellcheck="false" @keyup="updateTagCount"></textarea>
        </div>
        <div v-show="preview.show">
            <tag-preview :tags="preview.tags" :loading="preview.loading" @close="previewFinalTags"></tag-preview>
        </div>
        <div class="related-tag-functions">
            Related:
            <a href="#" @click.prevent="findRelated()">Tags</a> |
            <a href="#" @click.prevent="findRelated(1)">Artists</a> |
            <a href="#" @click.prevent="findRelated(3)">Copyrights</a> |
            <a href="#" @click.prevent="findRelated(4)">Characters</a> |
            <a href="#" @click.prevent="findRelated(5)">Species</a> |
            <a href="#" @click.prevent="findRelated(7)">Metatags</a> |
            <a href="#" @click.prevent="previewFinalTags">Preview Final Tags</a>
        </div>
        <div>
            <h3>Related Tags <a href="#" @click.prevent="toggleRelated">{{ relatedText }}</a></h3>
            <related-tags v-show="expandRelated" :tags="tagsArray" :related="relatedTags"
                          :loading="loadingRelated"
                          @tag-active="pushTag"></related-tags>
        </div>
    </div>
</template>

<script>
  import { nextTick } from 'vue';
  import relatedTags from './uploader/related.vue';
  import tagPreview from './uploader/tag_preview.vue';
  import Post from './posts';
  import Autocomplete from "./autocomplete.js.erb";
  import Utility from "./utility.js";

  function tagSorter(a, b) {
    return a.name > b.name ? 1 : -1;
  }

  export default {
    components: {
      'related-tags': relatedTags,
      'tag-preview': tagPreview
    },
    data() {
      return {
        preview: {
          loading: false,
          show: false,
          tags: []
        },
        expandRelated: true,
        tags: window.uploaderSettings.postTags,
        relatedTags: [],
        loadingRelated: false,
      };
    },
    mounted() {
      setTimeout(() => {
        // Work around that browsers seem to take a few frames to acknowledge that the element is there before it can be focused.
        const el = this.$refs.otherTags;
        el.style.height = el.scrollHeight + "px";
        el.focus();
        el.scrollIntoView();
      }, 20);
      if(Utility.meta("enable-auto-complete") !== "true")
        return;
      Autocomplete.initialize_tag_autocomplete();
    },
    computed: {
      tagsArray() {
        return this.tags.toLowerCase().replace(/\r?\n|\r/g, ' ').split(' ');
      },
      relatedText() {
        return this.expandRelated ? "<<" : ">>";
      }
    },
    methods: {
      updateTagCount() {
        Post.update_tag_count({target: $("#post_tag_string")});
      },
      toggleRelated() {
        this.expandRelated = !this.expandRelated;
      },
      pushTag(tag, add) {
        this.preview.show = false;
        if (add) {
          const tags = this.tags.toLowerCase().trim().replace(/\r?\n|\r/g, ' ').split(' ');
          if (tags.indexOf(tag) === -1) {
            // Ensure that input ends with a space, and if not, add one.
            if(this.tags.length && (this.tags[this.tags.length-1] !== ' '))
              this.tags += ' ';
            this.tags += tag + ' ';
          }
        } else {
          const groups = this.tags.toLowerCase().split(/\r?\n|\r/g);
          for (let i = 0; i < groups.length; ++i) {
            const tags = groups[i].trim().split(' ').filter(function (e) {
              return e.trim().length
            });
            const tagIdx = tags.indexOf(tag);
            if (add) {
              if (tagIdx === -1)
                tags.push(tag);
            } else {
              if (tagIdx === -1)
                continue;
              tags.splice(tagIdx, 1);
            }
            groups[i] = tags.join(' ');
          }
          this.tags = groups.join('\n') + ' ';
        }
        nextTick(function() {
          Post.update_tag_count({target: $("#post_tag_string")});
        })
      },
      previewFinalTags() {
        if (this.preview.loading)
          return;
        if (this.preview.show) {
          this.preview.show = false;
          return;
        }
        this.preview.loading = true;
        this.preview.show = true;
        this.preview.tags = [];
        const self = this;
        const data = {tags: this.tags};
        $.ajax("/tags/preview.json", {
          method: 'POST',
          type: 'POST',
          data: data,
          success: function (result) {
            self.preview.loading = false;
            self.preview.tags = result;
          },
          error: function (result) {
            self.preview.loading = false;
            self.preview.tags = [];
            self.preview.show = false;
            Danbooru.error('Error loading tag preview ' + result);
          }
        })
      },
      findRelated(categoryId) {
        const self = this;
        self.expandRelated = true;
        const convertResponse = function (respData) {
          const sortedRelated = [];
          for (const key in respData) {
            if (!respData.hasOwnProperty(key))
              continue;
            if (!respData[key].length)
              continue;
            sortedRelated.push({title: 'Related: ' + key, tags: respData[key].sort(tagSorter)});
          }
          return sortedRelated;
        };
        const getSelectedTags = function () {
          const field = self.$refs.otherTags;
          if (typeof field['selectionStart'] === 'undefined')
            return null;
          const length = field.selectionEnd - field.selectionStart;
          if (length)
            return field.value.substr(field.selectionStart, length);
          return null;
        };
        this.loadingRelated = true;
        this.relatedTags = [];
        const selectedTags = getSelectedTags();
        const params = selectedTags ? {query: selectedTags} : {query: this.tags};

        if (categoryId)
          params['category_id'] = categoryId;
        $.ajax("/related_tag/bulk.json", {
          method: 'POST',
          type: 'POST',
          data: params,
          dataType: 'json',
          success: function (data) {
            self.relatedTags = convertResponse(data);
          }
        }).always(function() {
          self.loadingRelated = false;
        });
      }
    }
  };
</script>
