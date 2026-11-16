<template>
  <span
    class="uploader-file-input"
    :file-enabled="!disableFileUpload"
    :link-enabled="!disableURLUpload"
  >
    <div class="fileinput-wrapper" v-if="!disableFileUpload">
      <div class="box-section background-red" v-if="fileTooLarge">
        The file you are trying to upload is too large. Maximum allowed is {{ exceededFileSize / (1024*1024) }} MiB.<br />
        Check out <a href="/help/supported_filetypes">the Supported Formats</a> for more information.
      </div>
      <label
        class="fileinput"
        for="file-input"
        @dragover="fileDragover"
        @dragleave="fileDragleave"
        @drop="fileDrop"
        :dragging="uploader.dragging"
      >
        <input
          type="file"
          ref="post_file"
          id="file-input"
          accept="image/png,.png,image/apng,.apng,image/jpeg,.jpg,.jpeg,image/gif,.gif,video/webm,.webm,video/mp4,.mp4,image/webp,.webp"
          @change="updatePreviewFile"
          :disabled="disableFileUpload"
        />
        <span class="title">
          <div v-if="uploader.dragging">Release to drop a file here</div>
          <div v-else>Choose an image or video to upload</div>
        </span>
        <span class="subtitle">
          <div v-if="disableURLUpload">
            {{ getFileURL().name }}
          </div>
          <div v-else><u>Browse for file</u> or drag and drop</div>
        </span>
      </label>
      <button
        class="btn-clear"
        @click.prevent="clearFileUpload"
        v-show="disableURLUpload"
      >Clear</button>
    </div>

    <div class="linkinput-wrapper" v-if="!disableURLUpload">
      <div
        class="box-section url-rule"
        :class="rule.status === 'recommend' ? 'background-yellow' : 'background-red'"
        v-if="rule.status !== 'none'"
      >
        <template v-if="rule.status === 'failed'">
          This URL could not be checked (rule: {{ rule.label }}). Please report this to staff.
        </template>
        <template v-else>
          <b>{{ rule.label }}:</b>
          {{ rule.status === 'block' ? "this URL cannot be uploaded." : "a better version may be available." }}
          <div v-if="rule.message">{{ rule.message }}</div>
          <div v-if="rule.suggestedUrl">
            Suggested URL: <span class="url-rule-suggestion">{{ rule.suggestedUrl }}</span><br>
            <button class="st-button" @click.prevent="useSuggestedURL">Use suggested URL</button>
          </div>
          <div v-else>
            You should review <a href="/wiki_pages/howto:sites_and_sources">the sourcing guide</a>.
          </div>
        </template>
      </div>
      <label class="linkinput">
        <span class="linkinput-or">{{!disableFileUpload ? "OR" : "URL" }}</span>
        <input
          type="text"
          size="50"
          placeholder="Paste image URL"
          v-model="uploadURL"
          :disabled="disableURLUpload"
        />
      </label>
      <div
        id="whitelist-warning"
        v-show="whitelist.visible"
        :class="{'whitelist-warning-allowed': whitelist.allowed, 'whitelist-warning-disallowed': !whitelist.allowed}"
      >
        <span v-if="whitelist.allowed">Uploads from <b>{{whitelist.domain}}</b> are permitted.</span>
        <span v-if="!whitelist.allowed">Uploads from <b>{{whitelist.domain}}</b> are not permitted.
        <span v-if="whitelist.reason">Reason given: {{whitelist.reason}}</span>
        (<a href="/upload_whitelists">View whitelisted domains</a>)</span>
      </div>
    </div>
  </span>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onBeforeUnmount } from "vue";
import Settings from "@/utility/Settings";
import HTTP from "@/utility/HTTP";
import type { PreviewData, UploadChange } from "./types";

const emit = defineEmits<{ change: [payload: UploadChange] }>();

