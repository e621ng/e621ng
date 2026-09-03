<template>
  <textarea class="tag-textarea" rows="2" v-model="model" :id="fieldId"
            :placeholder="placeholder" data-autocomplete="tag-edit"></textarea>
</template>

<script>
  // A role-tagged free-text tag source (character / species / content). Registers
  // with the coordinator; contributes its tokens and accepts role-routed imports.
  export default {
    inject: ['tagRegistry'],
    props: {
      role: { type: String, required: true },
      fieldId: { type: String, default: '' },
      placeholder: { type: String, default: '' },
    },
    data() {
      return { model: '' };
    },
    methods: {
      currentTags() {
        return this.model.trim().split(/\s+/).filter(Boolean);
      },
      addTags(tags) {
        const existing = this.model ? this.model.trim().split(/\s+/).filter(Boolean) : [];
        for (const tag of tags) if (!existing.includes(tag)) existing.push(tag);
        // Trailing space kept deliberately (vue chokes without it on some inputs).
        this.model = existing.join(" ") + " ";
      },
      removeTag(tag) {
        const tags = this.model ? this.model.trim().split(/\s+/).filter(Boolean) : [];
        const idx = tags.indexOf(tag);
        if (idx === -1) return;
        tags.splice(idx, 1);
        this.model = tags.join(" ") + " ";
      },
    },
    mounted() {
      this.descriptor = {
        role: this.role,
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
