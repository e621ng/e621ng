import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import { Point } from "@/pages/posts/show/notes/Types";

export interface DragGestureCallbacks {
  /** The gesture became active: immediately for a mouse, after the long press for touch */
  onStart (point: Point): void;
  /** Pointer moved while the gesture is active. Throttled to animation frames. */
  onMove (point: Point): void;
  /** Pointer released while the gesture is active */
  onEnd (point: Point): void;
  /** Gesture was aborted: pointer cancelled, capture lost, `note:abort`, or a mouse context menu */
  onCancel (): void;
  /** Touch released before the long press fired, without moving past the slop */
  onTap? (point: Point): void;
}

export interface DragGestureOptions {
  /** Require touch and pen pointers to hold still before the gesture starts. Mouse always starts immediately. */
  longPress: boolean;
}

/** Subset of the pointer event fields the gesture reads, so that specs can trigger plain `$.Event`s */
interface PointerLike {
  pageX?: number;
  pageY?: number;
  button?: number;
  pointerId?: number;
  pointerType?: string;
  isPrimary?: boolean;
  originalEvent?: Partial<PointerEvent>;
}

/**
 * Pointer plumbing shared by the drawing, moving, and resizing interactions.
 * Handles pointer capture, the touch long-press delay, multi-touch filtering,
 * animation-frame throttling, and scroll suppression while a gesture is active.
 * Move / up / cancel listeners are bound on the note container: captured events
 * are retargeted to the capturing element and still bubble up to it.
 */
export default class DragGesture {

  /** How long a touch has to hold still before a long-press gesture starts */
  public static readonly LONG_PRESS_MS = 400;
  /** Movement past this distance (CSS px) during the hold cancels the long press and lets the page scroll */
  public static readonly SLOP_PX = 10;

  private static nextID = 0;
  private static current: DragGesture | null = null;
  private static touchPreventerBound = false;

  private readonly id = DragGesture.nextID++;
  private readonly callbacks: DragGestureCallbacks;
  private readonly longPress: boolean;

  private state: "idle" | "pending" | "active" = "idle";
  private pointerId: number | null = null;
  private _pointerType: string | null = null;
  private start: Point = { x: 0, y: 0 };
  private latest: Point = { x: 0, y: 0 };
  private timer: ReturnType<typeof setTimeout> | null = null;
  private frame: number | null = null;

  public constructor (callbacks: DragGestureCallbacks, { longPress }: DragGestureOptions) {
    this.callbacks = callbacks;
    this.longPress = longPress;
    DragGesture.bindTouchPreventer();
  }

  public get active (): boolean { return this.state === "active"; }
  public get pending (): boolean { return this.state === "pending"; }
  public get pointerType (): string | null { return this._pointerType; }


  /* ============================== */
  /* ===== Scroll suppression ===== */
  /* ============================== */

  /**
   * Touch scrolling is only blocked while a gesture is active, so that a plain
   * finger drag in editing mode still scrolls the page. This must be a native,
   * non-passive listener: jQuery cannot cancel touchmove reliably.
   */
  private static bindTouchPreventer (): void {
    if (this.touchPreventerBound) return;
    this.touchPreventerBound = true;

    NoteUtilities.container[0].addEventListener("touchmove", (event) => {
      if (!DragGesture.current?.active) return;
      if (event.cancelable) event.preventDefault();
    }, { passive: false });
  }


  /* ============================== */
  /* ========= Lifecycle ========== */
  /* ============================== */

  /**
   * Starts tracking a pointer from its `pointerdown` event.
   * Returns false when the event should be left alone.
   */
  public begin (event: JQuery.TriggeredEvent): boolean {
    if (this.state !== "idle" || DragGesture.current) return false;

    const pointer = DragGesture.read(event);
    if (pointer.button !== 0) return false;
    if (pointer.isPrimary === false) return false;

    this.pointerId = pointer.pointerId;
    this._pointerType = pointer.pointerType;
    this.start = this.toContainerPoint(pointer);
    this.latest = this.start;
    DragGesture.current = this;

    const container = NoteUtilities.container;
    const element = container[0];
    if (typeof element.setPointerCapture === "function") {
      try { element.setPointerCapture(this.pointerId); } catch { /* pointer already gone */ }
    }

    container
      .on(this.ns("pointermove"), (e) => this.onPointerMove(e))
      .on(this.ns("pointerup"), (e) => this.onPointerUp(e))
      .on(this.ns("pointercancel lostpointercapture"), (e) => this.onPointerCancel(e))
      .on(this.ns("contextmenu"), () => this.onContextMenu());

    if (this.longPress && this._pointerType !== "mouse") {
      this.state = "pending";
      this.timer = setTimeout(() => this.activate(), DragGesture.LONG_PRESS_MS);
    } else {
      this.activate();
    }

    return true;
  }

