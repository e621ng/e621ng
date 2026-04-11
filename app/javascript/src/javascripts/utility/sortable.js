/**
 * Pointer-events-based sortable utility for grid layouts.
 *
 * Works on desktop (mouse) and mobile (touch/stylus) via the unified
 * Pointer Events API — no HTML5 drag-and-drop involved.
 *
 * A ghost clone follows the pointer while dragging; a placeholder shows
 * the pending drop position. Pointer capture routes all move/up events
 * to the grabbed element so no document-level listeners are needed.
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
export default class Sortable {

  /**
   * Create a new Sortable instance.
   *
   * @param {Element|jQuery} container Container element holding sortable items
   * @param {Object} [options={}] Configuration options
   * @param {string} [options.itemSelector="li"] CSS selector for sortable items within container
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
    this._pendingMove = null;

    this._rebuildIndex();
    this.bindAll();
  }

  /** Clean up the sortable instance and remove all event listeners. */
  destroy () {
    this.unbindAll();
    if (this._drag) this._endDrag(true);
    if (this._rafId) {
      cancelAnimationFrame(this._rafId);
      this._rafId = 0;
    }
    this._pendingMove = null;
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

    // Route all subsequent pointer events for this pointer ID to captureEl,
    // even when the pointer moves outside it. Releases automatically on pointerup/cancel.
    captureEl.setPointerCapture(nativeEvent.pointerId);

    // Bind move/end events on the captured element
    $(captureEl).on("pointermove.sortable-drag", (e) => this.onPointerMove(e));
    $(captureEl).on("pointerup.sortable-drag pointercancel.sortable-drag", (e) => this.onPointerUp(e));

    // Insert placeholder at original position, then hide original
    this._createPlaceholder(itemEl);
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

    // Coalesce placeholder updates to at most one per animation frame
    this._pendingMove = { clientX: nativeEvent.clientX, clientY: nativeEvent.clientY };
    if (!this._rafId) {
      this._rafId = requestAnimationFrame(() => {
        this._rafId = 0;
        const m = this._pendingMove;
        this._pendingMove = null;
        if (m) this._repositionPlaceholder(m.clientX, m.clientY);
      });
    }
  }

  onPointerUp (event) {
    if (!this._drag) return;
    const nativeEvent = event.originalEvent || event;
    if (nativeEvent.pointerId !== this._drag.pointerId) return;

    const cancelled = nativeEvent.type === "pointercancel";
    this._endDrag(cancelled);
  }


  // ======================================== //
  // ============= Drag Lifecycle =========== //
  // ======================================== //

  _endDrag (cancelled) {
    if (!this._drag) return;
    const { el, originNextSibling } = this._drag;

    // Cancel any pending placeholder RAF
    if (this._rafId) {
      cancelAnimationFrame(this._rafId);
      this._rafId = 0;
    }
    this._pendingMove = null;

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


  // ======================================== //
  // ========== Ghost & Placeholder ========= //
  // ======================================== //

  _createGhost (refEl, rect, clientX, clientY) {
    this.$ghost = $(refEl.cloneNode(true))
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

  _createPlaceholder (refEl) {
    const tag = refEl?.tagName || "LI";
    this.$placeholder = $(`<${tag}>`)
      .addClass("sortable-placeholder")
      .attr("aria-hidden", "true");
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

    const rect = itemEl.getBoundingClientRect();
    const before = (clientX - rect.left) < rect.width / 2;

    if (before) {
      if (ph.nextSibling !== itemEl) itemEl.parentNode.insertBefore(ph, itemEl);
    } else {
      if (itemEl.nextSibling !== ph) itemEl.parentNode.insertBefore(ph, itemEl.nextSibling);
    }
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
