<template>
  <div class="upload_preview_container" :class="classes">
    <div class="box-section background-red" v-show="overDims">
      One of the image dimensions is above the maximum allowed of 15,000px and will fail to upload.
    </div>
    <div v-if="!failed">
      <div class="upload_preview_dims">{{ previewDimensions }}</div>
      <video v-if="data.isVideo" class="upload_preview_img" controls :src="finalPreviewUrl"
        v-on:loadeddata="updateDimensions($event)" v-on:error="previewFailed()">
      </video>
      <img v-else class="upload_preview_img" :src="finalPreviewUrl"
        referrerpolicy="no-referrer"
        v-on:load="updateDimensions($event)" v-on:error="previewFailed()"/>
    </div>
    <div v-else class="preview-fail box-section background-yellow">
      <p>The preview for this file failed to load. Please, double check that the URL you provided is correct.</p>
      Note that some sites intentionally prevent images they host from being displayed on other sites. The file can still be uploaded despite that.
    </div>
  </div>
</template>

<script>
const thumbNone = "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==";
export default {
  props: {
    classes: String,
    data: {
      validator: function(obj) {
        return typeof obj.isVideo === "boolean" && typeof obj.url === "string";
      }
    },
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
      return this.data.url === "" ? thumbNone : this.data.url;
    },
  },
  watch: {
    data: function() {
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
