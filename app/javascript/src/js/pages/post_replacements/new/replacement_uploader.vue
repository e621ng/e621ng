<template>
  <div class="box-section background-red" v-if="showErrors && noUpload">
    You must provide a file or a URL to upload.
  </div>
  <file-input @change="onFileChange"></file-input>
  <br>

  <div class="input">
    <label>Additional Source</label>
    <sources :maxSources="1" :showErrors="showErrors" @missingSourceWarning="missingSourceWarning = $event" @nonUrlSourceWarning="nonUrlSourceWarning = $event" v-model:noSource="noSource" v-model:sources="sources"></sources>
    <span class="hint">The submission page the replacement file came from</span>
  </div>

  <div class="input">
    <label>
      <div>Reason</div>
      <autocompletable-input
        id="replacement-reason"
        listId="reason-datalist"
        :addToList="submittedReason"
        placeholder="Better image quality / Fixed by the artist / etc."
        v-model="reason"
      ></autocompletable-input>
    </label>
    <span class="hint">
      Tell us why this file should replace the original.<br />
      See <a href="/help/replacements">the help page</a> for more information.
    </span>
  </div>

  <div class="input" v-if="canApprove">
    <label class="section-label"><input type="checkbox" id="as_pending" v-model="uploadAsPending"/>
      Upload as pending
    </label>
  </div>

  <div class="background-red error_message" v-if="errorMessage">
    {{ errorMessage }}
  </div>

  <button @click="submit" :disabled="(showErrors && preventUpload) || submitting">
      {{ submitting ? "Uploading..." : "Upload" }}
  </button>

  <file-preview :data="previewData"></file-preview>
</template>

<script>
import autocompletableInput from "@/components/autocompletable_input.vue";
import filePreview from "@/pages/uploads/new/file_preview.vue";
import fileInput from "@/pages/uploads/new/file_input.vue";
import sources from "@/pages/uploads/new/sources.vue";
import CurrentUser from "@/models/CurrentUser";
import { submitUploadForm } from "@/utility/UploadSubmission";

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
      noSource: false,
      uploadValue: "",
      invalidUploadValue: false,
      reason: "",
      errorMessage: undefined,
      showErrors: false,
      missingSourceWarning: false,
      nonUrlSourceWarning: false,
      submitting: false,
      submittedReason: undefined,
      canApprove: CurrentUser.can.approvePosts,
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
    noUpload() {
      // Empty string = nothing provided; a URL string or a File is truthy.
      return !this.uploadValue;
    },
    preventUpload() {
      return this.missingSourceWarning || this.nonUrlSourceWarning || this.invalidUploadValue || this.noUpload;
    }
  },
  methods: {
    onFileChange({ value, preview, invalid }) {
      this.uploadValue = value;
      this.previewData = preview;
      this.invalidUploadValue = invalid;
    },
    async submit() {
      this.showErrors = true;
      this.errorMessage = undefined;
      if (this.preventUpload || this.submitting) {
        return;
      }
      this.submitting = true;
      const formData = new FormData();
      if (typeof this.uploadValue === "string") {
        formData.append("post_replacement[replacement_url]", this.uploadValue);
      } else {
        formData.append("post_replacement[replacement_file]", this.uploadValue);
      }
      formData.append("post_replacement[source]", this.noSource ? "" : this.sources[0]);
      formData.append("post_replacement[reason]", this.reason);
      formData.append("post_replacement[as_pending]", this.uploadAsPending);

      const postId = new URLSearchParams(window.location.search).get("post_id");
      const outcome = await submitUploadForm("/post_replacements.json?post_id=" + postId, formData);

      if (outcome.kind === "success") {
        // Only a successful submission earns the reason a datalist entry.
        this.submittedReason = this.reason;
        location.assign(outcome.body.location);
        return;
      }

      this.submitting = false;
      if (outcome.kind === "blocked" || outcome.kind === "failed") {
        this.errorMessage = outcome.message;
        return;
      }
      this.errorMessage = outcome.json.reason || outcome.json.message;
    }
  }
};
</script>