const whitelist = reactive({
  visible: false,
  allowed: false,
  reason: "",
  domain: "",
  oldDomain: "",
});
// Sequencing token so out-of-order whitelist responses can't show a stale verdict.
let whitelistRequestId = 0;
// Verdict of the staff-defined upload URL rules for the current URL.
// "failed" = a rule could not be evaluated; the server refuses such uploads.
type RuleStatus = "none" | "recommend" | "block" | "failed";
const rule = reactive({ status: "none" as RuleStatus, label: "", message: "", suggestedUrl: "" });
let ruleRequestId = 0;
const uploader = reactive({ dragging: false });
const uploadURL = ref(new URLSearchParams(window.location.search).get("upload_url") || "");
const fileTooLarge = ref(false);
const exceededFileSize = ref(0);
const maxFileSize = Settings.Posts.max_file_size;
const maxFileSizeMap = Settings.Posts.max_file_sizes;
const videoExtensions = Settings.Posts.video_extensions;
const disableFileUpload = ref(false);
const disableURLUpload = ref(false);
// Retained so `change` can carry the full current selection each time.
let currentValue: string | File = "";
let currentWhitelistAllowed: boolean | undefined = undefined;
const currentPreview = ref<PreviewData>({ url: "", isVideo: false });

const post_file = ref<HTMLInputElement | null>(null);

const invalidUploadValue = computed(() => rule.status === "block" || rule.status === "failed" || fileTooLarge.value);

// Debounce the network/preview work (whitelist lookup + preview src) so typing a
// URL doesn't fire a request per keystroke; the value/validity emit stays
// immediate so submit-gating is never delayed. (Also the seam the future IQDB
// URL dup-check will hang off of.)
const URL_PREVIEW_DEBOUNCE = 300; // ms
let urlPreviewTimer: ReturnType<typeof setTimeout> | undefined;

watch(uploadURL, () => {
  fileTooLarge.value = false;
  // Any edit stales the verdicts; updatePreviewURL re-establishes them.
  currentWhitelistAllowed = undefined;
  clearRule();
  uploadValueChanged(uploadURL.value);
  clearTimeout(urlPreviewTimer);
  if (uploadURL.value.length === 0) {
    updatePreviewURL();   // immediate: clear whitelist warning + reset disableFileUpload
    setEmptyThumb();
    return;
  }
  urlPreviewTimer = setTimeout(updatePreviewURL, URL_PREVIEW_DEBOUNCE);
}, { immediate: true });

onBeforeUnmount(() => clearTimeout(urlPreviewTimer));

