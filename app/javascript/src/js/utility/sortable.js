/**
 * Pointer-events-based sortable utility for grid layouts.
 *
 * Works on desktop (mouse) and mobile (touch/stylus) via the unified
 * Pointer Events API — no HTML5 drag-and-drop involved.
 *
 * A ghost clone follows the pointer while dragging; a placeholder shows
 * the pending drop position. Pointer capture routes all move/up events
 * to the grabbed element so no document-level listeners are needed.
 * Holding the pointer near the top or bottom of the viewport scrolls the page.
 *
 * @example
 * const sortable = new Sortable(containerEl, {
 *   itemSelector: "li.thumbnail",
 *   idDataKey: "postId",
 *   onReorder: (ids) => console.log("New order:", ids)
 * });
 *
 * // Get current order
 * const currentOrder = sortable.order;
 *
 * // Update after DOM changes
 * sortable.refresh();
 *
 * // Cleanup
 * sortable.destroy();
 */
/** Distance from the top/bottom viewport edge at which a drag starts scrolling the page. */
const AUTOSCROLL_EDGE = 60;

/** Autoscroll speed at the very edge of the viewport, in pixels per second. */
const AUTOSCROLL_MAX_SPEED = 1200;

/** Longest frame gap used for an autoscroll step, so a stalled frame can't cause a jump. */
const AUTOSCROLL_MAX_FRAME = 50;

export default class Sortable {

  /**
   * Create a new Sortable instance.
   *
   * @param {Element|JQuery<HTMLElement>} container Container element holding sortable items
   * @param {Object} [options={}] Configuration options
   * @param {string} [options.itemSelector="li"] CSS selector for sortable items within container
   * @param {string|null} [options.handleSelector=null] CSS selector for drag handle within each item; if null, the entire item is the handle
   * @param {string} [options.idDataKey="id"] Data attribute key for item IDs (e.g., "postId" for data-post-id)
   * @param {Function} [options.onReorder] Callback fired when items are reordered, receives array of IDs
   */
  constructor (container, options = {}) {
    if (!container) throw new Error("Sortable: container is required");
    this.$container = $(container);

    this.settings = {
      itemSelector: options.itemSelector || "li",
      handleSelector: options.handleSelector || null,
      idDataKey: options.idDataKey || "id",
      onReorder: typeof options.onReorder === "function" ? options.onReorder : null,
    };

    // Active drag state; null when idle
    this._drag = null;

    // requestAnimationFrame coalescing for placeholder repositioning
    this._rafId = 0;

    // Latest pointer position of the active drag; shared by placeholder
    // repositioning, the final drop and autoscroll
    this._lastPointer = null;

    // Edge autoscroll loop
    this._scrollRafId = 0;
    this._scrollLastTs = 0;

    this._rebuildIndex();
    this.bindAll();
  }

  /** Clean up the sortable instance and remove all event listeners. */
  destroy () {
    this.unbindAll();
    if (this._drag) this._endDrag(true);
    this._cancelFrames();
    this._lastPointer = null;
    this._clearCache();
  }


  // ======================================== //
  // ============ Binding Helpers =========== //
  // ======================================== //

  bindAll () {
    // If a handle selector is configured, only start drags from the handle;
    // otherwise the whole item is the drag target.
    const pointerTarget = this.settings.handleSelector
      ? `${this.settings.itemSelector} ${this.settings.handleSelector}`
      : this.settings.itemSelector;
    this.$container.on("pointerdown.sortable", pointerTarget, (evt) => this.onPointerDown(evt));
  }

  unbindAll () {
    this.$container.off(".sortable");
  }

  /**
   * Refresh the sortable after DOM changes.
   *
   * Call this method when items are added, removed, or modified in the container
   * to ensure event listeners are properly bound.
   *
   * @example
   * // After adding new items to the container
   * container.append('<li data-id="new-item">New Item</li>');
   * sortable.refresh();
   */
  refresh () {
    this.unbindAll();
    this.bindAll();
    this._rebuildIndex();
  }


  // ======================================== //
  // =========== Pointer Handlers =========== //
  // ======================================== //

  onPointerDown (event) {
    // Primary button only (left mouse / first touch / pen contact)
    if (event.button !== 0) return;
    // Don't start a second drag while one is active
    if (this._drag) return;

    const nativeEvent = event.originalEvent || event;
    // captureEl is the element that received pointerdown (handle or item).
    // itemEl is always the sortable item (the li), found via closest() when a handle is in use.
    const captureEl = event.currentTarget;
    const itemEl = this.settings.handleSelector
      ? $(captureEl).closest(this.settings.itemSelector)[0]
      : captureEl;
    if (!itemEl) return;

    const rect = itemEl.getBoundingClientRect();

    // Prevent text selection and touch-scroll during drag
    event.preventDefault();

    this._drag = {
      pointerId: nativeEvent.pointerId,
      el: itemEl,
      captureEl,
      originNextSibling: itemEl.nextSibling,
      offsetX: nativeEvent.clientX - rect.left,
      offsetY: nativeEvent.clientY - rect.top,
    };
    this._lastPointer = { clientX: nativeEvent.clientX, clientY: nativeEvent.clientY };

    // Route all subsequent pointer events for this pointer ID to captureEl,
    // even when the pointer moves outside it. Releases automatically on pointerup/cancel.
    captureEl.setPointerCapture(nativeEvent.pointerId);

    // Bind move/end events on the captured element
    $(captureEl).on("pointermove.sortable-drag", (e) => this.onPointerMove(e));
    $(captureEl).on("pointerup.sortable-drag pointercancel.sortable-drag", (e) => this.onPointerUp(e));

    // Insert placeholder at original position, then hide original
    this._createPlaceholder(itemEl, rect);
    itemEl.parentNode.insertBefore(this.$placeholder[0], itemEl);
    $(itemEl).addClass("dragging");

    // Create ghost clone that follows the pointer
    this._createGhost(itemEl, rect, nativeEvent.clientX, nativeEvent.clientY);
  }

