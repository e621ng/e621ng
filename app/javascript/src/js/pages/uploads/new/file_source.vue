<template>
    <div class="upload-source-row" v-bind:index="index">
        <input
          type="text"
          size="50"
          placeholder="Ex: https://example.com/artist/post/12345"
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
    props: ['modelValue', 'index'],
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
