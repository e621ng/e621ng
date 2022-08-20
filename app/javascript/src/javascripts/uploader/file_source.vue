<template>
    <div class="upload-source-row">
        <input type="text" size="50" v-model="realValue" @keyup.enter="add"/>
        <button @click="remove" v-if="index !== 0">-</button>
        <button @click="add" v-if="last && index < maxSources - 1">+</button>
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
      }
    },
    watch: {
      modelValue(v) {
        this.backendValue = v;
      }
    }
  }
</script>
