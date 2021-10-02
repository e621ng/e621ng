<template>
    <div class="upload_preview_container" :class="classes">
        <div class="upload_preview_dims">{{ $parent.previewDimensions }}</div>
        <img class="upload_preview_img" :src="$parent.previewURL" style="max-width: 100%;"
            referrerpolicy="no-referrer"
            v-on="addListeners ? { load: $parent.updatePreviewDims, error: $parent.previewError } : {}"/>
    </div>
</template>

<script>
export default {
  props: ["classes", "addListeners"]
};
</script>
