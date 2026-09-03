<template>
  <textarea class="tag-textarea" rows="2" v-model="model" :id="fieldId"
            :placeholder="placeholder" data-autocomplete="tag-edit"></textarea>
</template>

<script>
  import * as TagField from './tag_field.js';

  // A role-tagged free-text tag source (character / species / content). Registers
  // with the coordinator; contributes its tokens and accepts role-routed imports.
  export default {
    inject: ['tagRegistry'],
    props: {
      role: { type: String, required: true },
      fieldId: { type: String, default: '' },
      placeholder: { type: String, default: '' },
      order: { type: Number, default: 0 },
    },
    data() {
      return { model: '' };
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
    },
    mounted() {
      this.descriptor = {
        role: this.role,
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
