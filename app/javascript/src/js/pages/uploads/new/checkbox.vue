<template>
    <button class="toggle-button" :class="{active: modelValue}"
            @click="$emit('update:modelValue', !modelValue)">{{check.name}}</button>
</template>

<script setup lang="ts">
  defineProps<{ check: { name: string }; modelValue?: boolean }>();
  defineEmits<{ "update:modelValue": [value: boolean] }>();
</script>
