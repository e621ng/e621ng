<template>
  <div class="upload_preview_container" :class="classes">
    <div class="box-section sect_red" v-show="overDims">
      One of the image dimensions is above the maximum allowed of 15,000px and will fail to upload.
    </div>
    <div v-if="!failed">
      <div class="upload_preview_dims">{{ previewDimensions }}</div>
      <preview-video v-if="isVideo" :url="finalPreviewUrl"
        @load="updateDimensions($event)" @error="previewFailed()"></preview-video>
      <preview-image v-else :url="finalPreviewUrl"
        @load="updateDimensions($event)" @error="previewFailed()"></preview-image>
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
const thumbNone = "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==";
export default {

  components: {
    "preview-image": previewImage,
    "preview-video": previewVideo,
  },
  props: {
    classes: String,
    url: String,
    isVideo: Boolean,
  },
  data() {
    return {
      heigth: 0,
      width: 0,
      overDims: false,
      failed: false,
    }
  },
  computed: {
    previewDimensions() {
      if (this.width > 1 && this.height > 1)
        return this.width + "×" + this.height;
      return "";
    },
    finalPreviewUrl() {
      return this.url === "" ? thumbNone : this.url;
    },
  },
  watch: {
    url: function() {
      this.resetFilePreview();
    }
  },
  methods: {
   updateDimensions(e) {
      const target = e.target;
      this.height = target.naturalHeight || target.videoHeight;
      this.width = target.naturalWidth || target.videoWidth;
      this.overDims = (this.height > 15000 || this.width > 15000);
    },
    resetFilePreview() {
      this.overDims = false;
      this.width = 0;
      this.height = 0;
      this.failed = false;
    },
    previewFailed() {
      this.failed = true;
    },
  }
};
</script>
