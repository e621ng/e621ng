<template>
    <button class="toggle-button" :class="{active: value}" @click="value = !value">{{check.name}}</button>
</template>

<script>
  export default {
    props: ['check', 'checks'],
    computed: {
      value: {
        get() {
          if (this.checks[this.tagName] === undefined)
            return false;
          return this.checks[this.tagName];
        },
        set(v) {
          this.$emit('set', this.tagName, v);
        }
      },
      tagName() {
        return this.check.tag || this.check.name.toLowerCase().replace(/ /g, '_');
      }
    }
  }
</script>
