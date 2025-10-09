/**
 * HTML5 drag-and-drop sortable utility for grid layouts.
 *
 * Provides intuitive drag-and-drop reordering with visual feedback via placeholders.
 * Uses CSS Grid/Flexbox compatible positioning and CSS-based styling.
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
      idDataKey: options.idDataKey || "id",
      onReorder: typeof options.onReorder === "function" ? options.onReorder : null,
    };

    this.state = {
      draggingId: null,
      draggingEl: null,
      lastTarget: null,
      lastBefore: null,
    };

    // requestAnimationFrame coalescing for dragover
    this._dragOverRafId = 0;
    this._pendingOver = null;

    this.$container.find(this.settings.itemSelector).attr("draggable", "true");
    this._rebuildIndex();
    this.bindAll();
  }

  /** Clean up the sortable instance and remove all event listeners. */
  destroy () {
    this.unbindAll();
    this.$container.find(this.settings.itemSelector).removeAttr("draggable");
    if (this.$placeholder) this.destroyPlaceholder();

    if (this._dragOverRafId) {
      cancelAnimationFrame(this._dragOverRafId);
      this._dragOverRafId = 0;
    }
    this._pendingOver = null;

    this._clearCache();
  }


  // ======================================== //
  // ====== Dragged Item Event Handlers ===== //
  // ======================================== //

  bindAll () {
    this.$container.on("dragstart.sortable", this.settings.itemSelector, (evt) => this.onItemDragStart(evt));
    this.$container.on("dragend.sortable", this.settings.itemSelector, (evt) => this.onItemDragEnd(evt));
    this.$container.on("dragover.sortable", this.settings.itemSelector, (evt) => this.onItemDragOver(evt));
  }

  unbindAll () {
    this.$container.off("dragstart.sortable dragend.sortable dragover.sortable");
  }

  /**
   * Refresh the sortable after DOM changes.
   *
   * Call this method when items are added, removed, or modified in the container
   * to ensure new items become draggable and event listeners are properly bound.
   *
   * @example
   * // After adding new items to the container
   * container.append('<li data-id="new-item">New Item</li>');
   * sortable.refresh();
   */
  refresh () {
    this.unbindAll();

    // Apply draggable attribute to new items
    this.$container.find(this.settings.itemSelector).attr("draggable", "true");
    this.bindAll();
    this._rebuildIndex();
  }

  onItemDragStart (event) {
    const el = event.currentTarget;
    const $el = $(el);

    this.state = {
      draggingId: this.getIdByElement(el),
      draggingEl: el,
      lastTarget: null,
      lastBefore: null,
    };

    const nativeEvent = event.originalEvent || event;
    if (nativeEvent.dataTransfer) {
      nativeEvent.dataTransfer.effectAllowed = "move";
      nativeEvent.dataTransfer.setData("text/plain", this.state.draggingId || "");
    }

    // Replace the dragged element with a placeholder to avoid layout shifts
    this.showPlaceholder(el);
    const ph = this.$placeholder && this.$placeholder[0];
    if (ph && el.parentNode) el.parentNode.insertBefore(ph, el);
    $el.addClass("dragging");
  }

  onItemDragEnd (event) {
    const dragged = this.state.draggingEl || event.currentTarget;
    let committed = false;

    // If the placeholder is still attached, the browser likely didn't fire drop on it.
    // Act as if the item was dropped on the placeholder.
    const ph = this.$placeholder && this.$placeholder[0];
    if (ph && ph.parentNode && dragged && dragged !== ph) {
      ph.parentNode.insertBefore(dragged, ph);
      committed = true;
    }
    this.hidePlaceholder();

    if (committed) {
      if (dragged && dragged.classList) dragged.classList.remove("dragging");
      this._rebuildIndex();
      if (this.settings.onReorder)
        this.settings.onReorder(this.order);
    } else $(event.currentTarget).removeClass("dragging");

    this.state = {
      draggingId: null,
      draggingEl: null,
      lastTarget: null,
      lastBefore: null,
    };
  }

  onItemDragOver (event) {
    event.preventDefault();
    const nativeEvent = event.originalEvent || event;
    if (nativeEvent.dataTransfer) nativeEvent.dataTransfer.dropEffect = "move";

    // Not dragging anything, ignore
    if (!this.state.draggingId) return;

    // Process dragover events at most once per frame
    this._pendingOver = {
      el: event.currentTarget,
      clientX: nativeEvent.clientX,
    };

    if (!this._dragOverRafId) {
      this._dragOverRafId = requestAnimationFrame(() => {
        this._dragOverRafId = 0;
        const pending = this._pendingOver;
        this._pendingOver = null;
        if (!pending) return;
        this._processDragOver(pending.el, pending.clientX);
      });
    }
  }

  _processDragOver (el, clientX) {
    if (!this.state.draggingId) return;

    const rect = el.getBoundingClientRect();
    const before = (clientX - rect.left) < rect.width / 2;

    if (this.state.lastTarget === el && this.state.lastBefore === before)
      return; // Already positioned here

    // Ensure placeholder exists and matches target size
    if (!this.$placeholder) {
      this.createPlaceholder(el);
      this.sizePlaceholder(el, rect);
      this.$placeholder.show();
    } else if (this.state.lastTarget !== el) {
      this.sizePlaceholder(el, rect);
      this.$placeholder.show();
    }

    // Position placeholder around target
    const ph = this.$placeholder[0];
    if (el.parentNode) {
      if (before) {
        if (ph.nextSibling !== el) el.parentNode.insertBefore(ph, el);
      } else {
        if (el.nextSibling !== ph) el.parentNode.insertBefore(ph, el.nextSibling);
      }
    }

    this.state.lastTarget = el;
    this.state.lastBefore = before;
  }

  // ======================================== //
  // ========== Placeholder Methods ========= //
  // ======================================== //

  createPlaceholder (refEl) {
    if (this.$placeholder) return;

    const tag = refEl?.tagName || "DIV";

    this.$placeholder = $(`<${tag}>`)
      .addClass("sortable-placeholder")
      .attr({
        "aria-hidden": "true",
        "draggable": "false",
      })
      .hide();

    // Bind placeholder events once
    this.bindPlaceholderEvents();
  }

  showPlaceholder (refEl) {
    if (!refEl) return null;

    if (!this.$placeholder) this.createPlaceholder(refEl);
    this.sizePlaceholder(refEl);
    this.$placeholder.show();

    return this.$placeholder;
  }

  hidePlaceholder () {
    if (!this.$placeholder) return;
    this.$placeholder.detach().hide();
  }

  destroyPlaceholder () {
    if (!this.$placeholder) return;

    this.unbindPlaceholderEvents();
    this.$placeholder.remove();
    this.$placeholder = null;
  }

  sizePlaceholder (refEl, refRect) {
    if (!refEl || !this.$placeholder) return;

    // Match the size of the reference element
    const rect = refRect || refEl.getBoundingClientRect();
    this.$placeholder.css({ width: `${rect.width}px`, height: `${rect.height}px` });
  }

  bindPlaceholderEvents () {
    if (!this.$placeholder) return;

    this.$placeholder.on("dragover.sortable", (event) => {
      event.preventDefault();
      const nativeEvent = event.originalEvent || event;
      if (nativeEvent.dataTransfer)
        nativeEvent.dataTransfer.dropEffect = "move";
    });

    this.$placeholder.on("drop.sortable", (event) => {
      event.preventDefault();
      const nativeEvent = event.originalEvent || event;

      const draggedId = this.state.draggingId || (nativeEvent.dataTransfer ? nativeEvent.dataTransfer.getData("text/plain") : "");
      if (!draggedId) return;
      const dragged = this.state.draggingEl || this._elementCache.get(draggedId);
      if (!dragged) return;

      // Move dragged element before placeholder using native DOM, then drop CSS class
      const ph = this.$placeholder && this.$placeholder[0];
      if (ph && ph.parentNode) ph.parentNode.insertBefore(dragged, ph);
      dragged.classList.remove("dragging");

      this._rebuildIndex();
      this.hidePlaceholder();

      if (this.settings.onReorder)
        this.settings.onReorder(this.order);
    });
  }

  unbindPlaceholderEvents () {
    if (!this.$placeholder) return;
    this.$placeholder.off(".sortable");
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
