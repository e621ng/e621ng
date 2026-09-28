import Favorite from "@/models/Favorite";

/** Pixels of pointer movement required before a click becomes a drag. */
const ACTIVATION_THRESHOLD = 6;

/** Ghost size relative to the real thumbnail - kept within the requested 60-75% range. */
const GHOST_SCALE = 0.7;

/** Fixed pixel offset from the pointer, so the ghost never sits exactly under the cursor tip. */
const GHOST_OFFSET = 12;

interface DragState {
  pointerId: number;
  sourceEl: HTMLElement;
  captureEl: HTMLElement;
  postId: string;
  startX: number;
  startY: number;
  active: boolean; // true once the movement threshold has been crossed
  currentTarget: HTMLElement | null;
  rafId: number;
  pendingMove: { clientX: number; clientY: number } | null;
  ghost: HTMLElement | null;
}

// Elements whose pointer sequence ended in a completed (threshold-crossing) drag get a
// one-shot entry here, so the synthetic click the browser still fires after pointerup can
// be caught and suppressed - a movement threshold alone only stops a *drag* from starting
// on a small jitter, it does nothing about the click a real, completed drag still
// generates on release.
const suppressedClickTargets = new WeakSet<Element>();

/**
 * Favorites-specific click-and-drag: dragging a post thumbnail onto a folder or the Go
 * Up card moves that Favorite server-side. Mouse/pen only in v1 - touch users still get
 * full folder navigation via taps/links, just not drag-and-drop, to avoid risking a
 * touch-scroll regression.
 *
 * Not built on the generic Sortable utility: that one starts dragging immediately on
 * pointerdown (which would break normal click-to-open-post navigation) and its
 * placeholder-insertion heuristic is specific to reordering within one container, not
 * detecting a drop target among several distinct drop zones.
 */
export default class FavoriteFolderDrag {
  container: HTMLElement;
  drag: DragState | null = null;

  constructor (container: Element) {
    this.container = container as HTMLElement;
    this.container.addEventListener("pointerdown", this.onPointerDown);
    // Capture phase: must run before the thumbnail link's own click/navigation handling.
    this.container.addEventListener("click", this.onClickCapture, true);
    // Real post thumbnails (article.thumbnail[data-id] only - folder/Go-Up cards also
    // render as article.thumbnail for visual parity, but deliberately never carry
    // data-id, so the [data-id] qualifier is what actually excludes them here) must never
    // start the browser's own native HTML5 drag: once that takes over, it owns the
    // pointer's event stream and our Pointer Events-based threshold/activation logic
    // below stops receiving pointermove for the rest of the gesture - the practical
    // symptom being "dragging only works from the tiny footer," since the image (the
    // most naturally draggable element in the card) is exactly where native drag wins.
    // Unconditional (not gated on an active `this.drag`): native drag starts on the very
    // first qualifying pointer move, before our own threshold logic would ever get a
    // chance to run.
    this.container.addEventListener("dragstart", this.onNativeDragStart);
  }

  onNativeDragStart = (event: DragEvent): void => {
    const target = event.target as Element;
    if (target.closest("article.thumbnail[data-id]")) {
      event.preventDefault();
    }
  };

  onPointerDown = (event: PointerEvent): void => {
    if (event.button !== 0) return;
    if (event.pointerType === "touch") return; // mouse/pen only in v1
    if (this.drag) return;

    const target = event.target as Element;
    if (target.closest("[data-drop-target]")) return; // folder/Go-Up cards are never drag sources

    const sourceEl = target.closest<HTMLElement>("article.thumbnail[data-id]");
    if (!sourceEl || !this.container.contains(sourceEl)) return;

    const postId = sourceEl.dataset.id;
    if (!postId) return;

    this.drag = {
      pointerId: event.pointerId,
      sourceEl,
      captureEl: sourceEl,
      postId,
      startX: event.clientX,
      startY: event.clientY,
      active: false,
      currentTarget: null,
      rafId: 0,
      pendingMove: null,
      ghost: null,
    };

    // Pre-activation tracking is deliberately bound at the document level, not on
    // sourceEl: no pointer capture is held yet below the activation threshold, so the
    // pointer is free to move off sourceEl's bounds entirely (a fast flick, a small
    // thumbnail, etc.) before enough movement has accumulated to activate the drag.
    // Listeners attached directly to sourceEl would then simply never fire again -
    // whatever element the pointer ends up over receives the pointerup/pointercancel
    // instead - leaving `this.drag` stuck non-null forever and permanently blocking any
    // future drag (see onPointerDown's `if (this.drag) return`). Document-level
    // listeners always see the event regardless of what's currently under the pointer.
    document.addEventListener("pointermove", this.onPreActivationPointerMove);
    document.addEventListener("pointerup", this.onPreActivationPointerUp);
    document.addEventListener("pointercancel", this.onPreActivationPointerCancel);
  };

