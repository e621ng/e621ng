<template>
    <div class="flex-grid-outer">
        <div class="col box-section" style="flex: 2 0 0;">
            <div class="box-section sect_red" v-show="filePreview.overDims">
                One of the image dimensions is above the maximum allowed of 15,000px and will fail to upload.
            </div>
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label" for="post_file">File</label>
                    <div class="hint"><a href="/help/supported_filetypes">Supported Formats</a></div>
                </div>
                <div class="col2">
                    <div v-if="!disableFileUpload">
                        <div class="box-section sect_red" v-if="fileTooLarge">
                            The file you are trying to upload is too large. Maximum allowed is {{this.maxFileSize / (1024*1024) }} MiB.<br>
                            Check out <a href="/help/supported_filetypes">the Supported Formats</a> for more information.
                        </div>
                        <label>File:
                            <input type="file" ref="post_file" @change="updateFilePreview" @keyup="updateFilePreview"
                                   accept="image/png,image/apng,image/jpeg,image/gif,video/webm,.png,.apng,.jpg,.jpeg,.gif,.webm"
                                   :disabled="disableFileUpload"/>
                        </label>
                        <button @click="clearFile" v-show="disableURLUpload">Clear</button>
                    </div>
                    <div v-if="!disableURLUpload">
                        <div class="box-section sect_red" v-if="badDirectURL">
                            The direct URL entered has the following problem: {{ directURLProblem }}<br>
                            You should review <a href="/wiki_pages/howto:sites_and_sources">the sourcing guide</a>.
                        </div>
                        <label>{{!disableFileUpload ? '(or) ' : '' }}URL:
                            <input type="text" size="50" v-model="uploadURL" @keyup="updateFilePreview" @paste="updateFilePreviewOnPaste($event)"
                                   :disabled="disableURLUpload"/>
                        </label>
                        <div id="whitelist-warning" v-show="whitelist.visible"
                             :class="{'whitelist-warning-allowed': whitelist.allowed, 'whitelist-warning-disallowed': !whitelist.allowed}">
                            <span v-if="whitelist.allowed">Uploads from <b>{{whitelist.domain}}</b> are permitted.</span>
                            <span v-if="!whitelist.allowed">Uploads from <b>{{whitelist.domain}}</b> are not permitted.
                                <span v-if="whitelist.reason">Reason given: {{whitelist.reason}}</span>
                                (<a href='/upload_whitelists'>View whitelisted domains</a>)</span>
                        </div>
                    </div>
                </div>
            </div>
            <file-preview classes="box-section in-editor below-upload" :preview="filePreview"></file-preview>
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label" for="post_sources">Sources</label>
                    <div>You should include: A link to the artists page where this was obtained, and a link to the
                        submission page where this image was obtained. No available source should ONLY be used if the
                        content has never been posted online anywhere else.
                    </div>
                </div>
                <div class="col2">
                    <div class="box-section sect_red" v-show="showErrors && sourceWarning">
                        A source must be provided or you must select that there is no available source.
                    </div>
                    <div v-if="!noSource">
                        <image-source :last="i === (sources.length-1)" :index="i" v-model="sources[i]"
                                      v-for="s, i in sources"
                                      @delete="removeSource(i)" @add="addSource" :key="i"></image-source>
                    </div>
                    <div>
                        <label class="section-label"><input type="checkbox" id="no_source" v-model="noSource"/>
                            No available source / I am the source.
                        </label>
                    </div>
                </div>
            </div>
            <template v-if="normalMode">
                <div class="flex-grid border-bottom">
                    <div class="col">
                        <label class="section-label" for="names">Artists</label>
                        <div><a href="/forum_topics/23553">How do I tag an artist?</a></div>
                        <div>Please don't use <a href="/wiki_pages/anonymous_artist">anonymous_artist</a> or <a href="/wiki_pages/unknown_artist">unknown_artist</a> tags unless they fall under those definitions on the wiki.</div>
                    </div>
                    <div class="col2">
                        <div>
            <textarea class="tag-textarea" v-model="tagEntries.character" id="post_characters" rows="2"
                      placeholder="Ex: artist_name, unknown_artist, anonymous_artist etc." data-autocomplete="tag-edit"></textarea>
                        </div>
                    </div>
                </div>
                <div class="flex-grid border-bottom">
                    <div class="col">
                        <label class="section-label" for="post_sex_tags">Characters</label>
                        <div>
                            Select (and write in) all that apply. Character sex is based only on what is visible in the
                            image.
                        </div>
                        <div><a href="/wiki_pages/tag_what_you_see">
                            Outside information or other images should not be used when deciding what tags are used.
                        </a></div>
                    </div>
                    <div class="col2">
                        <div class="flex-wrap">
                            <image-checkbox :check="check" :checks="checkboxes.selected" v-for="check in checkboxes.sex"
                                            @set="setCheck"
                                            :key="check.name"></image-checkbox>
                        </div>
                        <hr>
                        <div class="flex-wrap">
                            <image-checkbox :check="check" :checks="checkboxes.selected"
                                            v-for="check in checkboxes.count" @set="setCheck"
                                            :key="check.name"></image-checkbox>
                        </div>
                        <hr>
                        <div class="flex-wrap">
                            <image-checkbox :check="check" :checks="checkboxes.selected"
                                            v-for="check in checkboxes.pairing" @set="setCheck"
                                            :key="check.name"></image-checkbox>
                        </div>
                        <textarea class="tag-textarea" rows="2" v-model="tagEntries.sex" id="post_sexes"
                                  placeholder="Ex: character_name solo_focus etc."
                                  data-autocomplete="tag-edit"></textarea>
                    </div>
                </div>
                <div class="flex-grid border-bottom">
                    <div class="col">
                        <label class="section-label">Body Types and Species</label>
                        <div>One listed body type per visible character, listed options are mutually exclusive.</div>
                    </div>
                    <div class="col2">
                        <div class="flex-wrap">
                            <image-checkbox :check="check" :checks="checkboxes.selected"
                                            v-for="check in checkboxes.body" @set="setCheck"
                                            :key="check.name"></image-checkbox>
                        </div>
                        <textarea class="tag-textarea" rows="2" v-model="tagEntries.bodyType" id="post_bodyTypes"
                                  placeholder="Ex: bear dragon hyena rat newt etc."
                                  data-autocomplete="tag-edit"></textarea>
                    </div>
                </div>
                <div class="flex-grid border-bottom">
                    <div class="col">
                        <label class="section-label">Contentious Content</label>
                        <div>
                            Fetishes or subjects that other users may find extreme or objectionable.
                            These allow users to find or blacklist content with ease. Make sure that you are tagging
                            these upon initial upload.
                        </div>
                    </div>
                    <div class="col2">
          <textarea class="tag-textarea" v-model="tagEntries.theme" id="post_themes" rows="2"
                    data-autocomplete="tag-edit"
                    placeholder="Ex: cub young gore scat watersports diaper my_little_pony vore not_furry rape hyper etc."></textarea>
                    </div>
                </div>
            </template>
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label">Rating</label>
                    <div>Explicit tags include sex, pussy, penis, masturbation, fellatio, etc.
                        (<a href="/help/ratings" target="_blank">help</a>)
                    </div>
                </div>
                <div class="col2">
                    <div class="box-section sect_red" v-if="showErrors && invalidRating">
                        You must select an appropriate rating for this image.
                    </div>
                    <div>
                        <template v-if="!safe">
                            <button class="toggle-button rating-e" :class="{active: rating==='e'}" @click="rating = 'e'">
                                Explicit
                            </button>
                            <button class="toggle-button rating-q" :class="{active: rating==='q'}" @click="rating = 'q'">
                                Questionable
                            </button>
                        </template>
                        <button class="toggle-button rating-s" :class="{active: rating==='s'}" @click="rating = 's'">Safe
                        </button>
                    </div>
                </div>
            </div>
            <div class="flex-grid come-together-now">
                <div class="col">
                    <label class="section-label" for="post_tags">Other Tags</label>
                    <div>
                        Separate tags with spaces. (<a href="/help/tags" target="_blank">help</a>)
                    </div>
                    <div>
                      <a href="/wiki_pages/tag_what_you_see">
                        Outside information or other images should not be used when deciding what tags are used.
                      </a>
                    </div>
                </div>
                <div class="col2">
                  <file-preview classes="box-section in-editor" :preview="filePreview"></file-preview>
                    <div class="box-section sect_red" v-show="showErrors && notEnoughTags">
                        You must provide at least <b>{{4 - tagCount}}</b> more tags. Tags in other sections count
                        towards this total.
                    </div>
                    <div v-show="!tagPreview.show">
                        <textarea class="tag-textarea" id="post_tags" v-model="tagEntries.other" rows="5"
                                  ref="otherTags" data-autocomplete="tag-edit"></textarea>
                    </div>
                    <div v-show="tagPreview.show">
                        <tag-preview :tags="tagPreview.tags" :loading="tagPreview.loading"
                                     @close="previewFinalTags"></tag-preview>
                    </div>

                    <div class="related-tag-functions">
                        Related:
                        <a href="#" @click.prevent="findRelated()">Tags</a> |
                        <a href="#" @click.prevent="findRelated('artist')">Artists</a> |
                        <a href="#" @click.prevent="findRelated('copyright')">Copyrights</a> |
                        <a href="#" @click.prevent="findRelated('char')">Characters</a> |
                        <a href="#" @click.prevent="findRelated('species')">Species</a> |
                        <a href="#" @click.prevent="findRelated('meta')">Metatags</a> |
                        <a href="#" @click.prevent="previewFinalTags">Preview Final Tags</a>
                    </div>
                </div>
            </div>
            <div class="flex-grid border-bottom over-me">
                <related-tags v-if="relatedTags.length" :tags="tagsArray" :related="relatedTags"
                              :loading="loadingRelated"
                              @tag-active="pushTag"></related-tags>
            </div>
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label">Parent Post ID</label>
                </div>
                <div class="col2">
                    <input type="number" v-model.number="parentID" placeholder="Ex. 12345"/>
                </div>
            </div>
            <div v-if="allowLockedTags" class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label">Locked Tags</label>
                </div>
                <div class="col2">
                    <input type="text" v-model="lockedTags" data-autocomplete="tag-query"/>
                </div>
            </div>
            <div v-if="allowRatingLock" class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label">Lock Rating</label>
                </div>
                <div class="col2">
                    <label><input type="checkbox" v-model="ratingLocked"/> Lock Rating</label>
                </div>
            </div>
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label" for="post_description">Description</label>
                </div>
                <div class="col2">
                    <textarea class="tag-textarea dtext-previewable" id="post_description" v-model="description" rows="10" :data-limit="descrLimit" data-initialized="false"></textarea>
                </div>
            </div>
            <div v-if="allowUploadAsPending" class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label">Upload as Pending</label>
                    <div>If you aren't sure if this particular post is up to the standards, checking this box will put it into the moderation queue.</div>
                </div>
                <div class="col2">
                    <label><input type="checkbox" v-model="uploadAsPending"/> Upload as Pending</label>
                </div>
            </div>
            <div class="flex-grid">
                <div class="col"></div>
                <div class="col2">
                    <div class="box-section sect_red" v-show="preventUpload && showErrors">
                        Unmet requirements above prevent the submission of the post.
                    </div>
                    <div class="box-section sect_green" v-show="submitting">
                        Submitting your post, please wait.
                    </div>
                    <div class="box-section sect_red" v-show="error">
                        {{ error }}
                    </div>
                    <div class="box-section sect_red" v-show="duplicateId">
                        Post is a duplicate of <a :href="duplicatePath">post #{{duplicateId}}.</a>
                    </div>
                    <button @click="submit" :disabled="(showErrors && preventUpload) || submitting" accesskey="s">
                        {{ submitting ? 'Uploading...' : 'Upload' }}
                    </button>
                </div>
            </div>
        </div>
        <div id="preview-sidebar" class="col box-section" style="margin-left: 10px; padding: 10px;">
            <file-preview classes="in-sidebar" :preview="filePreview" @load="updateFilePreviewDims" @error="filePreviewError"></file-preview>
        </div>
    </div>
