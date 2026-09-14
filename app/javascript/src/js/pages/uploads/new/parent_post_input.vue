<template>
  <div>
    <input 
      :value="modelValue" 
      @input="handleInput"
      placeholder="Ex. 12345"
      type="text"
    />
    
    <div v-if="error" class="upload-parent-error box-section background-red">
      {{ error }}
    </div>
    
    <div v-if="postData && !error" class="upload-parent-preview">
      <a :href="`/posts/${postData.id}`" target="_blank">
        <img 
          :src="postData.preview.url" 
          :alt="`Post #${postData.id}`"
        />
      </a>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onBeforeUnmount } from "vue";
import HTTP from "@/utility/HTTP";

interface ParentPost {
  id: number;
  preview: { url: string };
}

defineProps<{ modelValue?: string | number }>();
const emit = defineEmits<{ "update:modelValue": [value: string] }>();

const error = ref("");
const postData = ref<ParentPost | null>(null);
let debounceTimer: ReturnType<typeof setTimeout> | undefined;

function handleInput(event: Event) {
  const value = (event.target as HTMLInputElement).value.trim();
  emit("update:modelValue", value);

  error.value = "";
  postData.value = null;

  // Debounce
  if (debounceTimer) clearTimeout(debounceTimer);
  if (!value) return;

  debounceTimer = setTimeout(() => {
    validateAndFetch(value);
  }, 500);
}

function validateAndFetch(value: string) {
  const numValue = parseInt(value, 10);
  if (isNaN(numValue) || numValue.toString() !== value || numValue <= 0) {
    error.value = "Parent Post ID must be a valid positive integer.";
    return;
  }

  fetchPostData(numValue);
}

async function fetchPostData(postId: number) {
  error.value = "";

  try {
    const response = await HTTP.get(`/posts/${postId}.json`);

    if (!response.ok) {
      if (response.status === 404) {
        error.value = `Post #${postId} not found.`;
      } else {
        error.value = `Error loading post #${postId}: ${response.statusText}`;
      }
      return;
    }

    const data = await response.json();

    if (!data || !data.post || !data.post.id) {
      error.value = `Post #${postId} not found or invalid response.`;
      return;
    }

    // Preview URL may be null if post is deleted or hidden
    if (!data.post.preview || !data.post.preview.url) {
      error.value = `Post #${postId} is unavailable (may be deleted or hidden in safe mode).`;
      return;
    }

    postData.value = data.post;

  } catch (e) {
    console.error("Error fetching post data:", e);
    error.value = `Failed to load post #${postId}. Please check your connection.`;
  }
}

onBeforeUnmount(() => {
  if (debounceTimer)
    clearTimeout(debounceTimer);
});
</script>
