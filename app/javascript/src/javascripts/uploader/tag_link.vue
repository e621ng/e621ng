<template>
  <a :class="'tag-type-' + tagType" :href="'/wiki_pages/show_or_new?title=' + name" target="_blank">
    {{ name }}
  </a>
</template>

<script>
  export default {
    props: ["tagType", "name"],
  }
</script>
