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
 * const currentOrder = sortable.getOrderedIds();
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

    this.$container.find(this.settings.itemSelector).attr("draggable", "true");
    this.bindAll();
  }

  getItems () {
    const nodes = Array.from(this.$container.find(this.settings.itemSelector));
    return nodes.filter((el) => !this.$placeholder || el !== this.$placeholder[0]);
  }

  getId (el) {
    const val = el.dataset[this.settings.idDataKey];
    return val != null ? String(val) : null;
  }

  /** Clean up the sortable instance and remove all event listeners. */
  destroy () {
    this.unbindAll();
    this.$container.find(this.settings.itemSelector).removeAttr("draggable");
    if (this.$placeholder) this.destroyPlaceholder();
  }

  /**
   * Get the current order of sortable items as an array of IDs.
   *
   * @returns {string[]} Array of item IDs in their current DOM order
   * @example
   * const order = sortable.getOrderedIds();
   * // Returns: ["post-123", "post-456", "post-789"]
   */
  getOrderedIds () {
    return this.getItems()
      .map((el) => this.getId(el))
      .filter((v) => v != null && v !== "");
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
  }

  onItemDragStart (event) {
    const el = event.currentTarget;
    const $el = $(el);

    this.state = {
      draggingId: this.getId(el),
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
    const $ph = this.showPlaceholder(el);
    $ph.insertBefore($el);
    $el.addClass("dragging");
  }

  onItemDragEnd (event) {
    this.state = {
      draggingId: null,
      draggingEl: null,
      lastTarget: null,
      lastBefore: null,
    };

    this.hidePlaceholder();
    $(event.currentTarget).removeClass("dragging");
  }

  onItemDragOver (event) {
    event.preventDefault();
    const el = event.currentTarget;

    const nativeEvent = event.originalEvent || event;
    if (nativeEvent.dataTransfer) nativeEvent.dataTransfer.dropEffect = "move";

    // Not dragging anything, ignore
    if (!this.state.draggingId) return;

    const rect = el.getBoundingClientRect();
    const before = (nativeEvent.clientX - rect.left) < rect.width / 2;

    if (this.state.lastTarget === el && this.state.lastBefore === before)
      return; // Already positioned here

    // Show placeholder on first use, or resize if target changed
    if (!this.$placeholder) this.showPlaceholder(el);
    else if (this.state.lastTarget !== el) {
      this.sizePlaceholder(el);
      this.$placeholder.show();
    }

    // Position placeholder around target
    const ph = this.$placeholder[0];
    if (before) {
      if (ph.nextSibling !== el) this.$placeholder.insertBefore(el);
    } else {
      if (el.nextSibling !== ph) this.$placeholder.insertAfter(el);
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
      .addClass("sortable-drop-target")
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

  sizePlaceholder (refEl) {
    if (!refEl || !this.$placeholder) return;

    // Match the size of the reference element
    const rect = refEl.getBoundingClientRect();
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
      const dragged = this.state.draggingEl || this.getItems().find((n) => this.getId(n) === draggedId);
      if (!dragged) return;

      $(dragged).insertBefore(this.$placeholder).removeClass("dragging");
      this.hidePlaceholder();

      if (this.settings.onReorder)
        this.settings.onReorder(this.getOrderedIds());
    });
  }

  unbindPlaceholderEvents () {
    if (!this.$placeholder) return;
    this.$placeholder.off(".sortable");
  }
}
