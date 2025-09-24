<template>
  <div class="box-section background-red source_warning" v-show="showErrors && sourceWarning">
    A source must be provided or you must select that there is no available source.
  </div>
  <div class="upload-source-list" v-if="!noSource">
    <file-source
      :maxSources="maxSources"
      :last="i === (sources.length-1)"
      :index="i"
      v-model="sources[i]"
      v-for="s, i in sources"
      @delete="removeSource(i)"
      @add="addSource"
      @madd="pasteSource($event, i)"
      :key="i"
    ></file-source>
  </div>
  <div class="upload-source-more">
    <label class="section-label upload-source-none">
      <input type="checkbox" id="no_source" v-model="noSource"/>
      No available source.
    </label>
    <button @click="addSource" v-if="sources.length < maxSources && !noSource" class="upload-source-add">Add another source</button>
  </div>
</template>

<script>
  import fileSource from "./file_source.vue";
  export default {
    components: {
      "file-source": fileSource,
    },
    props: ["showErrors", "sources", "maxSources"],
    data() {
      return {
        noSource: false,
      };
    },
    emits: ["sourceWarning"],
    methods: {
      removeSource(i) {
        this.sources.splice(i, 1);
        if (this.sources.length === 0)
          this.sources.push("");
      },
      addSource() {
        if (this.sources.length < this.maxSources) {
          this.sources.push("");
        }
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
        this.sources.splice(index, urls.length, ...urls);
      },
    },
    computed: {
      sourceWarning: function() {
        const validSourceCount = this.sources.filter(function (source) {
          return source.length > 0;
        }).length;
        return !this.noSource && (validSourceCount === 0);
      },
    },
    watch: {
      sourceWarning: {
        immediate: true,
        handler() {
          this.$emit("sourceWarning", this.sourceWarning);
        }  
      },
    },
  }
</script>
