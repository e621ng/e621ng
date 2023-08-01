<template>
  <div class="box-section sect_red source_warning" v-show="showErrors && sourceWarning">
    A source must be provided or you must select that there is no available source.
  </div>
  <div v-if="!noSource">
    <file-source :maxSources="maxSources" :last="i === (sources.length-1)" :index="i" v-model="sources[i]"
                    v-for="s, i in sources"
                    @delete="removeSource(i)" @add="addSource" :key="i"></file-source>
  </div>
  <div>
    <label class="section-label"><input type="checkbox" id="no_source" v-model="noSource"/>
      No available source.
    </label>
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
      },
      addSource() {
        if (this.sources.length < this.maxSources) {
          this.sources.push("");
        }
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
