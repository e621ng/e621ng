<template>
  <div class="upload-status" aria-live="polite">
    <div v-if="outcome === 'completed'" class="box-section background-green">
      Post created, redirecting&hellip;
      <a :href="postPath">View the post</a>
    </div>

    <div v-else-if="outcome === 'duplicate'" class="box-section background-red">
      This file is a duplicate of
      <a v-if="upload.duplicate_post_id" :href="`/posts/${upload.duplicate_post_id}`">post #{{ upload.duplicate_post_id }}</a>
      <span v-else>a post that no longer exists</span>.
    </div>

    <div v-else-if="outcome === 'failed'" class="box-section background-red">
      <p>The upload could not be processed: {{ upload.error_message || "unknown error" }}</p>
      <p><a :href="retryUrl">Back to the upload form</a> (your tags and details are kept).</p>
    </div>

    <div v-else class="box-section background-grey">
      <p v-if="upload.status === 'queued'">Waiting for a worker&hellip;</p>
      <p v-else-if="!upload.processing_step">Preparing&hellip;</p>
      <ol class="steps">
        <li v-for="step in steps" :key="step.key" :class="stateOf(step.key)">{{ step.label }}</li>
      </ol>
      <p v-if="connectionLost" class="connection-lost">Connection lost, retrying&hellip;</p>
    </div>

    <div v-if="upload.warning_messages && upload.warning_messages.length" class="box-section background-yellow">
      <p v-for="warning in upload.warning_messages" :key="warning">{{ warning }}</p>
    </div>
  </div>
</template>

<script lang="ts">
export interface UploadJson {
  id: number;
  status: string;
  processing_step: string | null;
  post_id: number | null;
  error_message: string | null;
  warning_messages: string[] | null;
  duplicate_post_id: number | null;
}
</script>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import HTTP from "@/utility/HTTP";

defineOptions({ name: "UploadStatus" });

const props = defineProps<{
  uploadId: number;
  fileExt: string;
  retryUrl: string;
  initial: UploadJson;
}>();

// Order matches UploadProcessingJob::STEPS.
const ALL_STEPS = [
  { key: "integrity", label: "Checking the file" },
  { key: "thumbnail", label: "Generating previews" },
  { key: "sound", label: "Detecting audio", videoOnly: true },
  { key: "post", label: "Creating the post" },
];
const FAST_POLL_MS = 1000;
const SLOW_POLL_MS = 3000;
const FAST_POLL_WINDOW_MS = 10_000;
const CONNECTION_LOST_AFTER = 3;

const upload = ref<UploadJson>(props.initial);
const failures = ref(0);
const startedAt = Date.now();
let timer: ReturnType<typeof setTimeout> | null = null;
let stopped = false;

const isVideo = ["webm", "mp4"].includes(props.fileExt);
const steps = ALL_STEPS.filter((step) => !step.videoOnly || isVideo);

type Outcome = "completed" | "duplicate" | "failed" | "pending";
const outcome = computed<Outcome>(() => {
  const status = upload.value.status;
  if (status === "completed") return "completed";
  if (status === "failed") return "failed";
  if (status.startsWith("duplicate")) return "duplicate";
  return "pending";
});
const postPath = computed(() => `/posts/${upload.value.post_id}`);
const connectionLost = computed(() => failures.value >= CONNECTION_LOST_AFTER);

function stateOf (key: string): string {
  if (outcome.value === "completed") return "done";
  const current = steps.findIndex((step) => step.key === upload.value.processing_step);
  const index = steps.findIndex((step) => step.key === key);
  if (current < 0) return "pending";
  if (index < current) return "done";
  if (index === current) return "active";
  return "pending";
}

function settle (): void {
  stopped = true;
  if (outcome.value === "completed" && upload.value.post_id)
    location.assign(postPath.value);
}

function schedule (): void {
  if (stopped) return;
  const delay = Date.now() - startedAt < FAST_POLL_WINDOW_MS ? FAST_POLL_MS : SLOW_POLL_MS;
  timer = setTimeout(tick, delay);
}

async function tick (): Promise<void> {
  timer = null;
  if (stopped) return;
  // Background tabs wait until they are looked at, so a set opened in many tabs does not poll from each.
  if (document.hidden) {
    document.addEventListener("visibilitychange", () => void tick(), { once: true });
    return;
  }

  try {
    upload.value = await HTTP.getJSON<UploadJson>(`/uploads/${props.uploadId}.json`);
    failures.value = 0;
  } catch {
    failures.value += 1;
  }

  if (outcome.value === "pending") schedule();
  else settle();
}

onMounted(() => {
  if (outcome.value === "pending") schedule();
  else settle();
});

onBeforeUnmount(() => {
  stopped = true;
  if (timer) clearTimeout(timer);
});
</script>
