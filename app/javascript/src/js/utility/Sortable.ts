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
export interface SortableOptions {
  /** CSS selector for sortable items within the container. Defaults to `"li"`. */
  itemSelector?: string;
  /** CSS selector for the drag handle within each item; if unset, the entire item is the handle. */
  handleSelector?: string | null;
  /** Data attribute key for item IDs (e.g. `"postId"` for `data-post-id`). Defaults to `"id"`. */
  idDataKey?: string;
  /** Fired after a successful drop with the item IDs in their new order. */
  onReorder?: SortableReorderCallback;
}

export type SortableReorderCallback = (ids: string[]) => void;

/** Options with their defaults applied. */
interface SortableSettings {
  itemSelector: string;
  handleSelector: string | null;
  idDataKey: string;
  onReorder: SortableReorderCallback | null;
}

interface DragState {
  pointerId: number;
  /** The sortable item being dragged */
  el: HTMLElement;
  /** The element that received pointerdown (the handle, or the item itself) and holds pointer capture */
  captureEl: HTMLElement;
  /** Where to put the item back if the drag is cancelled */
  originNextSibling: ChildNode | null;
  /** Pointer offset within the item, so the ghost keeps the grab point under the pointer */
  offsetX: number;
  offsetY: number;
}

interface PointerPosition {
  clientX: number;
  clientY: number;
}

/** jQuery pointer events, bound on the container (delegated) or on the capture element. */
type SortablePointerEvent = JQuery.TriggeredEvent<HTMLElement, undefined, HTMLElement, HTMLElement>;

/** The native pointer event behind a jQuery event; plain dispatched events have no `originalEvent`. */
function nativePointer (event: SortablePointerEvent): PointerEvent {
  return (event.originalEvent || event) as unknown as PointerEvent;
}

export default class Sortable {

  private $container: JQuery<HTMLElement>;
  private settings: SortableSettings;

  /** Active drag state; null when idle */
  private _drag: DragState | null;

  /** requestAnimationFrame coalescing for placeholder repositioning */
  private _rafId: number;
  private _pendingMove: PointerPosition | null;

  private $ghost: JQuery<HTMLElement> | null = null;
  private $placeholder: JQuery<HTMLElement> | null = null;

  /**
   * Create a new Sortable instance.
   *
   * @param container Container element holding sortable items
   * @param options Configuration options
   */
  constructor (container: Element | JQuery<HTMLElement>, options: SortableOptions = {}) {
    if (!container) throw new Error("Sortable: container is required");
    this.$container = container instanceof Element
      ? $(container) as JQuery<HTMLElement>
      : $(container.toArray());

    this.settings = {
      itemSelector: options.itemSelector || "li",
      handleSelector: options.handleSelector || null,
      idDataKey: options.idDataKey || "id",
      onReorder: typeof options.onReorder === "function" ? options.onReorder : null,
    };

    this._drag = null;
    this._rafId = 0;
    this._pendingMove = null;

    this._rebuildIndex();
    this.bindAll();
  }

  /** Clean up the sortable instance and remove all event listeners. */
  public destroy (): void {
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

  public bindAll (): void {
    // If a handle selector is configured, only start drags from the handle;
    // otherwise the whole item is the drag target.
    const pointerTarget = this.settings.handleSelector
      ? `${this.settings.itemSelector} ${this.settings.handleSelector}`
      : this.settings.itemSelector;
    this.$container.on("pointerdown.sortable", pointerTarget, (evt: SortablePointerEvent) => this.onPointerDown(evt));
  }

  public unbindAll (): void {
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
  public refresh (): void {
    this.unbindAll();
    this.bindAll();
    this._rebuildIndex();
  }


  // ======================================== //
  // =========== Pointer Handlers =========== //
  // ======================================== //

  public onPointerDown (event: SortablePointerEvent): void {
    // Primary button only (left mouse / first touch / pen contact)
    if (event.button !== 0) return;
    // Don't start a second drag while one is active
    if (this._drag) return;

    const nativeEvent = nativePointer(event);
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
    $(captureEl).on("pointermove.sortable-drag", (e: SortablePointerEvent) => this.onPointerMove(e));
    $(captureEl).on("pointerup.sortable-drag pointercancel.sortable-drag", (e: SortablePointerEvent) => this.onPointerUp(e));

    // Insert placeholder at original position, then hide original
    this._createPlaceholder(itemEl);
    itemEl.parentNode.insertBefore(this.$placeholder[0], itemEl);
    $(itemEl).addClass("dragging");

    // Create ghost clone that follows the pointer
    this._createGhost(itemEl, rect, nativeEvent.clientX, nativeEvent.clientY);
  }

  public onPointerMove (event: SortablePointerEvent): void {
    if (!this._drag) return;
    const nativeEvent = nativePointer(event);
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

  public onPointerUp (event: SortablePointerEvent): void {
    if (!this._drag) return;
    const nativeEvent = nativePointer(event);
    if (nativeEvent.pointerId !== this._drag.pointerId) return;

    const cancelled = nativeEvent.type === "pointercancel";
    this._endDrag(cancelled);
  }


  // ======================================== //
  // ============= Drag Lifecycle =========== //
  // ======================================== //

  private _endDrag (cancelled: boolean): void {
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

  private _createGhost (refEl: HTMLElement, rect: DOMRect, clientX: number, clientY: number): void {
    this.$ghost = $(refEl.cloneNode(true) as HTMLElement)
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

  private _createPlaceholder (refEl: HTMLElement): void {
    const tag = refEl?.tagName || "LI";
    this.$placeholder = $<HTMLElement>(`<${tag}>`)
      .addClass("sortable-placeholder")
      .attr("aria-hidden", "true");
  }

  private _repositionPlaceholder (clientX: number, clientY: number): void {
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

  public getElementById (id: string): HTMLElement | null { return this._elementCache.get(id) || null; }
  private _elementCache = new Map<string, HTMLElement>();

  public getIdByElement (el: HTMLElement): string | null {
    const val = el.dataset[this.settings.idDataKey];
    return val != null ? String(val) : null;
  }

  private _rebuildIndex (): void {
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

  private _clearCache (): void {
    this._elementCache.clear();
    this._idCache = [];
  }

  /** Item IDs in their current DOM order */
  public get order (): string[] { return this._idCache.slice(); }
  private _idCache: string[] = [];
}
