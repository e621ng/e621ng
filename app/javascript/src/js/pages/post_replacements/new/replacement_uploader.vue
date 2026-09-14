<template>
  <div class="box-section background-red" v-if="showErrors && noUpload">
    You must provide a file or a URL to upload.
  </div>
  <file-input @change="onFileChange"></file-input>
  <br>

  <div class="input">
    <label>Additional Source</label>
    <SourcesInput
      :maxSources="1"
      :showErrors="showErrors"
      @missingSourceWarning="missingSourceWarning = $event"
      @nonUrlSourceWarning="nonUrlSourceWarning = $event"
      v-model:noSource="noSource"
      v-model:sources="sources"
    ></SourcesInput>
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

<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from "vue";
import autocompletableInput from "@/components/autocompletable_input.vue";
import filePreview from "@/components/uploads/file_preview.vue";
import fileInput from "@/components/uploads/file_input.vue";
import SourcesInput from "@/components/uploads/sources.vue";
import CurrentUser from "@/models/CurrentUser";
import ToastManager from "@/utility/Toast";
import { submitUploadForm } from "@/utility/UploadSubmission";
import type { PreviewData, UploadChange } from "@/components/uploads/types";

// Immutable per-session config (read in the template).
const canApprove = CurrentUser.can.approvePosts;

const previewData = ref<PreviewData>({ url: "", isVideo: false });
const uploadValue = ref<string | File>("");
const invalidUploadValue = ref(false);

const missingSourceWarning = ref(false);
const nonUrlSourceWarning = ref(false);
const noSource = ref(false);
const sources = ref<string[]>([""]);

const reason = ref("");
const submittedReason = ref<string | undefined>();
const uploadAsPending = ref(false);

const showErrors = ref(false);
const submitting = ref(false);
const errorMessage = ref<string | undefined>();

// Not reactive: read only by the unload guard and submit.
let allowNavigate = false;
let postId: string | null = null;

function unloadHandler () {
  if (allowNavigate || (uploadValue.value === "" && reason.value === "")) {
    return;
  }
  return true;
}

onMounted(() => {
  window.onbeforeunload = unloadHandler;

  const params = new URLSearchParams(window.location.search);
  postId = params.get("post_id");

  if (params.has("additional_source"))
    sources.value = [params.get("additional_source")!];

  if (params.has("reason"))
    reason.value = params.get("reason")!;
});

onBeforeUnmount(() => {
  // Release the unload guard, but only if it's still ours.
  if (window.onbeforeunload === unloadHandler)
    window.onbeforeunload = null;
});

// Empty string = nothing provided; a URL string or a File is truthy.
const noUpload = computed(() => !uploadValue.value);
const preventUpload = computed(() =>
  missingSourceWarning.value || nonUrlSourceWarning.value || invalidUploadValue.value || noUpload.value);

function onFileChange ({ value, preview, invalid }: UploadChange) {
  uploadValue.value = value;
  previewData.value = preview;
  invalidUploadValue.value = invalid;
}

async function submit () {
  showErrors.value = true;
  errorMessage.value = undefined;
  if (preventUpload.value || submitting.value) {
    return;
  }
  submitting.value = true;
  const formData = new FormData();
  if (typeof uploadValue.value === "string") {
    formData.append("post_replacement[replacement_url]", uploadValue.value);
  } else {
    formData.append("post_replacement[replacement_file]", uploadValue.value);
  }
  formData.append("post_replacement[source]", noSource.value ? "" : sources.value[0]);
  formData.append("post_replacement[reason]", reason.value);
  formData.append("post_replacement[as_pending]", String(uploadAsPending.value));

  const url = postId ? `/post_replacements.json?post_id=${postId}` : "/post_replacements.json";
  const outcome = await submitUploadForm(url, formData);

  if (outcome.kind === "success") {
    // Only a successful submission earns the reason a datalist entry.
    submittedReason.value = reason.value;
    allowNavigate = true;
    ToastManager.notice("Replacement submitted successfully.");
    location.assign(outcome.body.location);
    return;
  }

  submitting.value = false;
  if (outcome.kind === "blocked" || outcome.kind === "failed") {
    errorMessage.value = outcome.message;
    return;
  }
  errorMessage.value = outcome.json.reason || outcome.json.message;
}
</script>
