<template>
    <div class="flex-grid-outer">
        <div class="col box-section">
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label" for="post_file">File</label>
                    <div class="hint"><a href="/help/supported_filetypes">Supported Formats</a></div>
                </div>
                <div class="col2">
                  <div class="box-section background-red" v-if="showErrors && noUpload">
                    You must provide a file or a URL to upload.
                  </div>
                  <file-input @change="onFileChange"></file-input>
                </div>
            </div>
            <file-preview classes="box-section in-editor below-upload" :data="previewData"></file-preview>
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label" for="post_sources">Sources</label>
                    <div>You should include: A link to the artists page where this was obtained, and a link to the
                        submission page where this image was obtained. No available source should ONLY be used if the
                        content has never been posted online anywhere else.
                    </div>
                </div>
                <div class="col2">
                    <sources :maxSources="10" :showErrors="showErrors" v-model:sources="sources" @missingSourceWarning="missingSourceWarning = $event" @nonUrlSourceWarning="nonUrlSourceWarning = $event" v-model:noSource="noSource"></sources>
                </div>
            </div>
            <template v-if="!compactMode">
                <div class="flex-grid border-bottom">
                    <div class="col">
                        <label class="section-label" for="names">Artists and Contributors</label>
                        <div><a href="/forum_topics/23553">How do I tag an artist?</a></div>
                        <div>Please don't use <a href="/wiki_pages/anonymous_artist">anonymous_artist</a> or <a href="/wiki_pages/unknown_artist">unknown_artist</a> tags unless they fall under those definitions on the wiki.</div>
                    </div>
                    <div class="col2">
                        <artist-source :order="2"></artist-source>
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
                        <checkbox-source kind="characters" :order="0"></checkbox-source>
                        <tag-textarea role="character" field-id="post_character" :order="3"
                                      placeholder="Ex: character_name"></tag-textarea>
                    </div>
                </div>
                <div class="flex-grid border-bottom">
                    <div class="col">
                        <label class="section-label">Body Types and Species</label>
                        <div>One listed body type per visible character, listed options are mutually exclusive.</div>
                    </div>
                    <div class="col2">
                        <checkbox-source kind="body" :order="0"></checkbox-source>
                        <tag-textarea role="species" field-id="post_species" :order="4"
                                      placeholder="Ex: bear dragon hyena rat newt etc."></tag-textarea>
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
                        <tag-textarea role="content" field-id="post_content" :order="5"
                                      placeholder="Ex: young gore scat watersports diaper my_little_pony vore not_furry rape hyper etc."></tag-textarea>
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
                    <div class="box-section background-red" v-if="showErrors && invalidRating">
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
                  <file-preview classes="box-section in-editor" :data="previewData"></file-preview>
                    <div class="box-section background-red" v-show="showErrors && notEnoughTags">
                        You must provide at least <b>{{4 - tagCount}}</b> more tags. Tags in other sections count
                        towards this total.
                    </div>
                    <textarea class="tag-textarea" id="post_tags" v-model="otherTags" rows="5"
                              placeholder="Ex: standing orange_fur white_shirt outside smile 4_toes etc."
                              ref="otherTags" data-autocomplete="tag-edit"></textarea>
                    <tag-preview :tags="tags" />
                    <div class="related-tag-functions">
                        Related:
                        <a href="#" @click.prevent="findRelated()">Tags</a> |
                        <a href="#" @click.prevent="findRelated('artist')">Artists</a> |
                        <a href="#" @click.prevent="findRelated('contributor')">Contributors</a> |
                        <a href="#" @click.prevent="findRelated('copyright')">Copyrights</a> |
                        <a href="#" @click.prevent="findRelated('character')">Characters</a> |
                        <a href="#" @click.prevent="findRelated('species')">Species</a> |
                        <a href="#" @click.prevent="findRelated('meta')">Metatags</a>
                    </div>
                </div>
            </div>
            <div class="flex-grid border-bottom over-me">
                <related-tags v-if="relatedTags.length" :tags="tagsArray" :related="relatedTags"
                              :loading="loadingRelated"
                              :uploaded-tags="uploadTags" :recent-tags="recentTags"
                              @tag-active="pushTag"></related-tags>
            </div>
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label">Parent Post ID</label>
                </div>
                <div class="col2">
                    <parent-post-input v-model="parentID" />
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
                  <div class="dtext-formatter pending" data-state="write" data-allow-color="false" data-limit="50000">
                    <textarea class="dtext required dtext-formatter-input dtext-vue" id="post_description" rows="10" v-model="description"></textarea>
                  </div>
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
                    <div class="box-section background-red" v-show="preventUpload && showErrors">
                        Unmet requirements above prevent the submission of the post.
                    </div>
                    <div class="box-section background-green" v-show="submitting">
                        Submitting your post, please wait.
                    </div>
                    <div class="box-section background-red" v-show="error">
                        {{ error }}
                    </div>
                    <div class="box-section background-red" v-show="duplicateId">
                        Post is a duplicate of <a :href="duplicatePath">post #{{duplicateId}}.</a>
                    </div>
                    <button @click="submit" :disabled="(showErrors && preventUpload) || submitting" accesskey="s">
                        {{ submitting ? 'Uploading...' : 'Upload' }}
                    </button>
                </div>
            </div>
        </div>
        <div id="preview-sidebar" class="col box-section" style="margin-left: 10px; padding: 10px;">
            <file-preview classes="in-sidebar" :data="previewData"></file-preview>
        </div>
    </div>