  onPreActivationPointerMove = (event: PointerEvent): void => {
    const drag = this.drag;
    if (!drag || drag.active || event.pointerId !== drag.pointerId) return;

    const distance = Math.hypot(event.clientX - drag.startX, event.clientY - drag.startY);
    if (distance < ACTIVATION_THRESHOLD) return;
    this.activate(event);
  };

  onPreActivationPointerUp = (event: PointerEvent): void => {
    const drag = this.drag;
    if (!drag || drag.active || event.pointerId !== drag.pointerId) return;
    // Below threshold: nothing was ever touched (no preventDefault, no capture), so the
    // browser's normal click/navigation for this pointer sequence proceeds untouched.
    this.removePreActivationListeners();
    this.drag = null;
  };

  onPreActivationPointerCancel = (event: PointerEvent): void => {
    const drag = this.drag;
    if (!drag || drag.active || event.pointerId !== drag.pointerId) return;
    this.removePreActivationListeners();
    this.drag = null;
  };

  removePreActivationListeners (): void {
    document.removeEventListener("pointermove", this.onPreActivationPointerMove);
    document.removeEventListener("pointerup", this.onPreActivationPointerUp);
    document.removeEventListener("pointercancel", this.onPreActivationPointerCancel);
  }

  activate (event: PointerEvent): void {
    const drag = this.drag;
    if (!drag) return;

    this.removePreActivationListeners();

    drag.active = true;
    event.preventDefault(); // suppresses text-selection/native drag now that a real drag has started
    drag.captureEl.setPointerCapture(drag.pointerId);
    // Dims the source in place - it must never leave its grid slot or be removed from the
    // DOM here (see the favorite-dragging rule in favorites.scss): doing so would reflow
    // every later thumbnail into its spot before the drop result is even known, and jump
    // them all back again on a cancelled/failed drag. The card only ever actually leaves
    // once commitMove's move request has succeeded.
    drag.sourceEl.classList.add("favorite-dragging");
    drag.ghost = this.createGhost(drag, event.clientX, event.clientY);

    // Post-activation tracking is scoped to captureEl instead of the document: pointer
    // capture guarantees every subsequent event for this pointer targets captureEl
    // regardless of what's visually under the pointer, so element-scoped listeners are
    // both correct and sufficient from here on.
    drag.captureEl.addEventListener("pointermove", this.onPointerMove);
    drag.captureEl.addEventListener("pointerup", this.onPointerUp);
    drag.captureEl.addEventListener("pointercancel", this.onPointerCancel);
  }

  createGhost (drag: DragState, clientX: number, clientY: number): HTMLElement {
    const rect = drag.sourceEl.getBoundingClientRect();
    const ghost = drag.sourceEl.cloneNode(true) as HTMLElement;
    ghost.classList.remove("favorite-dragging");
    ghost.classList.add("favorite-drag-ghost");
    this.sanitizeGhost(ghost);
    Object.assign(ghost.style, {
      position: "fixed",
      left: `${clientX + GHOST_OFFSET}px`,
      top: `${clientY + GHOST_OFFSET}px`,
      width: `${rect.width * GHOST_SCALE}px`,
      height: `${rect.height * GHOST_SCALE}px`,
      margin: "0",
      pointerEvents: "none",
      zIndex: "9999",
    });
    document.body.appendChild(ghost);
    return ghost;
  }

  // Strips every id and data-* attribute (data-id, data-flags, data-tags, ...) from the
  // clone and all of its descendants, so the ghost - while it briefly sits in document.body
  // during the gesture - can never match article.thumbnail[data-id] (this module's own
  // drag-source selector, and post_mode_menu.js's bulk-select selectors) or collide with
  // a real element id, and so can never be mistaken for a real, interactive post
  // thumbnail or drop source. pointer-events: none (set by the caller) already keeps it
  // from receiving input directly; this guards against selector-based lookups instead.
  sanitizeGhost (ghost: HTMLElement): void {
    const nodes = [ghost, ...Array.from(ghost.querySelectorAll<HTMLElement>("*"))];
    for (const node of nodes) {
      node.removeAttribute("id");
      for (const attr of Array.from(node.attributes)) {
        if (attr.name.startsWith("data-")) node.removeAttribute(attr.name);
      }
    }
  }

  onPointerMove = (event: PointerEvent): void => {
    const drag = this.drag;
    if (!drag || event.pointerId !== drag.pointerId) return;

    if (drag.ghost) {
      drag.ghost.style.left = `${event.clientX + GHOST_OFFSET}px`;
      drag.ghost.style.top = `${event.clientY + GHOST_OFFSET}px`;
    }

    drag.pendingMove = { clientX: event.clientX, clientY: event.clientY };
    if (!drag.rafId) {
      drag.rafId = requestAnimationFrame(() => {
        drag.rafId = 0;
        const move = drag.pendingMove;
        drag.pendingMove = null;
        if (move) this.updateHoverTarget(move.clientX, move.clientY);
      });
    }
  };

