import DialogContainer from "./DialogContainer";

export interface DialogParams {
  /** Header text */
  title?: string;
  /** Initial placement as "<x> <y>": labels (left/center/right, top/center/bottom) or numbers from 0 to 1 */
  position?: string;
  /** Dialog width in px. Defaults to the rendered width, or 250 */
  width?: number;
  /** Content height in px. When omitted, the dialog follows its content */
  height?: number;
  /** Open immediately after construction */
  startOpen?: boolean;
}

/** Horizontal and vertical placement, each between 0 (start) and 1 (end) */
export type NormalizedPosition = [number, number];

const POSITION_LABELS = new Map<string, number>([
  ["center", 0.5],
  ["top", 0],
  ["bottom", 1],
  ["left", 0],
  ["right", 1],
]);

/** Subset of the pointer event fields dragging reads, so that specs can trigger plain `$.Event`s */
interface PointerLike {
  button?: number;
  clientX?: number;
  clientY?: number;
  pointerId?: number;
  originalEvent?: Partial<PointerEvent>;
}

function readPointer (event: JQuery.TriggeredEvent): Required<Omit<PointerLike, "originalEvent">> {
  const synthetic = event as unknown as PointerLike;
  const native = synthetic.originalEvent ?? {};
  return {
    button: synthetic.button ?? native.button ?? 0,
    clientX: synthetic.clientX ?? native.clientX ?? 0,
    clientY: synthetic.clientY ?? native.clientY ?? 0,
    pointerId: synthetic.pointerId ?? native.pointerId ?? 0,
  };
}

function clamp (value: number, min: number, max: number): number {
  return Math.max(min, Math.min(value, max));
}

/**
 * A draggable, stackable floating dialog wrapping an existing content element.
 * Parameters may also come from `data-*` attributes on that element.
 * Fires `dialog:open`, `dialog:close`, and `dialog:destroy` on the content element,
 * and a native `dialog:move` on the window whenever the frame is repositioned.
 */
export default class Dialog {

  public readonly id: number;
  /** The dialog frame */
  public readonly $dialog: JQuery<HTMLElement>;
  /** The content element the dialog wraps */
  public readonly $element: JQuery<HTMLElement>;
  private readonly $header: JQuery<HTMLElement>;
  private readonly $title: JQuery<HTMLElement>;

  public width = 0;
  /** Full height, header included */
  public height = 0;
  private left = 0;
  private top = 0;
  private position: NormalizedPosition = [0.5, 0.5];
  private observed = false;
  private _isOpen = false;

  public constructor (element: JQuery<HTMLElement> | string, params: DialogParams = {}) {
    this.id = DialogContainer.allocateID();
    this.$element = typeof element === "string" ? $(element) : element;

    this.$dialog = $("<div class='dialog hidden'>")
      .attr({
        "role": "dialog",
        "tabindex": "-1",
        "aria-labelledby": `dialog-title-${this.id}`,
        "data-id": this.id,
      })
      .appendTo(DialogContainer.element);

    this.$header = $("<div class='dialog-header'>").appendTo(this.$dialog);
    this.$title = $("<span>").attr("id", `dialog-title-${this.id}`).appendTo(this.$header);
    this.$header.on("pointerdown", (event) => this.startDrag(event));

    $("<button type='button' class='st-button'>&times;</button>")
      .attr({ "title": "Close", "aria-label": "Close dialog" })
      .appendTo(this.$header)
      .on("click", () => this.close());

    $("<div class='dialog-content'>")
      .attr("role", "document")
      .appendTo(this.$dialog)
      .append(this.$element);

    DialogContainer.register(this);
    this.$dialog.on("pointerdown", () => DialogContainer.focus(this));

    this.$dialog.on("keydown", (event) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      this.close();
    });

    // Explicit parameters win over data attributes
    const options = { ...this.$element.data() } as DialogParams;
    for (const [key, value] of Object.entries(params))
      if (value !== undefined) (options as Record<string, unknown>)[key] = value;

    if (options.title) this.$title.text(options.title);

    if (options.position) {
      const [x, y] = options.position.trim().split(/\s+/);
      this.position = [Dialog.resolvePosition(x), Dialog.resolvePosition(y)];
    }

    this.width = options.width || this.$dialog.outerWidth() || 250;
    if (options.height) this.height = options.height + this.headerHeight();
    else {
      this.height = this.$dialog.outerHeight() || 200;
      DialogContainer.observe(this);
      this.observed = true;
    }

    this.reposition();
    $(window).on(`dialogContainer:resize.dialog-${this.id}`, () => this.reposition());

