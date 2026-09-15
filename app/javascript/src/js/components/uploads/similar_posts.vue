<template>
  <div class="similar-posts" v-if="showWrapper">
    <div class="similar-posts-header">
      <span class="similar-posts-title">Similar posts</span>
    </div>
    <div class="box-section background-red similar-posts-error" v-if="error">
      {{ error.message }}
      <button @click.prevent="retry" :disabled="cooldownActive">Retry</button>
    </div>
    <div class="similar-posts-pending" v-if="pending">Searching for similar posts&hellip;</div>
    <template v-else-if="matches !== null">
      <div class="similar-posts-strip" v-if="shownMatches.length">
        <a
          v-for="match in shownMatches"
          :key="match.post_id"
          :href="`/posts/${match.post_id}`"
          target="_blank"
        >
          <img v-if="previewUrl(match)" :src="previewUrl(match)!" :alt="`Post #${match.post_id}`" />
          <span v-else class="similar-posts-placeholder">
            <b>Post #{{ match.post_id }}</b>
            <span>{{ match.post.flags?.deleted ? "Deleted" : "Not visible" }}</span>
          </span>
          <span class="similar-posts-score">{{ Math.round(match.score) }}%</span>
        </a>
      </div>
      <div class="similar-posts-none" v-if="matches.length === 0 && !error">
        No similar posts found.
      </div>
      <div class="similar-posts-more" v-if="hiddenCount > 0">
        <a :href="`/iqdb_queries${typeof props.uploadValue === 'string' ? `?url=${encodeURIComponent(props.uploadValue)}` : ''}`">
          {{ hiddenCount }} more on the full search page
        </a>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onBeforeUnmount } from "vue";
import Settings from "@/utility/Settings";
import HTTP from "@/utility/HTTP";
import { downscaleImage } from "@/utility/ImageDownscale";

// Advisory IQDB duplicate check for the upload form.
// The endpoint is heavily throttled (6/10s per user AND per IP), so every gate below exists to
// spend at most one request per settled, viewed input.

const props = defineProps<{
  uploadValue: string | File;
  invalidUploadValue: boolean;
  whitelistAllowed?: boolean; // undefined = lookup in flight ("hold"), false = denied (skip), true = go.
}>();


const DWELL_MS = 1000; // Pre-filled tabs must not query until actually viewed for a moment.
const SETTLE_MS = 1750; // On top of file_input's 300ms preview debounce - needs the query to be stable
const COOLDOWN_MS = 10_000;
const MAX_SHOWN = 5;

interface IqdbMatch {
  score: number;
  post_id: number;
  post: {
    files?: { preview?: { webp?: string | null, jpg?: string | null } };
    flags?: { deleted?: boolean };
  };
}

const videoExtensions = Settings.Posts.video_extensions;

const matches = ref<IqdbMatch[] | null>(null);
const error = ref<{ status: number, message: string } | null>(null);
const pending = ref(false);
const cooldownActive = ref(false);

let requestId = 0; // Latest-wins token: any in-flight work whose id no longer matches is dropped.
let fired = false; // One request per input key; retry is the only way to fire again.
let settled = false; // The settle debounce has elapsed (immediately true for Files).

let settleTimer: ReturnType<typeof setTimeout> | undefined;
let dwellTimer: ReturnType<typeof setTimeout> | undefined;
let cooldownTimer: ReturnType<typeof setTimeout> | undefined;

// ===== Visibility gate (per tab: stays satisfied while the tab is visible) =====
const visibleAndDwelled = ref(false);

function onVisibilityChange () {
  clearTimeout(dwellTimer);
  if (document.visibilityState === "visible") {
    dwellTimer = setTimeout(() => { visibleAndDwelled.value = true; }, DWELL_MS);
  } else {
    // Dwell must be continuous; cycling through tabs starts over.
    visibleAndDwelled.value = false;
  }
}
document.addEventListener("visibilitychange", onVisibilityChange);
onVisibilityChange(); // seed: an already-visible tab starts its dwell now

watch(visibleAndDwelled, satisfied => { if (satisfied) tryFire(); });

onBeforeUnmount(() => {
  document.removeEventListener("visibilitychange", onVisibilityChange);
  clearTimeout(dwellTimer);
  clearTimeout(settleTimer);
  clearTimeout(cooldownTimer);
  requestId++;
});

// ===== Input pipeline =====
const inputKey = computed(() => {
  const v = props.uploadValue;
  return typeof v === "string" ? `url:${v}` : `file:${v.name}:${v.size}:${v.lastModified}`;
});

