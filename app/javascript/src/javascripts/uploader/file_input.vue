<template>
  <span>
    <div v-if="!disableFileUpload">
      <div class="box-section sect_red" v-if="fileTooLarge">
        The file you are trying to upload is too large. Maximum allowed is {{this.maxFileSize / (1024*1024) }} MiB.<br>
        Check out <a href="/help/supported_filetypes">the Supported Formats</a> for more information.
      </div>
      <label>File:
        <input type="file" ref="post_file" @change="updatePreviewFile"
          accept="image/png,image/apng,image/jpeg,image/gif,video/webm,.png,.apng,.jpg,.jpeg,.gif,.webm"
          :disabled="disableFileUpload"/>
      </label>
      <button @click.prevent="clearFileUpload" v-show="disableURLUpload">Clear</button>
    </div>
    <div v-if="!disableURLUpload">
      <div class="box-section sect_red" v-if="badDirectURL">
        The direct URL entered has the following problem: {{ directURLProblem }}<br>
        You should review <a href="/wiki_pages/howto:sites_and_sources">the sourcing guide</a>.
      </div>
      <label>{{!disableFileUpload ? "(or) " : "" }}URL:
        <input type="text" size="50" v-model="uploadURL" :disabled="disableURLUpload"/>
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
      uploadURL: new URLSearchParams(window.location.search).get("upload_url") || "",
      fileTooLarge: false,
      maxFileSize: window.uploaderSettings.maxFileSize,
      disableFileUpload: false,
      disableURLUpload: false,
    }
  },
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
      }
    },
    invalidUploadValue() {
      this.$emit("invalidUploadValueChanged", this.invalidUploadValue);
    }
  },
  methods: {
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
      this.setEmptyThumb();
      this.uploadValueChanged("");

    },
    updatePreviewURL() {
      if (this.uploadURL.length === 0 || this.$refs["post_file"]?.files?.[0]) {
        this.disableFileUpload = false;
        this.whitelist.oldDomain = "";
        this.clearWhitelistWarning();
        return;
      }
      this.disableFileUpload = true;
      const domain = $("<a>").prop("href", this.uploadURL).prop("hostname");

      if (domain && domain !== this.whitelist.oldDomain) {
        $.getJSON("/upload_whitelists/is_allowed.json", {url: this.uploadURL}, data => {
          if (data.domain) {
            this.whitelistWarning(data.is_allowed, data.domain, data.reason);
            if (!data.is_allowed) {
              this.setEmptyThumb();
            }
          }
        });
      } else if (!domain) {
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
    updatePreviewFile() {
      const file = this.$refs["post_file"].files[0];
      this.fileTooLarge = file.size > this.maxFileSize;
      const objectUrl = URL.createObjectURL(file);
      this.disableURLUpload = true;
      this.uploadValueChanged(file);
      this.previewChanged(objectUrl, file.type === "video/webm");
    },
    uploadValueChanged(value) {
      this.$emit("uploadValueChanged", value);
    },
    setEmptyThumb()  {
      this.previewChanged("", false);
    },
    previewChanged(url, isVideo) {
      this.$emit("previewChanged", { url: url, isVideo: isVideo });
    },
  }
}
</script>
