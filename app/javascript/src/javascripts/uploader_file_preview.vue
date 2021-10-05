<template>
    <div class="upload_preview_container" :class="classes">
        <div class="upload_preview_dims">{{ $parent.previewDimensions }}</div>
        <img class="upload_preview_img" :src="$parent.filePreview.url" style="max-width: 100%;"
            referrerpolicy="no-referrer"
            v-if="!$parent.filePreview.isVideo"
            v-on="addListeners ? { load: $parent.updateFilePreviewDims, error: $parent.filePreviewError } : {}"/>
        <video class="upload_preview_img" controls :src="$parent.filePreview.url" style="max-width: 100%;" 
            v-on="addListeners ? { loadeddata: $parent.updateFilePreviewDims, error: $parent.filePreviewError } : {}"
            v-if="$parent.filePreview.isVideo"></video>
    </div>
</template>

<script>
export default {
  props: {
    classes: String,
    addListeners: {
      type: Boolean,
      default: false
    }
  }
};
</script>
