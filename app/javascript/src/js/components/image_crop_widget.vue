<template>
  <div class="image-crop-widget" ref="container">
    <div class="image-crop-widget-image-wrap" ref="wrap"
         @pointerdown="onWrapPointerDown"
         @pointermove="onPointerMove"
         @pointerup="onPointerUp"
         @pointercancel="onPointerUp">
      <img
        ref="img"
        :src="imageUrl"
        :style="{ display: 'block', maxWidth: '100%' }"
        @load="onImageLoad"
        draggable="false"
      />
      <div
        v-if="selection"
        class="image-crop-widget-selection"
        v-bind:class="[(sizeWarning ? 'size-warning' : ''), (niceWarning ? 'nice-warning' : '')]"
        :style="selectionStyle"
        @pointerdown.stop="onSelectionPointerDown"
      >
        <div v-for="h in handles" :key="h" class="image-crop-handle" :data-handle="h" @pointerdown.stop="onHandlePointerDown($event, h)" />
      </div>
    </div>
    <p v-if="niceWarning" class="image-crop-widget-nice">Selection is very nice (69x69 px in source image).</p>
    <p v-else-if="sizeWarning" class="image-crop-widget-warning">Selection is too small (minimum {{ minSize }}×{{ minSize }} px in source image).</p>
  </div>
</template>

<script>
export default {
  name: "ImageCropWidget",

  props: {
    imageUrl:     { type: String, required: true },
    naturalWidth:  { type: Number, required: true },
    naturalHeight: { type: Number, required: true },
    aspectRatio:   { type: Number, default: null },  // null = free, 1 = square
    minSize:       { type: Number, default: 0 },
  },

  emits: ["cropChange"],

  data() {
    return {
      // Displayed image dimensions (set after load)
      displayW: 0,
      displayH: 0,
      // Selection in display pixels: { x, y, w, h }
      selection: null,
      // Drag state
      drag: null,  // { type: "create"|"move"|"resize", pointerId, startX, startY, startSel, handle }
      handles: ["nw", "ne", "sw", "se"],
    };
  },

  computed: {
    scale() {
      return this.displayW > 0 ? this.naturalWidth / this.displayW : 1;
    },

    selectionStyle() {
      if (!this.selection) return {};
      const { x, y, w, h } = this.selection;
      return {
        position: "absolute",
        left: `${x}px`,
        top: `${y}px`,
        width: `${w}px`,
        height: `${h}px`,
      };
    },

    sourceSel() {
      if (!this.selection) return null;
      const s = this.scale;
      return {
        x: Math.round(this.selection.x * s),
        y: Math.round(this.selection.y * s),
        w: Math.round(this.selection.w * s),
        h: Math.round(this.selection.h * s),
      };
    },

    sizeWarning() {
      if (!this.sourceSel || this.minSize <= 0) return false;
      return this.sourceSel.w < this.minSize || this.sourceSel.h < this.minSize;
    },

    // Easter egg: pretty difficult to get accidentally
    niceWarning() {
      if (!this.sourceSel) return false;
      return this.sourceSel.w === 69 && this.sourceSel.h === 69;
    },
  },

  methods: {
    onImageLoad() {
      const img = this.$refs.img;
      this.displayW = img.clientWidth;
      this.displayH = img.clientHeight;
    },

    startDrag(e, dragState) {
      if (!e.isPrimary) return false;
      if (e.button !== 0) return false;
      e.preventDefault();
      this.drag = { ...dragState, pointerId: e.pointerId };
      this.$refs.wrap.setPointerCapture(e.pointerId);
      return true;
    },

    onWrapPointerDown(e) {
      const rect = this.$refs.wrap.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      if (!this.startDrag(e, { type: "create", startX: x, startY: y, startSel: null, handle: null })) return;
      this.selection = { x, y, w: 0, h: 0 };
    },

    onSelectionPointerDown(e) {
      const rect = this.$refs.wrap.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      this.startDrag(e, { type: "move", startX: x, startY: y, startSel: { ...this.selection }, handle: null });
    },

    onHandlePointerDown(e, handle) {
      const rect = this.$refs.wrap.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      this.startDrag(e, { type: "resize", startX: x, startY: y, startSel: { ...this.selection }, handle });
    },

    onPointerMove(e) {
      if (!this.drag || e.pointerId !== this.drag.pointerId) return;
      const rect = this.$refs.wrap.getBoundingClientRect();
      const mx = Math.max(0, Math.min(e.clientX - rect.left, this.displayW));
      const my = Math.max(0, Math.min(e.clientY - rect.top, this.displayH));
      const dx = mx - this.drag.startX;
      const dy = my - this.drag.startY;

      if (this.drag.type === "create") {
        this.selection = this.constrainSel(this.drag.startX, this.drag.startY, dx, dy);
      } else if (this.drag.type === "move") {
        const s = this.drag.startSel;
        this.selection = this.clampSel(s.x + dx, s.y + dy, s.w, s.h);
      } else if (this.drag.type === "resize") {
        this.selection = this.resizeSel(mx, my);
      }
    },

    onPointerUp(e) {
      if (!this.drag || e.pointerId !== this.drag.pointerId) return;
      this.drag = null;
      if (this.sourceSel) this.$emit("cropChange", this.sourceSel);
    },

    // Build a selection from an origin + delta, applying aspect ratio
    constrainSel(ox, oy, dx, dy) {
      if (this.aspectRatio) {
        // Force square (or given ratio): use the larger dimension
        const size = Math.max(Math.abs(dx), Math.abs(dy));
        dx = dx < 0 ? -size : size;
        dy = dy < 0 ? -size : size;
      }
      const x = dx < 0 ? ox + dx : ox;
      const y = dy < 0 ? oy + dy : oy;
      const w = Math.abs(dx);
      const h = this.aspectRatio ? w / this.aspectRatio : Math.abs(dy);
      return this.clampSel(x, y, w, h);
    },

    // Clamp a selection to the image bounds
    clampSel(x, y, w, h) {
      x = Math.max(0, Math.min(x, this.displayW - w));
      y = Math.max(0, Math.min(y, this.displayH - h));
      w = Math.min(w, this.displayW - x);
      h = Math.min(h, this.displayH - y);
      return { x, y, w, h };
    },

    // Resize from a corner handle
    resizeSel(mx, my) {
      const s = this.drag.startSel;
      const handle = this.drag.handle;

      // Determine the fixed corner opposite to the handle being dragged
      const fixedX = handle.includes("e") ? s.x : s.x + s.w;
      const fixedY = handle.includes("s") ? s.y : s.y + s.h;

      let newW = Math.abs(mx - fixedX);
      let newH = this.aspectRatio ? newW / this.aspectRatio : Math.abs(my - fixedY);
      if (this.aspectRatio) newH = newW / this.aspectRatio;

      const newX = mx < fixedX ? fixedX - newW : fixedX;
      const newY = my < fixedY ? fixedY - newH : fixedY;

      return this.clampSel(newX, newY, newW, newH);
    },
  },
};
</script>