  updateHoverTarget (clientX: number, clientY: number): void {
    const drag = this.drag;
    if (!drag) return;

    const hit = document.elementFromPoint(clientX, clientY);
    const hovered = hit ? hit.closest<HTMLElement>("[data-drop-target]") : null;
    const resolved = hovered && this.container.contains(hovered) ? hovered : null;

    if (resolved === drag.currentTarget) return;
    if (drag.currentTarget) drag.currentTarget.classList.remove("drag-hover");
    if (resolved) resolved.classList.add("drag-hover");
    drag.currentTarget = resolved;
  }

  onPointerUp = (event: PointerEvent): void => {
    const drag = this.drag;
    if (!drag || event.pointerId !== drag.pointerId) return;
    // Resolve the drop target synchronously from THIS event's own release coordinates,
    // rather than trusting whatever the RAF-throttled updateHoverTarget last computed:
    // that queued frame may not have run yet (a fast flick can enter a valid target and
    // release before the browser's next paint), which would otherwise either drop a
    // valid release as a no-op (currentTarget still null) or commit against a stale
    // previous target instead of where the pointer actually is now. endDrag still cancels
    // any pending RAF below, so that now-redundant frame never fires after this.
    this.updateHoverTarget(event.clientX, event.clientY);
    this.endDrag(false);
  };

  onPointerCancel = (event: PointerEvent): void => {
    const drag = this.drag;
    if (!drag || event.pointerId !== drag.pointerId) return;
    this.endDrag(true);
  };

  endDrag (cancelled: boolean): void {
    const drag = this.drag;
    if (!drag) return;

    drag.captureEl.removeEventListener("pointermove", this.onPointerMove);
    drag.captureEl.removeEventListener("pointerup", this.onPointerUp);
    drag.captureEl.removeEventListener("pointercancel", this.onPointerCancel);
    if (drag.rafId) cancelAnimationFrame(drag.rafId);

    if (drag.currentTarget) drag.currentTarget.classList.remove("drag-hover");
    if (drag.ghost) drag.ghost.remove();
    // Un-dims the source. It was never removed or repositioned, so there is nothing else
    // to restore here regardless of how the gesture ended - see commitMove, which removes
    // it separately, afterward, only once a move actually succeeds.
    drag.sourceEl.classList.remove("favorite-dragging");

    // A completed drag still generates a synthetic click on release, valid drop or not -
    // suppress it so a real drag never also navigates to the post.
    if (!cancelled) suppressedClickTargets.add(drag.sourceEl);

    const dropTarget = cancelled ? null : drag.currentTarget;
    this.drag = null;

    if (!dropTarget) return; // cancelled, or released over empty space: no-op, source stays put untouched
    this.commitMove(drag, dropTarget);
  }

  commitMove (drag: DragState, dropTarget: HTMLElement): void {
    const destinationFolderId = dropTarget.dataset.dropTarget === "go-up"
      ? dropTarget.dataset.destinationFolderId || null
      : dropTarget.dataset.folderId || null;

    // No optimistic removal, and so no rollback path either: the source card was never
    // touched above, so a failed or rejected request simply leaves it exactly where it
    // already is - there is nothing to reinsert.
    Favorite.move(Number(drag.postId), destinationFolderId ? Number(destinationFolderId) : null)
      .then(() => {
        // Every successful drop, from any drop target this component recognizes,
        // necessarily moves the favorite out of whatever's currently displayed: at root
        // (now "unfiled favorites") it gains a membership row; inside a folder it either
        // moves to a different folder or loses its membership row entirely (Go Up to
        // root). Either way, the post displayed at this position is no longer a member of
        // the collection being viewed, so the source always comes out once the move is
        // confirmed - never before.
        drag.sourceEl.remove();
      })
      .catch(() => {
        // Favorite.move already dispatched the danbooru:error toast for this failure.
      });
  }

  onClickCapture = (event: MouseEvent): void => {
    const target = event.target as Element;
    const sourceEl = target.closest("article.thumbnail[data-id]");
    if (sourceEl && suppressedClickTargets.has(sourceEl)) {
      suppressedClickTargets.delete(sourceEl);
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  };
}

$(() => {
  const container = document.querySelector("#c-favorites .posts-container");
  // No-op outside folder-scoped mode: without any rendered folder/Go-Up cards there is
  // nowhere to drop a post, so skip attaching listeners entirely rather than tracking
  // drags that could never resolve to a target.
  if (!container || !container.querySelector("[data-drop-target]")) return;
  new FavoriteFolderDrag(container);
});