</template>

<script>
  import { markRaw } from "vue";
  import HTTP from "@/utility/HTTP";
  import { submitUploadForm } from "@/utility/UploadSubmission";
  import ToastManager from "@/utility/Toast";
  import sources from './sources.vue';
  import checkboxSource from './checkbox_source.vue';
  import tagTextarea from './tag_textarea.vue';
  import relatedTags from './related.vue';
  import tagPreview from './tag_preview.vue';
  import filePreview from './file_preview.vue';
  import fileInput from './file_input.vue';
  import parentPostInput from './parent_post_input.vue';
  import artistSource from './artist_source.vue';
  import * as TagField from './tag_field.js';
  import Autocomplete from "@/components/autocomplete";
  import DTextFormatter from "@/components/DTextFormatter.ts";
  import CurrentUser from "@/models/CurrentUser";
  import UploadData from "@/models/UploadData";
  import TagCategories from "@/utility/TagCategories";

  function unloadWarning() {
    if (this.allowNavigate || (this.uploadValue === "" && this.tags === "")) {
      return;
    }
    return true;
  }

  export default {
    components: {
      'sources': sources,
      'checkbox-source': checkboxSource,
      'tag-textarea': tagTextarea,
      'related-tags': relatedTags,
      'tag-preview': tagPreview,
      'file-preview': filePreview,
      'file-input': fileInput,
      'parent-post-input': parentPostInput,
      'artist-source': artistSource,
    },
    provide() {
      return {
        tagRegistry: {
          register: this.registerSource,
          unregister: this.unregisterSource,
        },
      };
    },
    data() {
      return {
        safe: UploadData.safeSite,
        showErrors: false,
        allowNavigate: false,
        submitting: false,

        previewData: {
          url: '',
          isVideo: false,
        },
        uploadValue: '',
        invalidUploadValue: false,

        missingSourceWarning: false,
        nonUrlSourceWarning: false,
        noSource: false,
        sources: [''],
        compactMode: UploadData.compactMode,

        // Tag sources register here; `tags` aggregates their contributions.
        registry: { sources: [] },
        // The free-text "Other Tags" field is the always-present sink (inline on
        // the root so findRelated can reach its textarea via $refs.otherTags).
        otherTags: "",

        allowLockedTags: CurrentUser.is.admin,
        lockedTags: '',
        allowRatingLock: CurrentUser.is.privileged,
        ratingLocked: false,
        allowUploadAsPending: CurrentUser.can.uploadFree,
        uploadAsPending: false,

        uploadTags: UploadData.uploadTags,
        recentTags: UploadData.recentTags,
        relatedTags: [],
        lastRelatedCategoryId: undefined,
        loadingRelated: false,

        parentID: '',
        description: '',
        rating: '',
        error: '',
        duplicateId: 0,
      };
    },
    mounted() {
      const self = this;
      // The free-text "Other Tags" field is the always-present sink. Register it
      // before the query-param import below (importTags routes through it), so all
      // sources register in the same hook as the self-registering children.
      this.sinkDescriptor = {
        isSink: true,
        order: 1, // checkboxes (0) then other (1) then artist/character/species/content
        currentTags: () => TagField.splitTags(this.otherTags),
        addTags: tags => { this.otherTags = TagField.addTags(this.otherTags, tags); },
        removeTag: tag => { this.otherTags = TagField.removeTag(this.otherTags, tag); },
      };
      this.registerSource(this.sinkDescriptor);

      this.unloadHandler = unloadWarning.bind(self);
      window.onbeforeunload = this.unloadHandler;
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

      // Import tags from query parameters. Routing handles mode: params whose
      // role source isn't mounted (compact) fall through to the sink.
      const fillTags = function() {
        const queryList = ["tags-artist", "tags-character", "tags-species", "tags-content"];

        if(params.has("tags"))
          self.importTags(params.get("tags"), "other");

        for(const name of queryList) {
          if(!params.has(name)) continue;
          self.importTags(params.get(name), name.replace("tags-", ""));
        }
      };

      // Import the post rating from a query parameter
      const fillRating = function() {
        if(!params.has("rating")) return;
        const rating = params.get("rating")[0].toLowerCase();
        if(!/[sqe]/.test(rating)) return;
        self.rating = rating;
      };

      fillField('parentID', 'parent');
      fillField('description', 'description');
      fillTags();
      fillRating();
      if(params.has('sources')) {
        self.sources = params.get('sources').split(',');
      }
      if(this.allowRatingLock)
        fillFieldBool('ratingLocked', 'rating_locked');
      if(this.allowLockedTags)
        fillField('lockedTags', 'locked_tags');
      if(this.allowUploadAsPending)
        fillFieldBool("uploadAsPending", "upload_as_pending")

      Autocomplete.initialize_autocomplete('tag-edit');
      new DTextFormatter($(".dtext-formatter.pending"));
    },
    beforeUnmount() {
      // Release the unload guard, but only if it's still ours.
      if (window.onbeforeunload === this.unloadHandler)
        window.onbeforeunload = null;
    },
    methods: {
      onFileChange({ value, preview, invalid }) {
        this.uploadValue = value;
        this.previewData = preview;
        this.invalidUploadValue = invalid;
      },
      // ===== Tag-source coordinator =====
      // markRaw keeps descriptors out of the reactive proxy so `unregisterSource`
      // can match them by identity (a proxied element would never === the raw
      // object the child holds, and the filter would remove nothing).
      registerSource(descriptor) {
        this.registry.sources.push(markRaw(descriptor));
      },
      unregisterSource(descriptor) {
        this.registry.sources = this.registry.sources.filter(s => s !== descriptor);
      },
      // Inbound routing: by value (a source that owns the tag) then the sink.
      route(tag) {
        return this.registry.sources.find(s => s.ownsTag && s.ownsTag(tag))
          || this.registry.sources.find(s => s.isSink);
      },
      // Inbound routing by role (query import), falling back to the sink.
      routeByRole(role) {
        return this.registry.sources.find(s => s.role === role)
          || this.registry.sources.find(s => s.isSink);
      },
      async submit() {
        this.showErrors = true;
        this.error = '';
        this.duplicateId = 0;
        if (this.preventUpload || this.submitting)
          return;
        const self = this;
        this.submitting = true;
        const data = new FormData();
        if (typeof this.uploadValue === "string") {
          data.append('upload[direct_url]', this.uploadValue);
        } else {
          data.append('upload[file]', this.uploadValue);
        }
        data.append('upload[tag_string]', this.tags);
        data.append('upload[rating]', this.rating);
        data.append('upload[source]', this.noSource ? '' : this.sources.join('\n'));
        data.append('upload[description]', this.description);
        data.append('upload[parent_id]', this.parentID);
        if (this.allowLockedTags)
          data.append('upload[locked_tags]', this.lockedTags);
        if (this.allowRatingLock)
          data.append('upload[locked_rating]', this.ratingLocked);
        if (this.allowUploadAsPending)
          data.append('upload[as_pending]', this.uploadAsPending);
        const outcome = await submitUploadForm('/uploads.json', data);
        self.submitting = false;

        if (outcome.kind === 'success') {
          self.allowNavigate = true;
          ToastManager.notice('Post uploaded successfully.');
          location.assign(outcome.body.location);
          return;
        }
        if (outcome.kind === 'blocked' || outcome.kind === 'failed') {
          self.error = outcome.message;
          return;
        }

        const jsonData = outcome.json;
        if (jsonData.reason === 'duplicate') self.duplicateId = jsonData.post_id;
        if (['duplicate', 'invalid'].indexOf(jsonData.reason) !== -1) {
          self.error = jsonData.message;
        } else if (jsonData.message) {
          self.error = 'Error: ' + jsonData.message;
        } else {
          self.error = 'Error: ' + jsonData.reason;
        }
      },
      // Related-tag toggle: route the tag to its owning source, else the sink.
      pushTag(tag, add) {
        const source = this.route(tag);
        if (!source) return;
        if (add) source.addTags([tag]);
        else source.removeTag(tag);
      },

      /**
       * Import tags from a query parameter into the given role's field.
       * @param {string} tags Raw tag string
       * @param {string} role Target role ("other" for the sink, "artist"/"character"/…)
       */
      importTags(tags, role) {
        const incoming = (tags + "").trim().split(" ").filter(n => n);
        const deduped = [];
        for (const tag of incoming) if (!deduped.includes(tag)) deduped.push(tag);

        // Value-route: a checkbox-owned tag flips its checkbox (in either param).
        for (const tag of deduped) {
          const owner = this.registry.sources.find(s => s.ownsTag && s.ownsTag(tag));
          if (owner) owner.addTags([tag]);
        }
        // Textual home: the role's field, or the sink if that source isn't mounted.
        const target = this.routeByRole(role);
        if (target) target.addTags(deduped);
      },
      async findRelated(categoryName) {
        const self = this;
        const categoryId = categoryName ? TagCategories.idFor(categoryName) : undefined;
        if (self.loadingRelated)
          return;
        if (self.relatedTags.length > 0 && self.lastRelatedCategoryId === categoryId) {
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
            sortedRelated.push({title: 'Related: ' + key, tags: respData[key].sort(TagField.tagSorter)});
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

        if (categoryId != null)
          params['category_id'] = categoryId;
        try {
          const data = await HTTP.getJSON("/related_tag/bulk.json", params);
          self.relatedTags = convertResponse(data);
          self.lastRelatedCategoryId = categoryId;
        } catch {
          // A failed lookup just shows no related tags (relatedTags stays []).
        } finally {
          self.loadingRelated = false;
        }
      },
    },
    computed: {
      // Aggregate every registered source, in declared `order` (not registration
      // order) so the preview matches the pre-registry sequence. Serialization is
      // identical (first-comma replace + whitespace collapse); no cross-source dedupe.
      tags() {
        return [...this.registry.sources]
          .sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
          .flatMap(s => s.currentTags())
          .join(' ').replace(/,/g, ' ').trim().replace(/ +/g, ' ');
      },
      tagsArray() {
        return this.tags.toLowerCase().split(' ');
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
      noUpload: function () {
        // Empty string = nothing provided; a URL string or a File is truthy.
        return !this.uploadValue;
      },
      preventUpload: function () {
        return this.missingSourceWarning || this.nonUrlSourceWarning || this.notEnoughTags
          || this.invalidRating || this.invalidUploadValue || this.noUpload;
      },
      duplicatePath: function () {
        return `/posts/${this.duplicateId}`;
      }
    },
  }
</script>
