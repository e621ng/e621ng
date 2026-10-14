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
      <p>
        The preview for this file failed to load. Please, double check that the URL you provided is correct.
      </p>
      Note that some sites intentionally prevent images they host from being displayed on other sites. The file can still be uploaded despite that.
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from "vue";
import type { PreviewData } from "./types";

const thumbNone = "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==";

const props = defineProps<{ classes?: string; data: PreviewData }>();

const height = ref(0);
const width = ref(0);
const overDims = ref(false);
const failed = ref(false);

const previewDimensions = computed(() => {
  if (width.value > 1 && height.value > 1)
    return width.value + "×" + height.value;
  return "";
});
const finalPreviewUrl = computed(() => props.data.url === "" ? thumbNone : props.data.url);

watch(() => props.data, () => resetFilePreview());

function updateDimensions(e: Event) {
  const target = e.target as HTMLImageElement & HTMLVideoElement;
  height.value = target.naturalHeight || target.videoHeight;
  width.value = target.naturalWidth || target.videoWidth;
  overDims.value = (height.value > 15000 || width.value > 15000);
}
function resetFilePreview() {
  overDims.value = false;
  width.value = 0;
  height.value = 0;
  failed.value = false;
}
function previewFailed() {
  failed.value = true;
}
</script>
