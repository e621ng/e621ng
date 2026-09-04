<template>
  <span
    class="uploader-file-input"
    :file-enabled="!disableFileUpload"
    :link-enabled="!disableURLUpload"
  >
    <div class="fileinput-wrapper" v-if="!disableFileUpload">
      <div class="box-section background-red" v-if="fileTooLarge">
        The file you are trying to upload is too large. Maximum allowed is {{this.exceededFileSize / (1024*1024) }} MiB.<br>
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
            {{ this.getFileURL().name }}
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
      <div id="whitelist-warning" v-show="whitelist.visible"
            :class="{'whitelist-warning-allowed': whitelist.allowed, 'whitelist-warning-disallowed': !whitelist.allowed}">
        <span v-if="whitelist.allowed">Uploads from <b>{{whitelist.domain}}</b> are permitted.</span>
        <span v-if="!whitelist.allowed">Uploads from <b>{{whitelist.domain}}</b> are not permitted.
        <span v-if="whitelist.reason">Reason given: {{whitelist.reason}}</span>
        (<a href="/upload_whitelists">View whitelisted domains</a>)</span>
      </div>
    </div>
  </span>
</template>

<script>
import Settings from "@/utility/Settings";
import HTTP from "@/utility/HTTP";

export default {
  data() {
    return {
      whitelist: {
        visible: false,
        allowed: false,
        reason: "",
        domain: "",
        oldDomain: "",
      },
      // Sequencing token so out-of-order whitelist responses can't show a stale verdict.
      whitelistRequestId: 0,
      uploader: {
        dragging: false,
      },
      uploadURL: new URLSearchParams(window.location.search).get("upload_url") || "",
      fileTooLarge: false,
      exceededFileSize: 0,
      maxFileSize: Settings.Posts.max_file_size,
      maxFileSizeMap: Settings.Posts.max_file_sizes,
      disableFileUpload: false,
      disableURLUpload: false,
      // Retained so `change` can carry the full current selection each time.
      currentValue: "",
      currentPreview: { url: "", isVideo: false },
    }
  },
  emits: ["change"],
  computed: {
    directURLProblem: function () {
      return this.directURLCheck(this.uploadURL);
    },
    badDirectURL: function () {
      return !!this.directURLProblem;
    },
    invalidUploadValue: function() {
      return this.badDirectURL || this.fileTooLarge;
    }
  },
  watch: {
    uploadURL: {
      immediate: true,
      handler() {
        this.fileTooLarge = false;
        this.uploadValueChanged(this.uploadURL);
        this.updatePreviewURL();
        if(this.uploadURL.length === 0)
          this.setEmptyThumb();
      }
    },
  },
  methods: {
    fileDragover(event) {
      event.preventDefault();
      this.uploader.dragging = true;
    },
    fileDragleave(event) {
      event.preventDefault();
      this.uploader.dragging = false;
    },
    fileDrop(event) {
      event.preventDefault();
      this.uploader.dragging = false;

      this.$refs.post_file.files = event.dataTransfer.files;
      this.updatePreviewFile();
    },
    whitelistWarning(allowed, domain, reason) {
      this.whitelist.allowed = allowed;
      this.whitelist.domain = domain;
      this.whitelist.reason = reason;
      this.whitelist.visible = true;
    },
    clearWhitelistWarning() {
      this.whitelist.visible = false;
      this.whitelist.domain = "";
    },
    directURLCheck(url) {
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
    },
    clearFileUpload() {
      if (!this.$refs["post_file"]?.files?.[0]) {
        return;
      }
      this.$refs["post_file"].value = null;
      this.disableURLUpload = false;
      this.disableFileUpload = false;
      this.fileTooLarge = false;
      this.exceededFileSize = 0;
      this.setEmptyThumb();
      this.uploadValueChanged("");

    },
    updatePreviewURL() {
      if (this.uploadURL.length === 0 || this.$refs["post_file"]?.files?.[0]) {
        this.whitelistRequestId++; // invalidate any in-flight lookup
        this.disableFileUpload = false;
        this.whitelist.oldDomain = "";
        this.clearWhitelistWarning();
        return;
      }
      this.disableFileUpload = true;

      let domain;
      try { domain = new URL(this.uploadURL).hostname; }
      catch { domain = ""; }

      if (domain && domain !== this.whitelist.oldDomain) {
        // Non-blocking (the synchronous preview tail below must run regardless) and
        // latest-wins: a newer URL change supersedes this lookup so a slow, out-of-order
        // response can't overwrite the current verdict.
        const requestId = ++this.whitelistRequestId;
        HTTP.getJSON("/upload_whitelists/is_allowed.json", { url: this.uploadURL }).then(data => {
          if (requestId !== this.whitelistRequestId) return;
          if (data.domain) {
            this.whitelistWarning(data.is_allowed, data.domain, data.reason);
            if (!data.is_allowed) {
              this.setEmptyThumb();
            }
          }
        }).catch(() => {});
      } else if (!domain) {
        this.whitelistRequestId++; // invalidate any in-flight lookup
        this.clearWhitelistWarning();
        this.setEmptyThumb();
      }
      this.whitelist.oldDomain = domain;
      if(/^(https?\:\/\/|www).*?$/.test(this.uploadURL)) {
        const isVideo = /^(https?\:\/\/|www).*?\.(webm)$/.test(this.uploadURL);
        this.previewChanged(this.uploadURL, isVideo);
      } else {
        this.setEmptyThumb();
      }
    },
    getFileURL() {
      return this.$refs["post_file"].files[0];
    },
    updatePreviewFile() {
      const file = this.getFileURL();
      const maxFileSize = this.maxFileSizeMap[file.type.split("/")?.[1]] ?? this.maxFileSize;
      if (file.size > maxFileSize) {
        this.fileTooLarge = true;
        this.exceededFileSize = maxFileSize;
      } else {
        this.fileTooLarge = false;
        this.exceededFileSize = 0;
      }
      const objectUrl = URL.createObjectURL(file);
      this.disableURLUpload = true;
      this.uploadValueChanged(file);
      this.previewChanged(
        objectUrl, 
        ["video/webm", "video/mp4"].includes(file.type),
      );
    },
    uploadValueChanged(value) {
      this.currentValue = value;
      this.emitChange();
    },
    setEmptyThumb()  {
      this.previewChanged("", false);
    },
    previewChanged(url, isVideo) {
      this.currentPreview = { url: url, isVideo: isVideo };
      this.emitChange();
    },
    // Single contract: the current value + preview + validity, emitted whenever any changes.
    emitChange() {
      this.$emit("change", {
        value: this.currentValue,
        preview: this.currentPreview,
        invalid: this.invalidUploadValue,
      });
    },
  }
}
</script>
