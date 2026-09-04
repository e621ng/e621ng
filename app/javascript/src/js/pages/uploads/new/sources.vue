<template>
  <div class="box-section background-red source_warning" v-show="showErrors && missingSourceWarning">
    A source must be provided or you must select that there is no available source.
  </div>
  <div class="box-section background-red source_warning" v-show="showErrors && nonUrlSourceWarning">
    The source must be a URL, starting with "http" or "https".
  </div>
  <div class="upload-source-more">
    <label class="section-label upload-source-none">
      <input type="checkbox" id="no_source" :checked="noSource" @change="$emit('update:noSource', $event.target.checked)"/>
      No available source.
    </label>
    <button @click="addSource" v-if="sources.length < maxSources && !noSource" class="upload-source-add">Add another source</button>
  </div>
  <div class="upload-source-list" v-if="!noSource">
    <file-source
      :index="i"
      :model-value="sources[i]"
      @update:model-value="updateSource(i, $event)"
      v-for="s, i in sources"
      @delete="removeSource(i)"
      @fadd="addSource(i + 1)"
      @madd="pasteSource($event, i)"
      @navigate="navigate($event)"
      :key="i"
      ref="fileSources"
    ></file-source>
  </div>
</template>

<script>
  import fileSource from "./file_source.vue";
  export default {
    components: {
      "file-source": fileSource,
    },
    props: ["showErrors", "sources", "maxSources", "noSource"],
    emits: ["missingSourceWarning", "nonUrlSourceWarning", "update:sources", "update:noSource"],
    methods: {
      // The list is owned by the parent (v-model:sources). Every mutation builds a
      // new array and emits it; the prop is never written in place.
      updateSource(i, value) {
        const next = this.sources.slice();
        next[i] = value;
        this.$emit("update:sources", next);
      },
      removeSource(i) {
        const next = this.sources.slice();
        next.splice(i, 1);
        if (next.length === 0)
          next.push("");
        this.$emit("update:sources", next);
      },
      addSource(i) {
        if (this.sources.length >= this.maxSources) return;

        const next = this.sources.slice();
        let targetIndex;
        // Insert a new source at the requested index (e.g. after current row)
        if (typeof i === "number" && i >= 0 && i <= next.length) {
          next.splice(i, 0, "");
          targetIndex = i;
        } else {
          next.push("");
          targetIndex = next.length - 1;
        }
        this.$emit("update:sources", next);

        // Focus the newly created source after the parent round-trips the array back.
        this.$nextTick(() => {
          const refs = this.$refs.fileSources;
          if (refs && refs[targetIndex])
            refs[targetIndex].focus();
        });
      },
      pasteSource(event, index) {
        if (!event.clipboardData) return;
        // Default to vanilla behavior if only one line is pasted
        const pastedText = event.clipboardData.getData("text/plain");
        if (!pastedText) return;
        const urls = pastedText.split(/\r?\n/).map(url => url.trim()).filter(n => n);
        if (urls.length < 2) return;

        event.preventDefault();

        // Ensure that the maximum number of sources is not exceeded
        if (urls.length + index > this.maxSources)
          urls.splice(this.maxSources - index);

        // Insert the pasted URLs starting at the current index
        const next = this.sources.slice();
        next.splice(index, urls.length, ...urls);
        this.$emit("update:sources", next);
      },
      navigate($event) {
        let targetIndex = $event;
        if (targetIndex >= this.sources.length) targetIndex = 0;
        else if (targetIndex < 0) targetIndex = this.sources.length - 1;

        const refs = this.$refs.fileSources;
        if (refs[targetIndex]) refs[targetIndex].focus();
      },
    },
    computed: {
      missingSourceWarning: function() {
        const validSourceCount = this.sources.filter(function (source) {
          return source.length > 0;
        }).length;
        return !this.noSource && (validSourceCount === 0);
      },
      nonUrlSourceWarning: function() {
        if (this.noSource) return false;

        return this.sources.some(function (source) {
          if (source.length <= 0) return false;

          // Allow dead source links prefixed with `-`
          if (source[0] === "-") source = source.substring(1);
          try {
            const url = new URL(source);
            return url.protocol !== "http:" && url.protocol !== "https:";
          } catch { }  // Exception occurs if the URL constructor fails to parse the string, which means it's not a valid URL
          return true;
        });
      },
    },
    watch: {
      missingSourceWarning: {
        immediate: true,
        handler() {
          this.$emit("missingSourceWarning", this.missingSourceWarning);
        }
      },
      nonUrlSourceWarning: {
        immediate: true,
        handler() {
          this.$emit("nonUrlSourceWarning", this.nonUrlSourceWarning);
        }
      },
    },
  }
</script>
