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
      <div class="box-section background-red" v-if="badDirectURL">
        The direct URL entered has the following problem: {{ directURLProblem }}<br>
        You should review <a href="/wiki_pages/howto:sites_and_sources">the sourcing guide</a>.
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
import { ref, reactive, computed, watch } from "vue";
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
const uploader = reactive({ dragging: false });
const uploadURL = ref(new URLSearchParams(window.location.search).get("upload_url") || "");
const fileTooLarge = ref(false);
const exceededFileSize = ref(0);
const maxFileSize = Settings.Posts.max_file_size;
const maxFileSizeMap = Settings.Posts.max_file_sizes;
const disableFileUpload = ref(false);
const disableURLUpload = ref(false);
// Retained so `change` can carry the full current selection each time.
let currentValue: string | File = "";
const currentPreview = ref<PreviewData>({ url: "", isVideo: false });

const post_file = ref<HTMLInputElement | null>(null);

const directURLProblem = computed(() => directURLCheck(uploadURL.value));
const badDirectURL = computed(() => !!directURLProblem.value);
const invalidUploadValue = computed(() => badDirectURL.value || fileTooLarge.value);

watch(uploadURL, () => {
  fileTooLarge.value = false;
  uploadValueChanged(uploadURL.value);
  updatePreviewURL();
  if (uploadURL.value.length === 0)
    setEmptyThumb();
}, { immediate: true });

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
function directURLCheck(url: string) {
  const patterns = [
    { reason: "Thumbnail URL", test: /[at]\.(facdn|furaffinity)\.net/gi },
    { reason: "Sample URL", test: /pximg\.net.*\/img-master\//gi },
    { reason: "Sample URL", test: /d3gz42uwgl1r1y\.cloudfront\.net\/.*\/\d+x\d+\./gi },
    { reason: "Sample URL", test: /pbs\.twimg\.com\/media\/[\w\-_]+\.(jpg|png)(:large)?$/gi },
    { reason: "Sample URL", test: /pbs\.twimg\.com\/media\/[\w\-_]+\?format=(jpg|png)(?!&name=orig)/gi },
    { reason: "Sample URL", test: /derpicdn\.net\/.*\/large\./gi },
    { reason: "Sample URL", test: /metapix\.net\/files\/(preview|screen)\//gi },
    { reason: "Sample URL", test: /sofurryfiles\.com\/std\/preview/gi }
  ];
  for (const pattern of patterns) {
    if (pattern.test.test(url)) {
      return pattern.reason;
    }
  }
  return "";
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
  setEmptyThumb();
  uploadValueChanged("");

}
function updatePreviewURL() {
  if (uploadURL.value.length === 0 || post_file.value?.files?.[0]) {
    whitelistRequestId++; // invalidate any in-flight lookup
    disableFileUpload.value = false;
    whitelist.oldDomain = "";
    clearWhitelistWarning();
    return;
  }
  disableFileUpload.value = true;

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
        if (!data.is_allowed) {
          setEmptyThumb();
        }
      }
    }).catch(() => {});
  } else if (!domain) {
    whitelistRequestId++; // invalidate any in-flight lookup
    clearWhitelistWarning();
    setEmptyThumb();
  }
  whitelist.oldDomain = domain;
  if(/^(https?\:\/\/|www).*?$/.test(uploadURL.value)) {
    const isVideo = /^(https?\:\/\/|www).*?\.(webm)$/.test(uploadURL.value);
    previewChanged(uploadURL.value, isVideo);
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
  uploadValueChanged(file);
  previewChanged(
    objectUrl,
    ["video/webm", "video/mp4"].includes(file.type),
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
  });
}
</script>
