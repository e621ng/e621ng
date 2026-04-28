<template>
    <div class="upload-source-row" v-bind:index="index">
        <input
          type="text"
          size="50"
          ref="inputEl"
          v-model="realValue"
          @keyup.enter="fadd"
          @keyup.up="focusPrev"
          @keyup.down="focusNext"
          @paste="paste"
        />
        <button @click="remove">&times;</button>
    </div>
</template>

<script>
  export default {
    props: ['modelValue', 'index', 'last', 'maxSources'],
    data() {
      return {
        backendValue: this.modelValue
      };
    },
    computed: {
      'realValue': {
        get: function () {
          return this.backendValue;
        },
        set: function (v) {
          this.backendValue = v;
          this.$emit('update:modelValue', v);
        }
      }
    },
    methods: {
      // Focus the input element for this source row
      focus() {
        if (this.$refs && this.$refs.inputEl) {
          this.$refs.inputEl.focus();
        }
      },
      add() { this.$emit("add"); },
      fadd() { this.$emit("fadd") },
      remove() { this.$emit("delete"); },
      paste($event) { this.$emit("madd", $event); },
      focusNext() { this.$emit("navigate", this.index + 1); },
      focusPrev() { this.$emit("navigate", this.index - 1); },
    },
    watch: {
      modelValue(v) {
        this.backendValue = v;
      }
    }
  }
</script>