  onPointerMove (event) {
    if (!this._drag) return;
    const nativeEvent = event.originalEvent || event;
    if (nativeEvent.pointerId !== this._drag.pointerId) return;

    // Update ghost position immediately for smooth visual feedback
    if (this.$ghost) {
      this.$ghost.css({
        left: `${nativeEvent.clientX - this._drag.offsetX}px`,
        top: `${nativeEvent.clientY - this._drag.offsetY}px`,
      });
    }

    // Coalesce placeholder updates to at most one per animation frame,
    // always using the newest pointer position
    this._lastPointer = { clientX: nativeEvent.clientX, clientY: nativeEvent.clientY };
    if (!this._rafId) {
      this._rafId = requestAnimationFrame(() => {
        this._rafId = 0;
        if (this._drag && this._lastPointer)
          this._repositionPlaceholder(this._lastPointer.clientX, this._lastPointer.clientY);
      });
    }

    this._startAutoScroll();
  }

  onPointerUp (event) {
    if (!this._drag) return;
    const nativeEvent = event.originalEvent || event;
    if (nativeEvent.pointerId !== this._drag.pointerId) return;

    const cancelled = nativeEvent.type === "pointercancel";
    if (!cancelled) {
      // Resolve the drop slot from the release position right now; a pending
      // placeholder frame may not have run yet, and the commit must not use a stale slot
      this._lastPointer = { clientX: nativeEvent.clientX, clientY: nativeEvent.clientY };
      this._cancelFrames();
      this._repositionPlaceholder(this._lastPointer.clientX, this._lastPointer.clientY);
    }
    this._endDrag(cancelled);
  }


  // ======================================== //
  // ============= Drag Lifecycle =========== //
  // ======================================== //

  _endDrag (cancelled) {
    if (!this._drag) return;
    const { el, originNextSibling } = this._drag;

    // Cancel any pending placeholder / autoscroll frames
    this._cancelFrames();
    this._lastPointer = null;

    // Unbind per-element drag events (pointer capture auto-releases)
    $(this._drag.captureEl).off(".sortable-drag");

    // Remove ghost
    if (this.$ghost) {
      this.$ghost.remove();
      this.$ghost = null;
    }

    // Commit or revert the item's DOM position
    const ph = this.$placeholder && this.$placeholder[0];
    if (cancelled) {
      // Restore to original position before the drag started
      if (el.parentNode) el.parentNode.insertBefore(el, originNextSibling || null);
    } else if (ph && ph.parentNode) {
      ph.parentNode.insertBefore(el, ph);
    }
    $(el).removeClass("dragging");

    // Remove placeholder
    if (ph && ph.parentNode) ph.parentNode.removeChild(ph);
    this.$placeholder = null;

    this._drag = null;

    if (!cancelled) {
      this._rebuildIndex();
      if (this.settings.onReorder) this.settings.onReorder(this.order);
    }
  }


  _cancelFrames () {
    if (this._rafId) {
      cancelAnimationFrame(this._rafId);
      this._rafId = 0;
    }
    if (this._scrollRafId) {
      cancelAnimationFrame(this._scrollRafId);
      this._scrollRafId = 0;
    }
    this._scrollLastTs = 0;
  }


  // ======================================== //
  // ============ Edge Autoscroll =========== //
  // ======================================== //

  /**
   * Scroll speed for a pointer at the given viewport Y, in pixels per second.
   * Ramps linearly from 0 at the inner edge of the zone to the maximum at the viewport edge.
   * @param {number} clientY
   * @returns {number} Negative near the top, positive near the bottom, 0 elsewhere
   */
  _autoScrollSpeed (clientY) {
    const edge = Math.min(AUTOSCROLL_EDGE, window.innerHeight / 4);
    if (edge <= 0) return 0;

    // A captured mouse/pen pointer can report positions outside the viewport;
    // treat those as being at the edge so the speed never exceeds the maximum
    const y = Math.min(Math.max(clientY, 0), window.innerHeight);

    if (y < edge) return -AUTOSCROLL_MAX_SPEED * ((edge - y) / edge);
    const fromBottom = window.innerHeight - y;
    if (fromBottom < edge) return AUTOSCROLL_MAX_SPEED * ((edge - fromBottom) / edge);
    return 0;
  }

