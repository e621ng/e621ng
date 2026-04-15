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

<script>
export default {
  name: 'ParentPostInput',
  props: {
    modelValue: {
      type: [String, Number],
      default: ''
    }
  },
  emits: ['update:modelValue'],
  data() {
    return {
      error: '',
      postData: null,
      loading: false,
      debounceTimer: null
    };
  },
  methods: {
    handleInput(event) {
      const value = event.target.value.trim();
      this.$emit('update:modelValue', value);

      this.error = '';
      this.postData = null;
      
      // Debounce
      if (this.debounceTimer) clearTimeout(this.debounceTimer);
      if (!value) return;

      this.debounceTimer = setTimeout(() => {
        this.validateAndFetch(value);
      }, 500);
    },
    
    validateAndFetch(value) {
      const numValue = parseInt(value, 10);
      if (isNaN(numValue) || numValue.toString() !== value || numValue <= 0) {
        this.error = 'Parent Post ID must be a valid positive integer.';
        return;
      }

      this.fetchPostData(numValue);
    },
    
    async fetchPostData(postId) {
      this.loading = true;
      this.error = '';
      
      try {
        const response = await fetch(`/posts/${postId}.json`);
        
        if (!response.ok) {
          if (response.status === 404) {
            this.error = `Post #${postId} not found.`;
          } else {
            this.error = `Error loading post #${postId}: ${response.statusText}`;
          }
          return;
        }
        
        const data = await response.json();
        
        if (!data || !data.post || !data.post.id) {
          this.error = `Post #${postId} not found or invalid response.`;
          return;
        }
        
        // Preview URL may be null if post is deleted or hidden
        if (!data.post.preview || !data.post.preview.url) {
          this.error = `Post #${postId} is unavailable (may be deleted or hidden in safe mode).`;
          return;
        }
        
        this.postData = data.post;
        
      } catch (error) {
        console.error('Error fetching post data:', error);
        this.error = `Failed to load post #${postId}. Please check your connection.`;
      } finally {
        this.loading = false;
      }
    }
  },
  
  beforeUnmount() {
    if (this.debounceTimer)
      clearTimeout(this.debounceTimer);
  }
};
</script>
