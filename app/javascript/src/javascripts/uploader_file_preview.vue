<template>
    <div class="upload_preview_container" :class="classes">
        <div v-if="!preview.failed">
          <div class="upload_preview_dims">{{ previewDimensions }}</div>
          <img class="upload_preview_img" :src="preview.url"
              referrerpolicy="no-referrer"
              v-if="!preview.isVideo"
              v-on:load="$emit('load', $event)" v-on:error="$emit('error')"/>
          <video class="upload_preview_img" controls :src="preview.url"
              v-on:loadeddata="$emit('load', $event)" v-on:error="$emit('error')"
              v-if="preview.isVideo"></video>
        </div>
        <div class="preview-fail box-section sect_yellow" v-if="preview.failed">
          <p>The preview for this file failed to load. Please, double check that the URL you provided is correct.</p>
          Note that some sites intentionally prevent images they host from being displayed on other sites. The file can still be uploaded despite that.
        </div>
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
