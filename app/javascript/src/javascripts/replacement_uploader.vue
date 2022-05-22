<template>
  <file-input @previewChanged="previewData = $event"
    :fileInputName="'post_replacement[replacement_file]'"
    :urlInputName="'post_replacement[replacement_url]'"></file-input>
  <Teleport to="#replacement-preview">
    <file-preview :data="previewData"></file-preview>
  </Teleport>
</template>

<script>
import filePreview from "./uploader/file_preview.vue";
import fileInput from "./uploader/file_input.vue";

export default {
  components: {
    "file-preview": filePreview,
    "file-input": fileInput,
  },
  data() {
    return {
      previewData: {
        url: "",
        isVideo: false,
      },
    };
  },
};
</script>
