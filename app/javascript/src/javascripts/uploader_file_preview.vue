<template>
    <div class="upload_preview_container" :class="classes">
        <div class="upload_preview_dims">{{ previewDimensions }}</div>
        <img class="upload_preview_img" :src="preview.url" style="max-width: 100%;"
            referrerpolicy="no-referrer"
            v-if="!preview.isVideo"
            v-on:load="$emit('load', $event)" v-on:error="$emit('error')"/>
        <video class="upload_preview_img" controls :src="preview.url" style="max-width: 100%;" 
            v-on:loadeddata="$emit('load', $event)" v-on:error="$emit('error')"
            v-if="preview.isVideo"></video>
    </div>
</template>

<script>
export default {
  props: {
    classes: String,
    preview: Object
  },
  computed: {
    previewDimensions() {
      if (this.preview.width && this.preview.height)
        return this.preview.width + '×' + this.preview.height;
      return '';
    },
  }
};
</script>