</template>

<script>
  import Vue from 'vue';
  import source from './uploader_source.vue';
  import checkbox from './uploader_checkbox.vue';
  import relatedTags from './uploader_related.vue';
  import tagPreview from './uploader_tag_preview.vue';
  import filePreview from './uploader_file_preview.vue';

  const thumbURLs = [
    "/images/notfound-preview.png",
    "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="
  ];
  const thumbs = {
    notfound: "/images/notfound-preview.png",
    none: 'data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=='
  };

  const sex_checks = [
    {name: 'Male'},
    {name: 'Female'},
    {name: 'Andromorph'},
    {name: 'Gynomorph'},
    {name: 'Hermaphrodite', tag: 'herm'},
    {name: 'Male-Herm', tag: 'maleherm'},
    {name: 'Ambiguous', tag: 'ambiguous_gender'}];

  const pairing_checks = [
    {name: 'Male/Male'},
    {name: 'Male/Female'},
    {name: 'Female/Female'},
    {name: 'Intersex/Male'},
    {name: 'Intersex/Female'},
    {name: 'Intersex/Intersex'}
  ];

  const char_count_checks = [
    {name: 'Solo'},
    {name: 'Duo'},
    {name: 'Trio'},
    {name: 'Group'},
    {name: 'Zero Pictured'}];

  const body_type_checks = [
    {name: 'Anthro'},
    {name: 'Feral'},
    {name: 'Humanoid'},
    {name: 'Human'},
    {name: 'Taur'}];

  function updateFilePreviewDims(e) {
    const target = e.target;
    if (thumbURLs.filter(function (x) {
      return target.src.indexOf(x) !== -1;
    }).length !== 0)
      return;
    this.filePreview.height = target.naturalHeight || target.videoHeight;
    this.filePreview.width = target.naturalWidth || target.videoWidth;
    this.filePreview.overDims = (this.filePreview.height > 15000 || this.filePreview.width > 15000);
  }

  function filePreviewError() {
    this.filePreview.width = this.filePreview.height = 0;
    this.filePreview.overDims = false;
    if (this.uploadURL === '' && !this.$refs['post_file']) {
      this.setPreviewImage(thumbs.none);
    } else {
      this.setPreviewImage(thumbs.notfound);
    }
  }

  function updatePreviewFile() {
    const file = this.$refs['post_file'].files[0];
    this.filePreview.height = 0;
    this.filePreview.width = 0;
    this.resetFilePreview();
    this.fileTooLarge = file.size > this.maxFileSize;
    const objectUrl = URL.createObjectURL(file);
    if (file.type.match('video/webm'))
      this.setPreviewVideo(objectUrl);
    else 
      this.setPreviewImage(objectUrl);

    this.disableURLUpload = true;
  }

  function updatePreviewURL() {
    const self = this;
    if (this.uploadURL.length === 0 || (this.$refs['post_file'] && this.$refs['post_file'].files.length > 0)) {
      this.disableFileUpload = false;
      this.oldDomain = '';
      this.filePreview.width = 0;
      this.filePreview.height = 0;
      this.resetFilePreview();
      self.clearWhitelistWarning();
      return;
    }
    this.disableFileUpload = true;
    const domain = $("<a>").prop("href", this.uploadURL).prop("hostname");

    if (domain && domain !== this.oldDomain) {
      $.getJSON("/upload_whitelists/is_allowed.json", {url: this.uploadURL}, function (data) {
        if (data.domain) {
          self.whitelistWarning(data.is_allowed, data.domain, data.reason);
          if (!data.is_allowed)
            self.setPreviewImage(thumbs.none);
        }
      });
    } else if (!domain) {
      self.clearWhitelistWarning();
    }
    this.oldDomain = domain;

    if (this.uploadURL.match(/^(https?\:\/\/|www).*?\.(webm)$/))
      this.setPreviewVideo(this.uploadURL);
    else if (this.uploadURL.match(/^(https?\:\/\/|www).*?$/))
      this.setPreviewImage(this.uploadURL);
    else
      this.setPreviewImage(thumbs.none);
  }

  function updateFilePreview() {
    this.fileTooLarge = false;
    if (this.$refs['post_file'] && this.$refs['post_file'].files[0])
      updatePreviewFile.call(this);
    else
      updatePreviewURL.call(this);
  }

  function setPreviewImage(url) {
    this.filePreview.isVideo = false;
    this.filePreview.url = url;
  }

  function setPreviewVideo(url) {
    this.filePreview.isVideo = true;
    this.filePreview.url = url;
  }

  function resetFilePreview() {
    // This might not be an objectURL, but revoking in those cases doesn't hurt
    URL.revokeObjectURL(this.filePreview.url);
    this.filePreview.isVideo = false;
    this.filePreview.url = thumbs.none;
    this.filePreview.overDims = false;
  }

  function directURLCheck(url) {
    var patterns = [
      {reason: 'Thumbnail URL', test: /[at]\.facdn\.net/gi},
      {reason: 'Sample URL', test: /pximg\.net.*\/img-master\//gi},
      {reason: 'Sample URL', test: /d3gz42uwgl1r1y\.cloudfront\.net\/.*\/\d+x\d+\./gi},
      {reason: 'Sample URL', test: /pbs\.twimg\.com\/media\/[\w\-_]+\.(jpg|png)(:large)?$/gi},
      {reason: 'Sample URL', test: /pbs\.twimg\.com\/media\/[\w\-_]+\?format=(jpg|png)(?!&name=orig)/gi},
      {reason: 'Sample URL', test: /derpicdn\.net\/.*\/large\./gi},
      {reason: 'Sample URL', test: /metapix\.net\/files\/(preview|screen)\//gi},
      {reason: 'Sample URL', test: /sofurryfiles\.com\/std\/preview/gi}];
    for (var i = 0; i < patterns.length; ++i) {
      var pattern = patterns[i];
      if (pattern.test.test(url))
        return pattern.reason;
    }
    return '';
  }

  function clearFileUpload() {
    if (!(this.$refs['post_file'] && this.$refs['post_file'].files[0]))
      return;
    this.$refs['post_file'].value = null;
    this.disableURLUpload = this.disableFileUpload = false;
    this.resetFilePreview();
    this.updateFilePreview();
  }

  function tagSorter(a, b) {
    return a[0] > b[0] ? 1 : -1;
  }

  function unloadWarning() {
    if (this.allowNavigate)
      return;
    const post_file = this.$refs['post_file'];
    if ((post_file && post_file.files && post_file.files.length) || this.uploadURL) {
      return true;
    }
  }

  export default {
    components: {
      'image-source': source,
      'image-checkbox': checkbox,
      'related-tags': relatedTags,
      'tag-preview': tagPreview,
      'file-preview': filePreview
    },
    data() {
      const allChecks = {};
      const addChecks = function (check) {
        if (typeof check['tag'] !== "undefined") {
          allChecks[check.tag] = true;
          return
        }
        allChecks[check.name.toLowerCase().replace(' ', '_')] = true;
      };
      sex_checks.forEach(addChecks);
      pairing_checks.forEach(addChecks);
      char_count_checks.forEach(addChecks);
      body_type_checks.forEach(addChecks);


      return {
        safe: window.uploaderSettings.safeSite,
        showErrors: false,
        whitelist: {
          visible: false,
          allowed: false,
          domain: ''
        },
        allowNavigate: false,
        submitting: false,
        disableFileUpload: false,
        disableURLUpload: false,

        filePreview: {
          heigth: 0,
          width: 0,
          overDims: false,
          url: thumbs.none,
          isVideo: false,
        },

        uploadURL: '',
        oldDomain: '',

        noSource: false,
        sources: [''],
        normalMode: !window.uploaderSettings.compactMode,

        checkboxes: {
          sex: sex_checks,
          pairing: pairing_checks,
          count: char_count_checks,
          body: body_type_checks,
          selected: {},
          all: allChecks
        },
        tagEntries: {
          character: '',
          sex: '',
          bodyType: '',
          theme: '',
          other: '',
        },

        tagPreview: {
          loading: false,
          show: false,
          tags: []
        },

        allowLockedTags: window.uploaderSettings.allowLockedTags,
        lockedTags: '',
        allowRatingLock: window.uploaderSettings.allowRatingLock,
        ratingLocked: false,
        allowUploadAsPending: window.uploaderSettings.allowUploadAsPending,
        uploadAsPending: false,

        relatedTags: [],
        loadingRelated: false,

        parentID: '',
        description: '',
        rating: '',
        error: '',
        duplicateId: 0,
        
        descrLimit: window.uploaderSettings.descrLimit,

        maxFileSize: window.uploaderSettings.maxFileSize,
        fileTooLarge: false,
      };
    },
    mounted() {
      const self = this;
      window.onbeforeunload = unloadWarning.bind(self);
      const params = new URLSearchParams(window.location.search);
      const fillField = function(field, key) {
        if(params.has(key)) {
          self[field] = params.get(key);
        }
      };
      const fillFieldBool = function(field, key) {
        if(params.has(key)) {
          self[field] = (params.get(key) === 'true');
        }
      };
      const fillTags = function() {
        if(!params.has('tags'))
          return;
        const tags = params.get('tags').split(' ');
        for(const tag of tags) {
          const trimTag = tag.trim();
          if(!trimTag)
            continue;
          self.pushTag(trimTag, true);
        }
      };
      fillField('uploadURL', 'upload_url');
      if(params.has('upload_url'))
        this.updateFilePreview();
      fillField('parentID', 'parent');
      fillField('description', 'description');
      fillTags();
      if(params.has('sources')) {
        self.sources = params.get('sources').split(',');
      }
      if(this.allowRatingLock)
        fillFieldBool('ratingLocked', 'rating_locked');
      if(this.allowLockedTags)
        fillField('lockedTags', 'locked_tags');
      if(this.allowUploadAsPending)
        fillFieldBool("uploadAsPending", "upload_as_pending")
    },
    methods: {
      updateFilePreview,
      updateFilePreviewOnPaste(evt) {
        this.uploadURL = (event.clipboardData || window.clipboardData).getData('text');
        this.updateFilePreview();
        evt.preventDefault();
      },
      updateFilePreviewDims,
      setPreviewImage,
      setPreviewVideo,
      resetFilePreview,
      filePreviewError,
      clearFile: clearFileUpload,
      whitelistWarning(allowed, domain, reason) {
        this.whitelist.allowed = allowed;
        this.whitelist.domain = domain;
        this.whitelist.reason = reason;
        this.whitelist.visible = true;
      },
      clearWhitelistWarning() {
        this.whitelist.visible = false;
        this.whitelist.domain = '';
      },
      removeSource(i) {
        this.sources.splice(i, 1);
      },
      addSource() {
        if (this.sources.length < 10)
          this.sources.push('');
      },
      setCheck(tag, value) {
        Vue.set(this.checkboxes.selected, tag, value);
      },
      submit() {
        this.showErrors = true;
        this.error = '';
        if (this.preventUpload || this.submitting)
          return;
        const self = this;
        this.submitting = true;
        const data = new FormData();
        const post_file = this.$refs['post_file'];
        if (post_file && post_file.files && post_file.files.length) {
          data.append('upload[file]', this.$refs['post_file'].files[0]);
        } else {
          data.append('upload[direct_url]', this.uploadURL);
        }
        data.append('upload[tag_string]', this.tags);
        data.append('upload[rating]', this.rating);
        data.append('upload[source]', this.sources.join('\n'));
        data.append('upload[description]', this.description);
        data.append('upload[parent_id]', this.parentID);
        if (this.allowLockedTags)
          data.append('upload[locked_tags]', this.lockedTags);
        if (this.allowRatingLock)
          data.append('upload[locked_rating]', this.ratingLocked);
        if (this.allowUploadAsPending)
          data.append('upload[as_pending]', this.uploadAsPending);
        jQuery.ajax('/uploads.json', {
          contentType: false,
          processData: false,
          method: 'POST',
          type: 'POST',
          data: data,
          success(data) {
            self.submitting = false;
            self.allowNavigate = true;
            Danbooru.notice('Post uploaded successfully.');
            location.assign(data.location);
          },
          error(data) {
            self.submitting = false;
            const data2 = data.responseJSON;
            try {
              if (data2 && data2.reason === 'duplicate') {
                self.duplicateId = data2.post_id;
              }
              if (data2 && ['duplicate', 'invalid'].indexOf(data2.reason) !== -1) {
                self.error = data2.message;
              } else if (data2 && data2.message) {
                self.error = 'Error: ' + data2.message;
              } else {
                self.error = 'Error: ' + data2.reason;
              }
            } catch (e) {
              self.error = 'Error: Unknown error! ' + JSON.stringify(data2);
            }
          }
        });
      },
      pushTag(tag, add) {
        this.tagPreview.show = false;
        const isCheck = typeof this.checkboxes.all[tag] !== "undefined";
        // In advanced mode we need to push these into the tags area because there are no checkboxes or other
        // tag fields so we can't see them otherwise.
        if (isCheck && this.normalMode) {
          this.setCheck(tag, add);
          return;
        }
        const tags = this.tagEntries.other ? this.tagEntries.other.trim().split(' ') : [];
        const tagIdx = tags.indexOf(tag);
        if (add) {
          if (tagIdx === -1)
            tags.push(tag);
        } else {
          if (tagIdx === -1)
            return;
          tags.splice(tagIdx, 1);
        }
        this.tagEntries.other = tags.join(' ') + ' ';
      },
      previewFinalTags() {
        if (this.tagPreview.loading)
          return;
        if (this.tagPreview.show) {
          this.tagPreview.show = false;
          return;
        }
        this.tagPreview.loading = true;
        this.tagPreview.show = true;
        this.tagPreview.tags = [];
        const self = this;
        const data = {tags: this.tags};
        jQuery.ajax("/tags/preview.json", {
          method: 'POST',
          type: 'POST',
          data: data,
          success: function (result) {
            self.tagPreview.loading = false;
            self.tagPreview.tags = result;
          },
          error: function (result) {
            self.tagPreview.loading = false;
            self.tagPreview.tags = [];
            self.tagPreview.show = false;
            Danbooru.error('Error loading tag preview ' + result);
          }
        })
      },
      findRelated(type) {
        const self = this;
        if (self.loadingRelated)
          return;
        if (self.relatedTags.length > 0 && self.lastRelatedType === type) {
          self.relatedTags = [];
          return;
        }
        const convertResponse = function (respData) {
          const sortedRelated = [];
          for (const key in respData) {
            if (!respData.hasOwnProperty(key))
              continue;
            if (!respData[key].length)
              continue;
            sortedRelated.push({title: 'Related: ' + key, tags: respData[key].sort(tagSorter)});
          }
          return sortedRelated;
        };
        const getSelectedTags = function () {
          const field = self.$refs['otherTags'];
          if (!field.hasOwnProperty('selectionStart'))
            return null;
          const length = field.selectionEnd - field.selectionStart;
          if (length)
            return field.value.substr(field.selectionStart, length);
          return null;
        };
        this.loadingRelated = true;
        this.relatedTags = [];
        const selectedTags = getSelectedTags();
        const params = selectedTags ? {query: selectedTags} : {query: this.tags};

        if (type)
          params['category'] = type;
        $.getJSON("/related_tag/bulk.json", params, function (data) {
          self.relatedTags = convertResponse(data);
          self.lastRelatedType = type;
        }).always(function () {
          self.loadingRelated = false;
        });
      }
    },
    computed: {
      tags() {
        const self = this;
        if (!this.normalMode)
          return this.tagEntries.other;
        const checked = Object.keys(this.checkboxes.selected).filter(function (x) {
          return self.checkboxes.selected[x] === true;
        });
        return checked.concat([this.tagEntries.other, this.tagEntries.sex, this.tagEntries.bodyType,
          this.tagEntries.theme, this.tagEntries.character]).join(' ').replace(',', ' ').trim().replace(/ +/g, ' ');
      },
      tagsArray() {
        return this.tags.toLowerCase().split(' ');
      },
      directURLProblem: function () {
        return directURLCheck(this.uploadURL);
      },
      badDirectURL: function () {
        return !!this.directURLProblem;
      },
      sourceWarning: function () {
        const validSourceCount = this.sources.filter(function (i) {
          return i.length > 0;
        }).length;
        return !this.noSource && (validSourceCount === 0);
      },
      tagCount: function () {
        return this.tags.split(' ').filter(function (x) {
          return x;
        }).length;
      },
      notEnoughTags: function () {
        return this.tagCount < 4;
      },
      invalidRating: function () {
        return !this.rating;
      },
      preventUpload: function () {
        return this.sourceWarning || this.badDirectURL || this.notEnoughTags
          || this.invalidRating || this.fileTooLarge;
      },
      duplicatePath: function () {
        return `/posts/${this.duplicateId}`;
      }
    }
  }
</script>
