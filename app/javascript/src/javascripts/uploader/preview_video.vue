<template>
  <video class="upload_preview_img" controls :src="url"
      v-on:loadeddata="$emit('load', $event)" v-on:error="$emit('error')">
  </video>
</template>

<script>
  export default {
    props: {
      url: String
    }
  }
</script>
