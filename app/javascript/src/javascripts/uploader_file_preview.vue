<template>
    <div class="upload_preview_container" :class="classes">
        <div class="upload_preview_dims">{{ $parent.previewDimensions }}</div>
        <img class="upload_preview_img" :src="$parent.previewURL" style="max-width: 100%;"
            referrerpolicy="no-referrer"
            v-if="!$parent.previewIsVideo"
            v-on="addListeners ? { load: $parent.updatePreviewDims, error: $parent.previewError } : {}"/>
        <video class="upload_preview_img" controls :src="$parent.previewURL" style="max-width: 100%;" 
            v-on="addListeners ? { loadeddata: $parent.updatePreviewDims, error: $parent.previewError } : {}"
            v-if="$parent.previewIsVideo"></video>
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
