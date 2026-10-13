<template>
  <div class="uploader-column column-left">

    <!-- File Upload -->
    <div class="uploader-row">
      <div class="uploader-row-label">
        <label class="section-label" for="post_file">File</label>
        <div class="hint"><a href="/help/supported_filetypes">Supported Formats</a></div>
      </div>
      <div class="uploader-row-input">
        <div class="box-section background-red" v-if="showErrors && noUpload">
          You must provide a file or a URL to upload.
        </div>
        <file-input @change="onFileChange"></file-input>
      </div>
    </div>

    <div class="uploader-row">
      <similar-posts
        v-if="iqdbEnabled"
        :upload-value="uploadValue"
        :invalid-upload-value="invalidUploadValue"
        :whitelist-allowed="whitelistAllowed"
      ></similar-posts>
    </div>

    <!-- Mobile-only Preview (top) -->
    <file-preview classes="box-section in-editor below-upload" :data="previewData"></file-preview>

    <!-- Sources -->
    <div class="uploader-row">
      <div class="uploader-row-label">
        <label class="section-label" for="post_sources">Sources</label>
        <div>You should include: A link to the artists page where this was obtained, and a link to the
          submission page where this image was obtained. No available source should ONLY be used if the
          content has never been posted online anywhere else.
        </div>
      </div>
      <div class="uploader-row-input">
        <sources-input
          :maxSources="10"
          :showErrors="showErrors"
          v-model:sources="sources"
          @missingSourceWarning="missingSourceWarning = $event"
          @nonUrlSourceWarning="nonUrlSourceWarning = $event"
          v-model:noSource="noSource"
        ></sources-input>
      </div>
    </div>

    <template v-if="!compactMode">
      <!-- Artist and Contributor Tags -->
      <div class="uploader-row">
        <div class="uploader-row-label">
          <label class="section-label" for="names">Artists and Contributors</label>
          <div><a href="/forum_topics/23553">How do I tag an artist?</a></div>
          <div>
            Please don't use <a href="/wiki_pages/anonymous_artist">anonymous_artist</a> or
            <a href="/wiki_pages/unknown_artist">unknown_artist</a> tags unless they fall under
            those definitions on the wiki.
          </div>
        </div>
        <div class="uploader-row-input">
          <artist-source :order="2"></artist-source>
        </div>
      </div>

      <!-- Characters -->
      <div class="uploader-row">
        <div class="uploader-row-label">
          <label class="section-label" for="post_sex_tags">Characters</label>
          <div>
            Select (and write in) all that apply. Character sex is based only on what is visible in the
            image.
          </div>
          <div><a href="/wiki_pages/tag_what_you_see">
            Outside information or other images should not be used when deciding what tags are used.
          </a></div>
        </div>
        <div class="uploader-row-input">
          <checkbox-source kind="characters" :order="0"></checkbox-source>
          <tag-textarea
            role="character"
            field-id="post_character"
            :order="3"
            placeholder="Ex: character_name"
          ></tag-textarea>
        </div>
      </div>

      <!-- Body Types and Species -->
      <div class="uploader-row">
        <div class="uploader-row-label">
          <label class="section-label">Body Types and Species</label>
          <div>One listed body type per visible character, listed options are mutually exclusive.</div>
        </div>
        <div class="uploader-row-input">
          <checkbox-source kind="body" :order="0"></checkbox-source>
          <tag-textarea
            role="species"
            field-id="post_species"
            :order="4"
            placeholder="Ex: bear dragon hyena rat newt etc."
          ></tag-textarea>
        </div>
      </div>

      <!-- Contentious Content -->
      <div class="uploader-row">
        <div class="uploader-row-label">
          <label class="section-label">Contentious Content</label>
          <div>
            Fetishes or subjects that other users may find extreme or objectionable.
            These allow users to find or blacklist content with ease. Make sure that you are tagging
            these upon initial upload.
          </div>
        </div>
        <div class="uploader-row-input">
          <tag-textarea
            role="content"
            field-id="post_content"
            :order="5"
            placeholder="Ex: young gore scat watersports diaper my_little_pony vore not_furry rape hyper etc."
          ></tag-textarea>
        </div>
      </div>
    </template>

    <!-- Rating -->
    <div class="uploader-row">
      <div class="uploader-row-label">
        <label class="section-label">Rating</label>
        <div>Explicit tags include sex, pussy, penis, masturbation, fellatio, etc.
          (<a href="/help/ratings" target="_blank">help</a>)
        </div>
      </div>
      <div class="uploader-row-input">
        <div class="box-section background-red" v-if="showErrors && invalidRating">
          You must select an appropriate rating for this image.
        </div>
        <div class="toggle-button-group">
          <template v-if="!safe">
            <button class="toggle-button rating-e" :class="{active: rating==='e'}" @click="rating = 'e'">
              Explicit
            </button>
            <button class="toggle-button rating-q" :class="{active: rating==='q'}" @click="rating = 'q'">
              Questionable
            </button>
          </template>
          <button class="toggle-button rating-s" :class="{active: rating==='s'}" @click="rating = 's'">
            Safe
          </button>
        </div>
      </div>
    </div>

    <!-- Mobile-only Preview (bottom) -->
    <file-preview classes="box-section in-editor" :data="previewData"></file-preview>

    <!-- Other Tags -->
    <div class="uploader-row no-border">
      <div class="uploader-row-label">
        <label class="section-label" for="post_tags">Other Tags</label>
        <div>
          Separate tags with spaces. (<a href="/help/tags" target="_blank">help</a>)
        </div>
        <div>
          <a href="/wiki_pages/tag_what_you_see">
            Outside information or other images should not be used when deciding what tags are used.
          </a>
        </div>
        <br />
        <tag-counter :tags="tags" />
      </div>
      <div class="uploader-row-input">
        <div class="box-section background-red" v-show="showErrors && notEnoughTags">
          You must provide at least <b>{{4 - tagCount}}</b> more tags. Tags in other sections count
          towards this total.
        </div>
        <textarea
          class="tag-textarea"
          id="post_tags"
          v-model="otherTags"
          rows="5"
          placeholder="Ex: standing orange_fur white_shirt outside smile 4_toes etc."
          ref="otherTagsField"
          data-autocomplete="tag-edit"
        ></textarea>
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

    <!-- Related Tags -->
    <div class="uploader-row">
      <related-tags
        v-if="relatedTags.length || loadingRelated"
        :tags="tagsArray"
        :related="relatedTags"
        :loading="loadingRelated"
        :uploaded-tags="uploadTags"
        :recent-tags="recentTags"
        @tag-active="pushTag"
      ></related-tags>
    </div>

    <!-- Parent Post ID -->
    <div class="uploader-row">
      <div class="uploader-row-label">
        <label class="section-label">Parent Post ID</label>
      </div>
      <div class="uploader-row-input">
        <parent-post-input v-model="parentID" />
      </div>
    </div>

    <!-- Locked Tags -->
    <div v-if="allowLockedTags" class="uploader-row">
      <div class="uploader-row-label">
        <label class="section-label">Locked Tags</label>
      </div>
      <div class="uploader-row-input">
        <input type="text" v-model="lockedTags" data-autocomplete="tag-query"/>
      </div>
    </div>

    <!-- Lock Rating -->
    <div v-if="allowRatingLock" class="uploader-row">
      <div class="uploader-row-label">
        <label class="section-label">Lock Rating</label>
      </div>
      <div class="uploader-row-input">
        <label><input type="checkbox" v-model="ratingLocked"/> Lock Rating</label>
      </div>
    </div>

    <!-- Description -->
    <div class="uploader-row">
      <div class="uploader-row-label">
        <label class="section-label" for="post_description">Description</label>
      </div>
      <div class="uploader-row-input">
        <div
          class="dtext-formatter pending"
          data-state="write"
          data-allow-color="false"
          data-limit="50000"
        >
          <textarea
            class="dtext required dtext-formatter-input dtext-vue"
            id="post_description"
            rows="10"
            v-model="description"
          ></textarea>
        </div>
      </div>
    </div>

    <!-- Upload as Pending -->
    <div v-if="allowUploadAsPending" class="uploader-row">
      <div class="uploader-row-label">
        <label class="section-label">Upload as Pending</label>
        <div>If you aren't sure if this particular post is up to the standards, checking this box will put it into the moderation queue.</div>
      </div>
      <div class="uploader-row-input">
        <label><input type="checkbox" v-model="uploadAsPending"/> Upload as Pending</label>
      </div>
    </div>

    <!-- Submit & Errors -->
    <div class="uploader-row">
      <div class="uploader-row-label"></div>
      <div class="uploader-row-input">
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
        <button
          class="st-button submit"
          @click="submit"
          :disabled="(showErrors && preventUpload) || submitting"
          accesskey="s"
        >
          {{ submitting ? 'Uploading...' : 'Upload' }}
        </button>
      </div>
    </div>
  </div>

  <!-- Desktop Preview (sidebar) -->
  <div class="uploader-column column-right" id="preview-sidebar">
    <file-preview classes="in-sidebar" :data="previewData"></file-preview>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, provide, onMounted, onBeforeUnmount, markRaw, type Ref } from "vue";
  import { submitUploadForm } from "@/utility/UploadSubmission";
  import { fetchRelatedTags, selectedText } from "@/components/tags/related_tags";
  import type { RelatedTagGroup } from "@/components/tags/types";
  import ToastManager from "@/utility/Toast";
  import SourcesInput from '@/components/uploads/sources.vue';
  import CheckboxSource from './checkbox_source.vue';
  import TagTextarea from './tag_textarea.vue';
  import RelatedTags from '@/components/tags/related.vue';
  import TagPreview from '@/components/tags/tag_preview.vue';
  import TagCounter from '@/components/tags/tag_counter.vue';
  import FilePreview from '@/components/uploads/file_preview.vue';
  import FileInput from '@/components/uploads/file_input.vue';
  import SimilarPosts from '@/components/uploads/similar_posts.vue';
  import ParentPostInput from './parent_post_input.vue';
  import ArtistSource from './artist_source.vue';
  import * as TagField from '@/components/tags/tag_field';
  import Autocomplete from "@/components/autocomplete";
  import DTextFormatter from "@/components/DTextFormatter";
  import CurrentUser from "@/models/CurrentUser";
  import UploadData from "@/models/UploadData";
  import TagCategories from "@/utility/TagCategories";
  import Settings from "@/utility/Settings";
  import { tagRegistryKey, type TagSource } from "./registry";
  import type { PreviewData, UploadChange } from "@/components/uploads/types";

  defineOptions({ name: "Uploader" });

  // Shape of submitUploadForm's `error` JSON body (the `outcome.json` branch).
  interface UploadErrorBody { reason?: string; post_id?: number; message?: string }

  provide(tagRegistryKey, {
    register: registerSource,
    unregister: unregisterSource,
  });

  // Immutable per-session config (read in the template).
  const safe = UploadData.safeSite;
  const compactMode = UploadData.compactMode;
  const uploadTags = UploadData.uploadTags;
  const recentTags = UploadData.recentTags;
  const allowLockedTags = CurrentUser.is.admin;
  const allowRatingLock = CurrentUser.is.privileged;
  const allowUploadAsPending = CurrentUser.can.uploadFree;
  const iqdbEnabled = Settings.Iqdb.enabled;

  const showErrors = ref(false);
  const submitting = ref(false);

  const previewData = ref<PreviewData>({ url: '', isVideo: false });
  const uploadValue = ref<string | File>('');
  const invalidUploadValue = ref(false);
  const whitelistAllowed = ref<boolean | undefined>(undefined);

  const missingSourceWarning = ref(false);
  const nonUrlSourceWarning = ref(false);
  const noSource = ref(false);
  const sources = ref<string[]>(['']);

  // Tag sources register here; `tags` aggregates their contributions.
  const registry = reactive<{ sources: TagSource[] }>({ sources: [] });
  // The free-text "Other Tags" field is the always-present sink (inline on the
  // root so findRelated can reach its textarea via the otherTagsField ref).
  const otherTags = ref("");
  const otherTagsField = ref<HTMLTextAreaElement | null>(null);

  const lockedTags = ref('');
  const ratingLocked = ref(false);
  const uploadAsPending = ref(false);

  const relatedTags = ref<RelatedTagGroup[]>([]);
  let lastRelatedCategoryId: number | undefined;
  const loadingRelated = ref(false);

  const parentID = ref('');
  const description = ref('');
  const rating = ref('');
  const error = ref('');
  const duplicateId = ref(0);

  // Not reactive: read only by the unload guard.
  let allowNavigate = false;

  // The free-text "Other Tags" field is the always-present sink. Created here so
  // it stays a stable setup binding, registered in onMounted (before the
  // query-param import, which routes through it).
  const sinkDescriptor: TagSource = {
    isSink: true,
    order: 1, // checkboxes (0) then other (1) then artist/character/species/content
    currentTags: () => TagField.splitTags(otherTags.value),
    addTags: tags => { otherTags.value = TagField.addTags(otherTags.value, tags); },
    removeTag: tag => { otherTags.value = TagField.removeTag(otherTags.value, tag); },
  };

  function unloadHandler(event: BeforeUnloadEvent) {
    if (allowNavigate || (uploadValue.value === "" && tags.value === "")) {
      return;
    }
    // preventDefault (+ legacy returnValue) is what triggers the leave-site prompt
    // for an addEventListener handler; a truthy return only works for onbeforeunload.
    event.preventDefault();
    event.returnValue = "";
  }

  onMounted(() => {
    registerSource(sinkDescriptor);

    window.addEventListener("beforeunload", unloadHandler);
    const params = new URLSearchParams(window.location.search);
    const fillField = function(target: Ref<string>, key: string) {
      if (params.has(key)) target.value = params.get(key)!;
    };
    const fillFieldBool = function(target: Ref<boolean>, key: string) {
      if (params.has(key)) target.value = (params.get(key) === 'true');
    };

    // Import tags from query parameters. Routing handles mode: params whose
    // role source isn't mounted (compact) fall through to the sink.
    const fillTags = function() {
      const queryList = ["tags-artist", "tags-character", "tags-species", "tags-content"];

      if (params.has("tags"))
        importTags(params.get("tags")!, "other");

      for (const name of queryList) {
        if (!params.has(name)) continue;
        importTags(params.get(name)!, name.replace("tags-", ""));
      }
    };

    // Import the post rating from a query parameter
    const fillRating = function() {
      if (!params.has("rating")) return;
      const value = params.get("rating")![0].toLowerCase();
      if (!/[sqe]/.test(value)) return;
      rating.value = value;
    };

    fillField(parentID, 'parent');
    fillField(description, 'description');
    fillTags();
    fillRating();
    if (params.has('sources')) {
      sources.value = params.get('sources')!.split(',');
    }
    if (allowRatingLock)
      fillFieldBool(ratingLocked, 'rating_locked');
    if (allowLockedTags)
      fillField(lockedTags, 'locked_tags');
    if (allowUploadAsPending)
      fillFieldBool(uploadAsPending, "upload_as_pending");

    Autocomplete.initialize_autocomplete('tag-edit');
    if (allowLockedTags)
      Autocomplete.initialize_autocomplete('tag-query');
    new DTextFormatter($<HTMLDivElement>(".dtext-formatter.pending"));
  });

  onBeforeUnmount(() => {
    window.removeEventListener("beforeunload", unloadHandler);
  });

  function onFileChange({ value, preview, invalid, whitelistAllowed: allowed }: UploadChange) {
    uploadValue.value = value;
    previewData.value = preview;
    invalidUploadValue.value = invalid;
    whitelistAllowed.value = allowed;
  }

  // ===== Tag-source coordinator =====
  // markRaw keeps descriptors out of the reactive proxy so `unregisterSource`
  // can match them by identity (a proxied element would never === the raw
  // object the child holds, and the filter would remove nothing).
  function registerSource(descriptor: TagSource) {
    registry.sources.push(markRaw(descriptor));
  }
  function unregisterSource(descriptor: TagSource) {
    registry.sources = registry.sources.filter(s => s !== descriptor);
  }
  // Shared routing lookups so every inbound path (route / routeByRole / importTags)
  // applies the same rule and can't drift apart.
  function findOwner(tag: string) {
    return registry.sources.find(s => s.ownsTag && s.ownsTag(tag));
  }
  function findSink() {
    return registry.sources.find(s => s.isSink);
  }
  // Inbound routing: by value (a source that owns the tag) then the sink.
  function route(tag: string) {
    return findOwner(tag) || findSink();
  }
  // Inbound routing by role (query import), falling back to the sink.
  function routeByRole(role: string) {
    return registry.sources.find(s => s.role === role) || findSink();
  }
  async function submit() {
    showErrors.value = true;
    error.value = '';
    duplicateId.value = 0;
    if (preventUpload.value || submitting.value)
      return;
    submitting.value = true;
    const data = new FormData();
    if (typeof uploadValue.value === "string") {
      data.append('upload[direct_url]', uploadValue.value);
    } else {
      data.append('upload[file]', uploadValue.value);
    }
    data.append('upload[tag_string]', tags.value);
    data.append('upload[rating]', rating.value);
    data.append('upload[source]', noSource.value ? '' : sources.value.join('\n'));
    data.append('upload[description]', description.value);
    if (parentID.value)
      data.append('upload[parent_id]', parentID.value);
    if (allowLockedTags)
      data.append('upload[locked_tags]', lockedTags.value);
    if (allowRatingLock)
      data.append('upload[locked_rating]', String(ratingLocked.value));
    if (allowUploadAsPending)
      data.append('upload[as_pending]', String(uploadAsPending.value));
    const outcome = await submitUploadForm('/uploads.json', data);
    submitting.value = false;

    if (outcome.kind === 'success') {
      allowNavigate = true;
      ToastManager.notice('Post uploaded successfully.');
      location.assign(outcome.body.location);
      return;
    }
    if (outcome.kind === 'blocked' || outcome.kind === 'failed') {
      error.value = outcome.message;
      return;
    }

    const jsonData = outcome.json as UploadErrorBody;
    if (jsonData.reason === 'duplicate') duplicateId.value = jsonData.post_id ?? 0;
    if (['duplicate', 'invalid'].indexOf(jsonData.reason) !== -1) {
      error.value = jsonData.message;
    } else if (jsonData.message) {
      error.value = 'Error: ' + jsonData.message;
    } else {
      error.value = 'Error: ' + jsonData.reason;
    }
  }
  // Related-tag toggle: route the tag to its owning source, else the sink.
  function pushTag(tag: string, add: boolean) {
    const source = route(tag);
    if (!source) return;
    if (add) source.addTags([tag]);
    else source.removeTag(tag);
  }

  /**
   * Import tags from a query parameter into the given role's field.
   * @param tags Raw tag string
   * @param role Target role ("other" for the sink, "artist"/"character"/…)
   */
  function importTags(tags: string, role: string) {
    const incoming = (tags + "").trim().split(" ").filter(n => n);
    const deduped: string[] = [];
    for (const tag of incoming) if (!deduped.includes(tag)) deduped.push(tag);

    // Each tag routes to exactly one place: its owning source (a checkbox flip)
    // if owned, otherwise the role's field — or the sink if that source isn't
    // mounted. Owned tags are NOT also added to the field (that duplicated them).
    const unrouted: string[] = [];
    for (const tag of deduped) {
      const owner = findOwner(tag);
      if (owner) owner.addTags([tag]);
      else unrouted.push(tag);
    }
    if (unrouted.length) {
      const target = routeByRole(role);
      if (target) target.addTags(unrouted);
    }
  }
  async function findRelated(categoryName?: string) {
    const categoryId = categoryName ? TagCategories.idFor(categoryName) : undefined;
    if (loadingRelated.value)
      return;
    if (relatedTags.value.length > 0 && lastRelatedCategoryId === categoryId) {
      relatedTags.value = [];
      return;
    }
    loadingRelated.value = true;
    relatedTags.value = [];
    const query = selectedText(otherTagsField.value!) ?? tags.value;
    try {
      relatedTags.value = await fetchRelatedTags(query, categoryId);
      lastRelatedCategoryId = categoryId;
    } catch {
      // A failed lookup just shows no related tags (relatedTags stays []).
    } finally {
      loadingRelated.value = false;
    }
  }

  // Aggregate every registered source, in declared `order` (not registration
  // order) so the preview matches the pre-registry sequence. Serialization is
  // identical (first-comma replace + whitespace collapse); no cross-source dedupe.
  const tags = computed(() => {
    return [...registry.sources]
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
      .flatMap(s => s.currentTags())
      .join(' ').replace(/,/g, ' ').trim().replace(/ +/g, ' ');
  });
  const tagsArray = computed(() => tags.value.toLowerCase().split(' '));
  const tagCount = computed(() => new Set(TagField.splitTags(tags.value)).size);
  const notEnoughTags = computed(() => tagCount.value < 4);
  const invalidRating = computed(() => !rating.value);
  // Empty string = nothing provided; a URL string or a File is truthy.
  const noUpload = computed(() => !uploadValue.value);
  const preventUpload = computed(() =>
    missingSourceWarning.value || nonUrlSourceWarning.value || notEnoughTags.value
    || invalidRating.value || invalidUploadValue.value || noUpload.value);
  const duplicatePath = computed(() => `/posts/${duplicateId.value}`);
</script>
