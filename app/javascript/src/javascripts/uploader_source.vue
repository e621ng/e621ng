<template>
    <div>
        <input type="text" size="50" v-model="realValue" @keyup.enter="add"/>
        <button @click="remove" v-if="index !== 0">-</button>
        <button @click="add" v-if="last && index < 9">+</button>
    </div>
</template>

<script>
  export default {
    props: ['value', 'index', 'last'],
    data() {
      return {
        backendValue: this.value
      };
    },
    computed: {
      'realValue': {
        get: function () {
          return this.backendValue;
        },
        set: function (v) {
          this.backendValue = v;
          this.$emit('input', v);
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
      value(v) {
        this.backendValue = v;
      }
    }
  }
</script>