    if (options.startOpen) this.open();
  }

  /** Maps a placement label or number to a value between 0 and 1. Unknown input centers. */
  public static resolvePosition (value: string | number | undefined): number {
    if (typeof value === "number") return clamp(value, 0, 1);
    if (typeof value !== "string") return 0.5;

    const label = POSITION_LABELS.get(value);
    if (label !== undefined) return label;

    const numeric = Number(value);
    return value !== "" && !isNaN(numeric) ? clamp(numeric, 0, 1) : 0.5;
  }


  /* ============================== */
  /* ========= Visibility ========= */
  /* ============================== */

  public get isOpen (): boolean { return this._isOpen; }
  public set isOpen (value: boolean) {
    if (value) this.open();
    else this.close();
  }

  public open (): void {
    this._isOpen = true;
    this.$dialog.removeClass("hidden");
    DialogContainer.focus(this);
    this.$dialog.trigger("focus");
    this.$element.trigger("dialog:open");
  }

  /** @param quiet Skip the `dialog:close` event */
  public close (quiet = false): void {
    this._isOpen = false;
    this.stopDrag();
    this.$dialog.addClass("hidden");
    if (!quiet) this.$element.trigger("dialog:close");
  }

  public toggle (): void {
    if (this.isOpen) this.close();
    else this.open();
  }

  public setTitle (text: string): void {
    this.$title.text(text);
  }

  /** Removes the dialog, its content element included */
  public destroy (): void {
    this.close(true);
    DialogContainer.unregister(this);
    $(window).off(`.dialog-${this.id}`);
    if (this.observed) DialogContainer.unobserve(this);
    this.$element.trigger("dialog:destroy");
    this.$dialog.remove();
  }


  /* ============================== */
  /* ========== Geometry ========== */
  /* ============================== */

  public setZIndex (order: number): void {
    this.$dialog.css("z-index", 250 + order);
  }

  /** Called by the container's observer when the content element changes size */
  public setContentHeight (blockSize: number): void {
    const height = blockSize + this.headerHeight();
    if (height === this.height) return;
    this.height = height;
    this.reposition();
  }

  /** Places the dialog from its normalized position, clamped to the container */
  public reposition (): void {
    const maxX = DialogContainer.width - this.width;
    const maxY = DialogContainer.height - this.height;
    this.applyPosition(
      clamp(this.position[0] * maxX, 0, maxX),
      clamp(this.position[1] * maxY, 0, maxY),
    );
  }

  private applyPosition (left: number, top: number): void {
    this.left = left;
    this.top = top;
    this.$dialog.css({ width: this.width, height: this.height, left, top });
    // Native, so that body-anchored overlays (autocomplete) can follow
    window.dispatchEvent(new Event("dialog:move"));
  }

  // Falls back to the stylesheet's 2rem while the dialog is hidden and unmeasurable
  private headerHeight (): number {
    return this.$header.outerHeight() || DialogContainer.remToPx(2);
  }


  /* ============================== */
  /* ========== Dragging ========== */
  /* ============================== */

  private dragPointerId: number | null = null;
  private dragStart = { pointerX: 0, pointerY: 0, left: 0, top: 0 };
  private dragLatest = { x: 0, y: 0 };
  private dragFrame: number | null = null;

  private get dragNamespace (): string { return `.dialog-drag-${this.id}`; }

  private startDrag (event: JQuery.TriggeredEvent): void {
    if (this.dragPointerId !== null) return;
    const pointer = readPointer(event);
    if (pointer.button !== 0) return;
    if ($(event.target).is("button")) return;

    event.preventDefault();
    this.dragPointerId = pointer.pointerId;
    this.dragStart = { pointerX: pointer.clientX, pointerY: pointer.clientY, left: this.left, top: this.top };
    this.dragLatest = { x: pointer.clientX, y: pointer.clientY };
    this.$dialog.addClass("dragging");

    const header = this.$header[0];
    if (typeof header.setPointerCapture === "function") {
      try { header.setPointerCapture(pointer.pointerId); } catch { /* pointer already gone */ }
    }

    // Captured events are retargeted to the header and still bubble to the document
    const ns = this.dragNamespace;
    $(document)
      .on(`pointermove${ns}`, (e) => this.drag(e))
      .on(`pointerup${ns} pointercancel${ns}`, (e) => {
        if (readPointer(e).pointerId === this.dragPointerId) this.stopDrag();
      });
    this.$header.on(`lostpointercapture${ns}`, () => this.stopDrag());
    $(window).on(`blur${ns}`, () => this.stopDrag());
  }

  private drag (event: JQuery.TriggeredEvent): void {
    const pointer = readPointer(event);
    if (pointer.pointerId !== this.dragPointerId) return;
    event.preventDefault();
    this.dragLatest = { x: pointer.clientX, y: pointer.clientY };

    if (this.dragFrame) cancelAnimationFrame(this.dragFrame);
    this.dragFrame = requestAnimationFrame(() => {
      this.dragFrame = null;
      if (this.dragPointerId === null) return;
      this.moveToPointer();
    });
  }

  private moveToPointer (): void {
    const maxX = DialogContainer.width - this.width;
    const maxY = DialogContainer.height - this.height;
    const left = clamp(this.dragStart.left + (this.dragLatest.x - this.dragStart.pointerX), 0, maxX);
    const top = clamp(this.dragStart.top + (this.dragLatest.y - this.dragStart.pointerY), 0, maxY);

    // Remembered for the next container resize
    this.position = [
      maxX > 0 ? left / maxX : 0,
      maxY > 0 ? top / maxY : 0,
    ];
    this.applyPosition(left, top);
  }

  private stopDrag (): void {
    if (this.dragPointerId === null) return;

    if (this.dragFrame) {
      cancelAnimationFrame(this.dragFrame);
      this.dragFrame = null;
    }

    const header = this.$header[0];
    if (typeof header.releasePointerCapture === "function") {
      try { header.releasePointerCapture(this.dragPointerId); } catch { /* capture already released */ }
    }
    this.dragPointerId = null;

    const ns = this.dragNamespace;
    $(document).off(ns);
    $(window).off(ns);
    this.$header.off(ns);
    this.$dialog.removeClass("dragging");
  }
}
