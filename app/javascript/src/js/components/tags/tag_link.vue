<template>
  <a :class="'tag-type-' + tagType" :href="'/wiki_pages/show_or_new?title=' + name" target="_blank">
    {{ displayName }}
  </a>
</template>

<script>
  export default {
    props: ["tagType", "name", "wrap"],
    computed: {
      displayName() {
        if (this.wrap) {
          return this.name.replace(/_/g, '_\u200B');
        }
        return this.name;
      }
    }
  }
</script>
