<template>
    <div class="flex-grid-outer">
        <div class="col box-section">
            <div class="flex-grid border-bottom">
                <div class="col">
                    <label class="section-label" for="post_file">File</label>
                    <div class="hint"><a href="/help/supported_filetypes">Supported Formats</a></div>
                </div>
                <div class="col2">
                  <file-input @uploadValueChanged="uploadValue = $event"
                    @previewChanged="previewData = $event"
                    @invalidUploadValueChanged="invalidUploadValue = $event"></file-input>
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
                    <sources :maxSources="10" :showErrors="showErrors" v-model:sources="sources" @sourceWarning="sourceWarning = $event"></sources>
                </div>
            </div>
            <template v-if="normalMode">
                <div class="flex-grid border-bottom">
                    <div class="col">
                        <label class="section-label" for="names">Artists and Contributors</label>
                        <div><a href="/forum_topics/23553">How do I tag an artist?</a></div>
                        <div>Please don't use <a href="/wiki_pages/anonymous_artist">anonymous_artist</a> or <a href="/wiki_pages/unknown_artist">unknown_artist</a> tags unless they fall under those definitions on the wiki.</div>
                    </div>
                    <div class="col2">
                        <div>
            <textarea class="tag-textarea" v-model="tagEntries.artist" id="post_artist" rows="2"
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
                        <textarea class="tag-textarea" rows="2" v-model="tagEntries.character" id="post_character"
                                  placeholder="Ex: character_name"
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
                        <textarea class="tag-textarea" rows="2" v-model="tagEntries.species" id="post_species"
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
          <textarea class="tag-textarea" v-model="tagEntries.content" id="post_content" rows="2"
                    data-autocomplete="tag-edit"
                    placeholder="Ex: young gore scat watersports diaper my_little_pony vore not_furry rape hyper etc."></textarea>
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
                    <textarea class="tag-textarea" id="post_tags" v-model="tagEntries.other" rows="5"
                              placeholder="Ex: standing orange_fur white_shirt outside smile 4_toes etc."
                              ref="otherTags" data-autocomplete="tag-edit"></textarea>
                    <tag-preview :tags="tags" />
                    <div class="related-tag-functions">
                        Related:
                        <a href="#" @click.prevent="findRelated()">Tags</a> |
                        <a href="#" @click.prevent="findRelated(1)">Artists</a> |
                        <a href="#" @click.prevent="findRelated(2)">Contributors</a> |
                        <a href="#" @click.prevent="findRelated(3)">Copyrights</a> |
                        <a href="#" @click.prevent="findRelated(4)">Characters</a> |
                        <a href="#" @click.prevent="findRelated(5)">Species</a> |
                        <a href="#" @click.prevent="findRelated(7)">Metatags</a>
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
  import sources from './sources.vue';
  import checkbox from './checkbox.vue';
  import relatedTags from './related.vue';
  import tagPreview from './tag_preview.vue';
  import filePreview from './file_preview.vue';
  import fileInput from './file_input.vue';
  import parentPostInput from './parent_post_input.vue';
  import Autocomplete from "../autocomplete.js";
  import DTextFormatter from "../dtext_formatter.js";
  
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

  function tagSorter(a, b) {
    return a.name > b.name ? 1 : -1;
  }

  function unloadWarning() {
    if (this.allowNavigate || (this.uploadValue === "" && this.tags === "")) {
      return;
    }
    return true;
  }

  export default {
    components: {
      'sources': sources,
      'image-checkbox': checkbox,
      'related-tags': relatedTags,
      'tag-preview': tagPreview,
      'file-preview': filePreview,
      'file-input': fileInput,
      'parent-post-input': parentPostInput,
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
        allowNavigate: false,
        submitting: false,

        previewData: {
          url: '',
          isVideo: false,
        },
        uploadValue: '',
        invalidUploadValue: false,

        sourceWarning: false,
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
          // These had a bizarre naming pattern
          // Old names are listed below VVV
          artist: "",     // character: '',
          character: "",  // sex: '',
          species: "",    // bodyType: '',
          content: "",    // theme: '',
          other: "",      // other: '',
        },

        allowLockedTags: window.uploaderSettings.allowLockedTags,
        lockedTags: '',
        allowRatingLock: window.uploaderSettings.allowRatingLock,
        ratingLocked: false,
        allowUploadAsPending: window.uploaderSettings.allowUploadAsPending,
        uploadAsPending: false,

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

      // Import tags from query parameters
      const fillTags = function() {
        const queryList = ["tags-artist", "tags-character", "tags-species", "tags-content"];

        if(params.has("tags"))
          self.importTags(params.get("tags"), "other");

        if(self.normalMode) {
          for(const name of queryList) {
            if(!params.has(name)) continue;
            self.importTags(params.get(name), name.replace("tags-", ""));
          }
        } else {
          // No other inputs in advanced mode, so we can avoid
          // recalculating duplicates every time in importTags
          const tags = [];
          for(const name of queryList) {
            if(!params.has(name)) continue;
            tags.push(params.get(name));
          }
          if(tags.length > 0)
            self.importTags(tags.join(" "), "other");
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
      
      this.initVerifiedArtistButtons();

      Autocomplete.initialize_autocomplete('tag-edit');
      new DTextFormatter($(".dtext-formatter.pending"));
    },
    methods: {
      setCheck(tag, value) {
        this.checkboxes.selected[tag] = value;
      },
      submit() {
        this.showErrors = true;
        this.error = '';
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
          error(response, textStatus, errorThrown) {
            console.log('Error uploading post:', textStatus, errorThrown);
            if (textStatus === "error") textStatus = "unknown";

            console.log(`Status: ${response.status} ${response.statusText}`);
            console.log("Response:", response.responseText);
            console.log(response);

            self.submitting = false;
            try {
              const jsonData = response.responseJSON;
              if (!jsonData) throw new Error("No JSON data returned from server.");
              else console.log(jsonData);

              if (jsonData && jsonData.reason === 'duplicate') self.duplicateId = jsonData.post_id;
              if (jsonData && ['duplicate', 'invalid'].indexOf(jsonData.reason) !== -1) {
                self.error = jsonData.message;
              } else if (jsonData && jsonData.message) {
                self.error = 'Error: ' + jsonData.message;
              } else {
                self.error = 'Error: ' + jsonData.reason;
              }
            } catch (error) {
              console.log("An error occurred:", error);
              self.error = `Error: ${[textStatus, errorThrown].filter(n => n).join(" ")}. Check the browser console for details.`;
            }
          }
        });
      },
      pushTag(tag, add) {
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

      /**
       * Used to import tags from the query parameters
       * @param {string} tags Raw tag string
       * @param {string} input Which of the tagEntries the tags should be added to
       */
      importTags(tags, input) {
        const tagsA = (tags + "").trim().split(" ").filter(n => n);

        // Dedupe
        let tagsB = this.normalMode ? [] : (this.tagEntries.other || "").trim().split(" ");
        tagsA.forEach((tag) => {
          if(tagsB.indexOf(tag) >= 0) return;
          // In advanced mode, checkboxes are not available
          if(this.normalMode && typeof this.checkboxes.all[tag] !== "undefined")
            this.setCheck(tag, true);
          tagsB.push(tag);
        });

        // Without a space at the end, vue panics
        this.tagEntries[this.normalMode ? input : "other"] = tagsB.join(" ") + " ";
      },
      findRelated(categoryId) {
        const self = this;
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

        if (categoryId)
          params['category_id'] = categoryId;
        $.getJSON("/related_tag/bulk.json", params, function (data) {
          self.relatedTags = convertResponse(data);
          self.lastRelatedCategoryId = categoryId;
        }).always(function () {
          self.loadingRelated = false;
        });
      },

      initVerifiedArtistButtons () {
        if (window.uploaderSettings.verifiedArtistTags.length == 0) return;

        // Compact uploader
        const artistTextBox = document.querySelector("#post_artist");
        if (artistTextBox === null) return;

        const artistTextBoxParent = artistTextBox.parentElement;
        const buttonRow = document.createElement("div");
        buttonRow.classList.add("upload-artist-tags");

        const hint = document.createElement("div");
        hint.innerHTML = "Linked artist tags:";
        buttonRow.appendChild(hint);

        for (const artistName of window.uploaderSettings.verifiedArtistTags) {
          const newButton = document.createElement("button");
          newButton.classList.add("toggle-button");
          newButton.innerHTML = artistName;
          newButton.onclick = () => {
            let val = (this.tagEntries.artist ?? "").trim().split(" ").filter(n => n);
            if (val.includes(artistName)) val = val.filter(n => n !== artistName);
            else val.push(artistName);
            this.tagEntries.artist = val.join(" ") + " ";
          };
          buttonRow.appendChild(newButton);
        }
        artistTextBoxParent.appendChild(buttonRow);
      },
    },
    computed: {
      tags() {
        const self = this;
        if (!this.normalMode)
          return this.tagEntries.other;
        const checked = Object.keys(this.checkboxes.selected).filter(function (x) {
          return self.checkboxes.selected[x] === true;
        });
        return checked.concat([this.tagEntries.other, this.tagEntries.artist, this.tagEntries.character,
          this.tagEntries.species, this.tagEntries.content]).join(' ').replace(',', ' ').trim().replace(/ +/g, ' ');
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
      preventUpload: function () {
        return this.sourceWarning || this.notEnoughTags
          || this.invalidRating || this.invalidUploadValue;
      },
      duplicatePath: function () {
        return `/posts/${this.duplicateId}`;
      }
    },
  }
</script>
