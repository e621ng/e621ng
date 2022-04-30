<template>
  <img class="upload_preview_img" :src="url"
    referrerpolicy="no-referrer"
    v-on:load="$emit('load', $event)" v-on:error="$emit('error')"/>
</template>

<script>
  export default {
    props: {
      url: String
    }
  }
</script>