  _startAutoScroll () {
    if (!this._drag || !this._lastPointer || this._scrollRafId) return;
    if (this._autoScrollSpeed(this._lastPointer.clientY) === 0) return;

    this._scrollLastTs = 0;
    this._scrollRafId = requestAnimationFrame((ts) => this._autoScrollStep(ts));
  }

  _autoScrollStep (timestamp) {
    this._scrollRafId = 0;
    if (!this._drag || !this._lastPointer) return;

    const speed = this._autoScrollSpeed(this._lastPointer.clientY);
    if (speed === 0) {
      this._scrollLastTs = 0;
      return;
    }

    // First frame of a run has no previous timestamp; assume a typical frame
    const elapsed = this._scrollLastTs ? timestamp - this._scrollLastTs : 16;
    this._scrollLastTs = timestamp;
    const dt = Math.min(Math.max(elapsed, 0), AUTOSCROLL_MAX_FRAME) / 1000;

    const before = window.scrollY;
    window.scrollBy(0, speed * dt);
    if (window.scrollY === before) {
      // Top or bottom of the page; resumes on the next pointermove into the zone
      this._scrollLastTs = 0;
      return;
    }

    // The document moved under a pointer that may be stationary, so re-resolve
    // the drop slot without waiting for a pointermove
    this._repositionPlaceholder(this._lastPointer.clientX, this._lastPointer.clientY);
    this._scrollRafId = requestAnimationFrame((ts) => this._autoScrollStep(ts));
  }


  // ======================================== //
  // ========== Ghost & Placeholder ========= //
  // ======================================== //

  _createGhost (refEl, rect, clientX, clientY) {
    this.$ghost = $(refEl.cloneNode(true))
      .removeClass("dragging")
      .addClass("sortable-ghost")
      .css({
        position: "fixed",
        left: `${clientX - this._drag.offsetX}px`,
        top: `${clientY - this._drag.offsetY}px`,
        width: `${rect.width}px`,
        height: `${rect.height}px`,
        margin: "0",
        pointerEvents: "none",
        zIndex: "9999",
      })
      .appendTo(document.body);
  }

  /**
   * Builds the drop-position placeholder, sized to the dragged item's rendered box so it
   * takes the same footprint. Alignment within a grid track is left to CSS.
   * @param {Element} refEl The dragged item
   * @param {DOMRect} rect The dragged item's rendered box
   */
  _createPlaceholder (refEl, rect) {
    const tag = refEl?.tagName || "LI";
    this.$placeholder = $(`<${tag}>`)
      .addClass("sortable-placeholder")
      .attr("aria-hidden", "true")
      .css({
        width: `${rect.width}px`,
        height: `${rect.height}px`,
      });
  }

  _repositionPlaceholder (clientX, clientY) {
    const ph = this.$placeholder && this.$placeholder[0];
    if (!ph) return;

    // The ghost has pointer-events:none and the original has display:none,
    // so elementFromPoint sees straight through both to find real items.
    const hit = document.elementFromPoint(clientX, clientY);
    if (!hit) return;

    // Traverse up to find the nearest sortable item under the pointer
    const itemEl = $(hit).closest(this.settings.itemSelector, this.$container[0])[0];
    if (!itemEl || itemEl === ph || itemEl === this._drag.el) return;
    if (!this.$container[0].contains(itemEl)) return;

    // Slot-based targeting: an item's whole box is one destination, so the placeholder
    // takes over the slot that item currently shows in. Moving past it in DOM order does
    // exactly that, whether the item is in the same row or the grid wraps in between.
    // The hidden source takes no visual slot, so it doesn't affect the result.
    const itemFollowsPlaceholder = ph.compareDocumentPosition(itemEl) & Node.DOCUMENT_POSITION_FOLLOWING;
    if (itemFollowsPlaceholder) itemEl.parentNode.insertBefore(ph, itemEl.nextSibling);
    else itemEl.parentNode.insertBefore(ph, itemEl);
  }


  // ======================================== //
  // ============ Indexing Helpers ========== //
  // ======================================== //

  getElementById (id) { return this._elementCache.get(id) || null; }
  _elementCache = new Map();

  getIdByElement (el) {
    const val = el.dataset[this.settings.idDataKey];
    return val != null ? String(val) : null;
  }

  _rebuildIndex () {
    this._clearCache();

    const els = Array.from(this.$container.find(this.settings.itemSelector));
    const phNode = this.$placeholder ? this.$placeholder[0] : null;
    for (const el of els) {
      if (phNode && el === phNode) continue;
      const id = this.getIdByElement(el);
      if (!id) continue;

      this._elementCache.set(id, el);
      this._idCache.push(id);
    }
  }

  _clearCache () {
    this._elementCache.clear();
    this._idCache = [];
  }

  /** @returns {string[]} Array of item IDs in their current DOM order */
  get order () { return this._idCache.slice(); }
  _idCache = [];
}