  /** Cancels the gesture from the outside, such as on `note:abort` */
  public abort (): void {
    if (this.state === "idle") return;
    const wasActive = this.state === "active";
    this.finish();
    if (wasActive) this.callbacks.onCancel();
  }

  private activate (): void {
    this.timer = null;
    this.state = "active";
    if (this._pointerType !== "mouse" && typeof navigator.vibrate === "function") navigator.vibrate(20);
    this.callbacks.onStart(this.start);
  }

  private finish (): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = null;

    NoteUtilities.container.off(`.e6.note-drag-${this.id}`);
    this.state = "idle";
    this.pointerId = null;
    if (DragGesture.current === this) DragGesture.current = null;
  }


  /* ============================== */
  /* ======= Event handlers ======= */
  /* ============================== */

  private onPointerMove (event: JQuery.TriggeredEvent): void {
    const pointer = DragGesture.read(event);
    if (pointer.pointerId !== this.pointerId) return;
    this.latest = this.toContainerPoint(pointer);

    if (this.state === "pending") {
      // Moved too far during the hold: this is a scroll, not a long press
      if (Math.hypot(this.latest.x - this.start.x, this.latest.y - this.start.y) > DragGesture.SLOP_PX)
        this.finish();
      return;
    }

    if (this.state !== "active") return;
    event.preventDefault();

    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = requestAnimationFrame(() => {
      this.frame = null;
      if (this.state !== "active") return;
      this.callbacks.onMove(this.latest);
    });
  }

  private onPointerUp (event: JQuery.TriggeredEvent): void {
    const pointer = DragGesture.read(event);
    if (pointer.pointerId !== this.pointerId) return;
    const point = this.toContainerPoint(pointer);
    const state = this.state;
    this.finish();

    if (state === "active") {
      event.preventDefault();
      event.stopPropagation();
      this.callbacks.onEnd(point);
    } else if (state === "pending") {
      this.callbacks.onTap?.(point);
    }
  }

  private onPointerCancel (event: JQuery.TriggeredEvent): void {
    const pointer = DragGesture.read(event);
    if (pointer.pointerId !== this.pointerId) return;
    this.abort();
  }

  /** Right-click aborts a mouse drag. A touch long press also fires this, and must not. */
  private onContextMenu (): void {
    if (this._pointerType !== "mouse") return;
    this.abort();
  }


  /* ============================== */
  /* ========== Helpers =========== */
  /* ============================== */

  private ns (events: string): string {
    return events.split(" ").map((name) => `${name}.e6.note-drag-${this.id}`).join(" ");
  }

  private toContainerPoint (pointer: { pageX: number, pageY: number }): Point {
    const offset = NoteUtilities.containerOffset;
    return { x: pointer.pageX - offset.x, y: pointer.pageY - offset.y };
  }

  /** Normalizes a jQuery pointer event, falling back to the synthetic fields that specs set directly */
  private static read (event: JQuery.TriggeredEvent): { pageX: number, pageY: number, button: number, pointerId: number, pointerType: string, isPrimary: boolean } {
    const synthetic = event as unknown as PointerLike;
    const native = synthetic.originalEvent ?? {};
    return {
      pageX: synthetic.pageX ?? native.pageX ?? 0,
      pageY: synthetic.pageY ?? native.pageY ?? 0,
      button: synthetic.button ?? native.button ?? 0,
      pointerId: synthetic.pointerId ?? native.pointerId ?? 0,
      pointerType: synthetic.pointerType ?? native.pointerType ?? "mouse",
      isPrimary: native.isPrimary ?? synthetic.isPrimary ?? true,
    };
  }
}