// Inputs a query could ever fire for; whitelist "hold" (undefined) stays
// eligible — the verdict watcher resumes it.
const eligible = computed(() => {
  const v = props.uploadValue;
  if (!v || props.invalidUploadValue) return false;
  if (typeof v === "string") {
    if (!/^(https?:\/\/|www)/.test(v)) return false;
    // Trailing extension, tolerating a ?query / #hash suffix (as file_input).
    const ext = (v.toLowerCase().match(/\.([a-z0-9]+)(?:[?#].*)?$/) || [])[1] || "";
    if (videoExtensions.includes(ext)) return false;
    if (props.whitelistAllowed === false) return false;
  } else if (videoExtensions.some(ext => v.type === "video/" + ext)) {
    // Vips can't thumbnail video server-side: a guaranteed-empty result
    // isn't worth the upload or the throttle slot.
    return false;
  }
  return true;
});

watch(inputKey, () => {
  requestId++;
  clearTimeout(settleTimer);
  fired = false;
  settled = false;
  matches.value = null;
  error.value = null;
  pending.value = false;
  if (!eligible.value) return;
  if (typeof props.uploadValue === "string") {
    settleTimer = setTimeout(() => { settled = true; tryFire(); }, SETTLE_MS);
  } else {
    // A picked File is already a settled, discrete event.
    settled = true;
    tryFire();
  }
}, { immediate: true });

// A held URL resumes the moment its whitelist verdict lands; if the settle
// already elapsed while holding, this fires immediately (no double wait).
watch(() => props.whitelistAllowed, () => tryFire());

function tryFire () {
  if (fired || !settled) return;
  if (!eligible.value || !visibleAndDwelled.value) return;
  if (typeof props.uploadValue === "string" && props.whitelistAllowed !== true) return;
  fireQuery();
}

async function fireQuery () {
  const id = ++requestId;
  fired = true;
  pending.value = true;
  error.value = null;
  const value = props.uploadValue;

  try {
    const body = new FormData();
    if (typeof value === "string") {
      body.append("search[url]", value);
    } else {
      const blob = await downscaleImage(value);
      if (id !== requestId) return;
      body.append("search[file]", blob, "query.jpg");
    }

    const response = await HTTP.post("/iqdb_queries.json?v2=true", body);
    if (id !== requestId) return;
    if (response.ok) {
      const json = await response.json();
      if (id !== requestId) return;
      matches.value = Array.isArray(json) ? json : [];
      error.value = null;
      return;
    }

    // Parse before blaming: the body may carry the server's message.
    let serverMessage: string | undefined;
    try {
      const json = await response.json();
      serverMessage = json.message ?? json.reason;
    } catch { /* non-JSON body (proxy/CF page); fall through to the status map */ }
    if (id !== requestId) return;
    setError(response.status, serverMessage);
  } catch {
    if (id !== requestId) return;
    setError(0);
  } finally {
    if (id === requestId) pending.value = false;
  }
}

function setError (status: number, serverMessage?: string) {
  let message: string;
  switch (status) {
    case 429:
      message = "Similarity search is rate-limited, try again shortly.";
      startCooldown();
      break;
    case 503:
      message = "Similarity search is currently unavailable.";
      break;
    case 422:
      message = "Could not fetch the image from that URL.";
      break;
    case 0:
      message = "Similarity search failed. Check your connection and try again.";
      break;
    default:
      message = serverMessage || "Similarity search failed.";
  }
  // An error never clears already-shown results for the same input.
  error.value = { status, message };
}

function startCooldown () {
  cooldownActive.value = true;
  clearTimeout(cooldownTimer);
  cooldownTimer = setTimeout(() => { cooldownActive.value = false; }, COOLDOWN_MS);
}

// Explicit user action: bypasses dwell/settle, still latest-wins.
function retry () {
  if (cooldownActive.value || pending.value) return;
  fireQuery();
}

// ===== Display =====
function previewUrl (match: IqdbMatch): string | null {
  return match.post.files?.preview?.webp ?? match.post.files?.preview?.jpg ?? null;
}

// Every match renders — a viewer-hidden one (deleted for non-staff, safe-mode
// blocked; null preview URLs) gets a placeholder card instead of a thumbnail.
// "This already exists but was deleted" is the strongest warning the component
// can give; suppressing it would defeat the feature's purpose.
const shownMatches = computed(() => (matches.value ?? []).slice(0, MAX_SHOWN));
const hiddenCount = computed(() => (matches.value?.length ?? 0) - shownMatches.value.length);

const showWrapper = computed(() =>
  !!props.uploadValue && (eligible.value || pending.value || matches.value !== null || !!error.value),
);
</script>