function fileDragover(event: DragEvent) {
  event.preventDefault();
  uploader.dragging = true;
}
function fileDragleave(event: DragEvent) {
  event.preventDefault();
  uploader.dragging = false;
}
function fileDrop(event: DragEvent) {
  event.preventDefault();
  uploader.dragging = false;

  if (post_file.value && event.dataTransfer) post_file.value.files = event.dataTransfer.files;
  updatePreviewFile();
}
function whitelistWarning(allowed: boolean, domain: string, reason: string) {
  whitelist.allowed = allowed;
  whitelist.domain = domain;
  whitelist.reason = reason;
  whitelist.visible = true;
}
function clearWhitelistWarning() {
  whitelist.visible = false;
  whitelist.domain = "";
}
function clearRule() {
  ruleRequestId++; // invalidate any in-flight check
  rule.status = "none";
  rule.label = "";
  rule.message = "";
  rule.suggestedUrl = "";
}
// Non-blocking and latest-wins, like the whitelist lookup. A check that cannot be
// completed (network error, 5xx) does not hold the form: the server enforces the rules.
function checkURLRules() {
  const requestId = ++ruleRequestId;
  HTTP.get("/upload_url_rules/check.json", { url: uploadURL.value }).then(async (response) => {
    if (!response.ok && response.status !== 422) return;
    const data = await response.json();
    if (requestId !== ruleRequestId) return;
    if (response.status === 422) {
      if (data.error !== "rule_failed") return;
      rule.status = "failed";
      rule.label = data.label ?? "";
    } else if (data.match === true && (data.handling === "block" || data.handling === "recommend")) {
      rule.status = data.handling;
      rule.label = data.label ?? "";
      rule.message = data.message ?? "";
      rule.suggestedUrl = data.suggested_url ?? "";
    } else {
      return;
    }
    emitChange();
  }).catch(() => {});
}
function useSuggestedURL() {
  if (rule.suggestedUrl) uploadURL.value = rule.suggestedUrl;
}
function clearFileUpload() {
  if (!post_file.value?.files?.[0]) {
    return;
  }
  post_file.value.value = null;
  disableURLUpload.value = false;
  disableFileUpload.value = false;
  fileTooLarge.value = false;
  exceededFileSize.value = 0;
  currentWhitelistAllowed = undefined;
  setEmptyThumb();
  uploadValueChanged("");

}
function updatePreviewURL() {
  if (uploadURL.value.length === 0 || post_file.value?.files?.[0]) {
    whitelistRequestId++; // invalidate any in-flight lookup
    currentWhitelistAllowed = undefined;
    disableFileUpload.value = false;
    whitelist.oldDomain = "";
    clearWhitelistWarning();
    return;
  }
  disableFileUpload.value = true;
  if (/^https?:\/\//i.test(uploadURL.value)) checkURLRules();

  let domain;
  try { domain = new URL(uploadURL.value).hostname; }
  catch { domain = ""; }

  if (domain && domain !== whitelist.oldDomain) {
    // Non-blocking (the synchronous preview tail below must run regardless) and
    // latest-wins: a newer URL change supersedes this lookup so a slow, out-of-order
    // response can't overwrite the current verdict.
    const requestId = ++whitelistRequestId;
    HTTP.getJSON<{ domain?: string; is_allowed?: boolean; reason?: string }>("/upload_whitelists/is_allowed.json", { url: uploadURL.value }).then(data => {
      if (requestId !== whitelistRequestId) return;
      if (data.domain) {
        whitelistWarning(!!data.is_allowed, data.domain, data.reason ?? "");
        currentWhitelistAllowed = !!data.is_allowed;
        if (!data.is_allowed) {
          setEmptyThumb(); // emits, carrying the verdict
        } else {
          emitChange();
        }
      }
    }).catch(() => {}); // lookup failure: verdict stays undefined (hold, not deny)
  } else if (domain && whitelist.visible) {
    // Same-domain edit: no new lookup fires, so restore the displayed verdict
    // (the URL watch cleared it).
    currentWhitelistAllowed = whitelist.allowed;
    emitChange();
  } else if (!domain) {
    whitelistRequestId++; // invalidate any in-flight lookup
    currentWhitelistAllowed = undefined;
    clearWhitelistWarning();
    setEmptyThumb();
  }
  whitelist.oldDomain = domain;
  if(/^(https?\:\/\/|www).*?$/.test(uploadURL.value)) {
    // Trailing extension, tolerating a ?query / #hash suffix.
    const ext = (uploadURL.value.toLowerCase().match(/\.([a-z0-9]+)(?:[?#].*)?$/) || [])[1] || "";
    previewChanged(uploadURL.value, videoExtensions.includes(ext));
  } else {
    setEmptyThumb();
  }
}
function getFileURL() {
  return post_file.value!.files![0];
}
function updatePreviewFile() {
  const file = getFileURL();
  const maxSize = maxFileSizeMap[file.type.split("/")?.[1]] ?? maxFileSize;
  if (file.size > maxSize) {
    fileTooLarge.value = true;
    exceededFileSize.value = maxSize;
  } else {
    fileTooLarge.value = false;
    exceededFileSize.value = 0;
  }
  const objectUrl = URL.createObjectURL(file);
  disableURLUpload.value = true;
  currentWhitelistAllowed = undefined; // files never have a whitelist verdict
  clearRule(); // nor a URL rule verdict
  uploadValueChanged(file);
  previewChanged(
    objectUrl,
    videoExtensions.some((ext) => file.type === "video/" + ext),
  );
}
function uploadValueChanged(value: string | File) {
  currentValue = value;
  emitChange();
}
function setEmptyThumb() {
  previewChanged("", false);
}
function previewChanged(url: string, isVideo: boolean) {
  currentPreview.value = { url: url, isVideo: isVideo };
  emitChange();
}
// Single contract: the current value + preview + validity, emitted whenever any changes.
function emitChange() {
  emit("change", {
    value: currentValue,
    preview: currentPreview.value,
    invalid: invalidUploadValue.value,
    whitelistAllowed: currentWhitelistAllowed,
  });
}
</script>
