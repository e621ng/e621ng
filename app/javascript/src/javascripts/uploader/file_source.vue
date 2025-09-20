<template>
    <div class="upload-source-row" v-bind:index="index">
        <input
          type="text"
          size="50"
          v-model="realValue"
          @keyup.enter="add"
          @paste="paste"
        />
        <button @click="remove">-</button>
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
      add() {
        this.$emit('add');
      },
      remove() {
        this.$emit('delete');
      },
      paste($event) {
        this.$emit('madd', $event);
      },
    },
    watch: {
      modelValue(v) {
        this.backendValue = v;
      }
    }
  }
</script>
