<template>
  <span class="options">
    <!-- eslint-disable-next-line vue/no-v-html -->
    <svg id="face" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"
      fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
      :class="'face-' + face" v-html="faceIcon"></svg>
    <span class="count">{{ countLabel }}</span>
  </span>
</template>

<script>
import SVGIcon from "@/utility/SVGIcon";
import { splitTags } from "./tag_field.js";

// The tag counter (count + mood face) for a tag-string input. Renders the same
// markup shape the server header used to, so specific/tags.scss applies as is.
// NOTE: #face is styled by id — before mounting a second instance on one page
// (e.g. uploader adoption), restyle it to a class.
export default {
  props: {
    tags: { type: String, default: "" },
  },
  computed: {
    // Unique raw tokens, no case folding — matches the retired Post.update_tag_count.
    count() {
      return new Set(splitTags(this.tags)).size;
    },
    countLabel() {
      return this.count === 1 ? "1 tag" : this.count + " tags";
    },
    face() {
      if (this.count < 15) return "frown";
      if (this.count < 25) return "meh";
      return "smile";
    },
    faceIcon() {
      return SVGIcon.ICONS["face_" + this.face];
    },
  },
};
</script>
