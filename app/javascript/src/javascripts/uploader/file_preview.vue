<template>
  <div class="upload_preview_container" :class="classes">
    <div v-if="!preview.failed">
      <div class="upload_preview_dims">{{ previewDimensions }}</div>
      <preview-video v-if="preview.isVideo" :url="preview.url"
        @load="$emit('load', $event)" @error="$emit('error')"></preview-video>
      <preview-image v-else :url="preview.url"
        @load="$emit('load', $event)" @error="$emit('error')"></preview-image>
    </div>
    <div v-else class="preview-fail box-section sect_yellow">
      <p>The preview for this file failed to load. Please, double check that the URL you provided is correct.</p>
      Note that some sites intentionally prevent images they host from being displayed on other sites. The file can still be uploaded despite that.
    </div>
  </div>
</template>

<script>
import previewImage from "./preview_image.vue";
import previewVideo from "./preview_video.vue";
export default {

  components: {
    "preview-image": previewImage,
    "preview-video": previewVideo,
  },
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
