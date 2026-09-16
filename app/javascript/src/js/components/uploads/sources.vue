<template>
  <div class="box-section background-red source_warning" v-show="showErrors && missingSourceWarning">
    A source must be provided or you must select that there is no available source.
  </div>
  <div class="box-section background-red source_warning" v-show="showErrors && nonUrlSourceWarning">
    The source must be a URL, starting with "http" or "https".
  </div>
  <div class="upload-source-more">
    <label class="section-label upload-source-none">
      <input
        type="checkbox"
        id="no_source"
        :checked="noSource"
        @change="$emit('update:noSource', ($event.target as HTMLInputElement).checked)"
      />
      No available source.
    </label>
    <button @click="addSource" v-if="sources.length < maxSources && !noSource" class="upload-source-add">
      Add another source
    </button>
  </div>
  <div class="upload-source-list" v-if="!noSource" ref="sourceList">
    <file-source
      :index="i"
      :model-value="sources[i]"
      @update:model-value="updateSource(i, $event)"
      v-for="s, i in sources"
      @delete="removeSource(i)"
      @fadd="addSource(i + 1)"
      @madd="pasteSource($event, i)"
      @navigate="navigate($event)"
      :key="rowIds[i]"
    ></file-source>
  </div>
</template>

<script setup lang="ts">
  import { ref, computed, watch, nextTick } from "vue";
  import fileSource from "./file_source.vue";

  const props = defineProps<{
    showErrors?: boolean;
    sources: string[];
    maxSources: number;
    noSource?: boolean;
  }>();
  const emit = defineEmits<{
    missingSourceWarning: [value: boolean];
    nonUrlSourceWarning: [value: boolean];
    "update:sources": [value: string[]];
    "update:noSource": [value: boolean];
  }>();

  // Stable per-row ids so Vue keys rows by identity (not index), preserving a
  // row's DOM node — and its focus/caret — across a splice/reorder.
  const rowIds = ref<number[]>([]);
  let nextRowId = 0;
  const sourceList = ref<HTMLElement | null>(null);

  // The list is owned by the parent (v-model:sources). Every mutation builds a
  // new array and emits it; the prop is never written in place.
  function updateSource(i: number, value: string) {
    const next = props.sources.slice();
    next[i] = value;
    emit("update:sources", next);
  }
  function removeSource(i: number) {
    const next = props.sources.slice();
    next.splice(i, 1);
    rowIds.value.splice(i, 1);
    if (next.length === 0) {
      next.push("");
      rowIds.value.push(nextRowId++);
    }
    emit("update:sources", next);
  }
  // `i` is a number from @fadd (insert after row) or the click Event from the
  // "Add another source" button (falls through to append via the typeof guard).
  function addSource(i?: number | Event) {
    if (props.sources.length >= props.maxSources) return;

    const next = props.sources.slice();
    let targetIndex;
    // Insert a new source at the requested index (e.g. after current row)
    if (typeof i === "number" && i >= 0 && i <= next.length) {
      next.splice(i, 0, "");
      rowIds.value.splice(i, 0, nextRowId++);
      targetIndex = i;
    } else {
      next.push("");
      rowIds.value.push(nextRowId++);
      targetIndex = next.length - 1;
    }
    emit("update:sources", next);

    // Focus the newly created source after the parent round-trips the array back.
    nextTick(() => focusRow(targetIndex));
  }
  function pasteSource(event: ClipboardEvent, index: number) {
    if (!event.clipboardData) return;
    // Default to vanilla behavior if only one line is pasted
    const pastedText = event.clipboardData.getData("text/plain");
    if (!pastedText) return;
    const urls = pastedText.split(/\r?\n/).map(url => url.trim()).filter(n => n);
    if (urls.length < 2) return;

    event.preventDefault();

    // Ensure that the maximum number of sources is not exceeded
    if (urls.length + index > props.maxSources)
      urls.splice(props.maxSources - index);

    // Insert the pasted URLs starting at the current index
    const next = props.sources.slice();
    next.splice(index, urls.length, ...urls);
    rowIds.value.splice(index, urls.length, ...urls.map(() => nextRowId++));
    emit("update:sources", next);

    // Focus the last pasted row.
    nextTick(() => focusRow(index + urls.length - 1));
  }
  function navigate($event: number) {
    let targetIndex = $event;
    if (targetIndex >= props.sources.length) targetIndex = 0;
    else if (targetIndex < 0) targetIndex = props.sources.length - 1;

    focusRow(targetIndex);
  }
  // Focus the row input at a VISUAL position. Query the DOM (ordered) rather
  // than $refs — a v-for ref array isn't guaranteed to match DOM order after
  // a keyed insert/move.
  function focusRow(index: number) {
    const inputs = sourceList.value?.querySelectorAll<HTMLInputElement>(".upload-source-row input");
    if (inputs && inputs[index]) inputs[index].focus();
  }

  const missingSourceWarning = computed(() => {
    const validSourceCount = props.sources.filter(source => source.length > 0).length;
    return !props.noSource && (validSourceCount === 0);
  });
  const nonUrlSourceWarning = computed(() => {
    if (props.noSource) return false;

    return props.sources.some(source => {
      if (source.length <= 0) return false;

      // Allow dead source links prefixed with `-`
      if (source[0] === "-") source = source.substring(1);
      try {
        const url = new URL(source);
        return url.protocol !== "http:" && url.protocol !== "https:";
      } catch { }  // Exception occurs if the URL constructor fails to parse the string, which means it's not a valid URL
      return true;
    });
  });

  // Seed on mount and reconcile length when the parent replaces the list
  // wholesale (query-param import). The structural mutators keep rowIds in
  // lockstep, so those changes land here as no-ops.
  watch(() => props.sources, () => {
    while (rowIds.value.length < props.sources.length) rowIds.value.push(nextRowId++);
    if (rowIds.value.length > props.sources.length) rowIds.value.splice(props.sources.length);
  }, { immediate: true });

  watch(missingSourceWarning, () => emit("missingSourceWarning", missingSourceWarning.value), { immediate: true });
  watch(nonUrlSourceWarning, () => emit("nonUrlSourceWarning", nonUrlSourceWarning.value), { immediate: true });
</script>
