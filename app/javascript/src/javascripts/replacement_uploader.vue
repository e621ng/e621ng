<template>
  <file-input @previewChanged="previewData = $event"
    @uploadValueChanged="uploadValue = $event"></file-input>
  <br>

  <div class="input">
    <label>
      Additional Source
      <sources :maxSources="1" :showErrors="showErrors" @sourceWarning="sourceWarning = $event" v-model:sources="sources"></sources>
    </label>
    <span class="hint">The submission page the replacement file came from</span>
  </div>

  <div class="input">
    <label>
      <div>Reason</div>
      <autocompletable-input listId="reason-datalist" :addToList="submittedReason" size="50" placeholder="Higher quality, artwork updated, official uncensored version, ..." v-model="reason"></autocompletable-input>
    </label>
    <span class="hint">Tell us why this file should replace the original.</span>
  </div>

  <div class="input" v-if="canApprove">
    <label class="section-label"><input type="checkbox" id="as_pending" v-model="uploadAsPending"/>
      Upload as pending
    </label>
  </div>

  <div class="background-red error_message" v-if="showErrors && errorMessage !== undefined">
    {{ errorMessage }}
  </div>

  <button @click="submit" :disabled="(showErrors && preventUpload) || submitting">
      {{ submitting ? "Uploading..." : "Upload" }}
  </button>

  <file-preview :data="previewData"></file-preview>
</template>

<script>
import autocompletableInput from "./autocompletable_input.vue";
import filePreview from "./uploader/file_preview.vue";
import fileInput from "./uploader/file_input.vue";
import sources from "./uploader/sources.vue";
import Utility from "./utility";

export default {
  components: {
    "autocompletable-input": autocompletableInput,
    "file-preview": filePreview,
    "file-input": fileInput,
    "sources": sources,
  },
  data() {
    return {
      previewData: {
        url: "",
        isVideo: false,
      },
      sources: [""],
      uploadValue: "",
      reason: "",
      errorMessage: undefined,
      showErrors: false,
      sourceWarning: false,
      submitting: false,
      submittedReason: undefined,
      canApprove: Utility.meta("current-user-can-approve-posts") === "true",
      uploadAsPending: false,
    };
  },
  mounted() {
    const params = new URLSearchParams(window.location.search);
    if (params.has("additional_source"))
      this.sources = [params.get("additional_source")];

    if (params.has("reason"))
      this.reason = params.get("reason");
  },
  computed: {
    preventUpload() {
      return this.sourceWarning;
    }
  },
  methods: {
    submit: function() {
      this.showErrors = true;
      if(this.preventUpload || this.submitting) {
        return;
      }
      this.submitting = true;
      const formData = new FormData();
      if (typeof this.uploadValue === "string") {
        formData.append("post_replacement[replacement_url]", this.uploadValue);
      } else {
        formData.append("post_replacement[replacement_file]", this.uploadValue);
      }
      formData.append("post_replacement[source]", this.sources[0]);
      formData.append("post_replacement[reason]", this.reason);
      formData.append("post_replacement[as_pending]", this.uploadAsPending);

      this.submittedReason = this.reason;

      const postId = new URLSearchParams(window.location.search).get("post_id");
      const self = this;
      $.ajax("/post_replacements.json?post_id=" + postId, {
        method: "POST",
        data: formData,
        processData: false,
        contentType: false,
        success(data) {
          location.assign(data.location);
        },
        error(data) {
          self.submitting = false;
          self.errorMessage = data.responseJSON.reason || data.responseJSON.message;
        }
      });
    }
  }
};
</script>
