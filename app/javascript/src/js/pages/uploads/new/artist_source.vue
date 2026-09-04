<template>
  <div>
    <artist-tag-input v-model="model"></artist-tag-input>
    <div v-if="verifiedArtistTags.length" class="upload-artist-tags">
      <div>Linked artist tags:</div>
      <button v-for="name in verifiedArtistTags" :key="name" type="button" class="toggle-button"
              @click="toggle(name)">{{ name }}</button>
    </div>
  </div>
</template>

<script>
  import artistTagInput from './artist_tag_input.vue';
  import * as TagField from './tag_field.js';
  import UploadData from "@/models/UploadData";

  // The artist field as a self-registering tag source. Wraps the (untouched)
  // artist_tag_input and renders the linked-artist buttons declaratively,
  // replacing the old imperative initVerifiedArtistButtons() DOM fossil.
  export default {
    components: { 'artist-tag-input': artistTagInput },
    inject: ['tagRegistry'],
    props: {
      order: { type: Number, default: 0 },
    },
    data() {
      return { model: '', verifiedArtistTags: UploadData.verifiedArtistTags };
    },
    methods: {
      currentTags() {
        return TagField.splitTags(this.model);
      },
      addTags(tags) {
        this.model = TagField.addTags(this.model, tags);
      },
      removeTag(tag) {
        this.model = TagField.removeTag(this.model, tag);
      },
      toggle(name) {
        this.model = TagField.splitTags(this.model).includes(name)
          ? TagField.removeTag(this.model, name)
          : TagField.addTags(this.model, [name]);
      },
    },
    mounted() {
      this.descriptor = {
        role: 'artist',
        order: this.order,
        currentTags: () => this.currentTags(),
        addTags: tags => this.addTags(tags),
        removeTag: tag => this.removeTag(tag),
      };
      this.tagRegistry.register(this.descriptor);
    },
    beforeUnmount() {
      this.tagRegistry.unregister(this.descriptor);
    },
  };
</script>
