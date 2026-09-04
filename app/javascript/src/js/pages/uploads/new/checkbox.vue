<template>
    <button class="toggle-button" :class="{active: modelValue}"
            @click="$emit('update:modelValue', !modelValue)">{{check.name}}</button>
</template>

<script>
  export default {
    props: {
      check: { type: Object, required: true },
      modelValue: { type: Boolean, default: false },
    },
    emits: ['update:modelValue'],
  }
</script>
