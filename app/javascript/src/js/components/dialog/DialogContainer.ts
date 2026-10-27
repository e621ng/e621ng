import type Dialog from "./Dialog";

/**
 * State shared by every dialog on the page: the fixed container they are
 * appended to, its cached dimensions, the z-order stack, and the ResizeObserver
 * that keeps content-sized dialogs measured.
 */
export default class DialogContainer {

  /** Cached container size, refreshed on window resize and fullscreen changes */
  public static width = 0;
  public static height = 0;

  private static _element: JQuery<HTMLElement> | null = null;
  private static fullscreenTimer: ReturnType<typeof setTimeout> | null = null;

  /** Container to which all dialogs are appended. Created on first access. */
  public static get element (): JQuery<HTMLElement> {
    if (this._element) return this._element;

    this._element = $("<div id='dialog-container'>").appendTo("body");
    this.measure();

    $(window).on("resize.dialog orientationchange.dialog", () => this.refresh());

    // The layout settles a moment after a fullscreen toggle; debounce quick toggling
    $(document).on("fullscreenchange webkitfullscreenchange mozfullscreenchange MSFullscreenChange", () => {
      if (this.fullscreenTimer) clearTimeout(this.fullscreenTimer);
      this.fullscreenTimer = setTimeout(() => {
        this.fullscreenTimer = null;
        this.refresh();
      }, 100);
    });

    return this._element;
  }

  private static measure (): void {
    this.width = this._element?.innerWidth() || 800;
    this.height = this._element?.innerHeight() || 600;
  }

  /** Re-measures the container and notifies the dialogs when its size changed */
  public static refresh (): void {
    const priorWidth = this.width, priorHeight = this.height;
    this.measure();
    if (priorWidth !== this.width || priorHeight !== this.height)
      $(window).trigger("dialogContainer:resize");
  }


  /* ============================== */
  /* ========== Stacking ========== */
  /* ============================== */

  /** Dialog ids, bottom to top */
  private static stack: number[] = [];
  private static index = new Map<number, Dialog>();
  private static nextID = 0;

  public static allocateID (): number {
    return this.nextID++;
  }

  /** Adds a built dialog to the top of the stack */
  public static register (dialog: Dialog): void {
    this.index.set(dialog.id, dialog);
    this.stack.push(dialog.id);
    this.restack();
  }

  public static unregister (dialog: Dialog): void {
    this.index.delete(dialog.id);
    this.stack = this.stack.filter((id) => id !== dialog.id);
    this.restack();
  }

  /** Brings the dialog to the front */
  public static focus (dialog: Dialog): void {
    const current = this.stack.indexOf(dialog.id);
    if (current > -1 && current === this.stack.length - 1) return;

    if (current > -1) this.stack.splice(current, 1);
    this.stack.push(dialog.id);
    this.restack();
  }

  private static restack (): void {
    this.stack.forEach((id, order) => this.index.get(id)?.setZIndex(order));
  }


  /* ============================== */
  /* ====== Content observer ====== */
  /* ============================== */

  private static _observer: ResizeObserver | null = null;

  private static get observer (): ResizeObserver {
    if (!this._observer)
      this._observer = new ResizeObserver((entries) => {
        for (const entry of entries) {
          const dialog = this.index.get(Number(entry.target.getAttribute("data-id")));
          if (!dialog) continue;

          const blockSize = this.blockSize(entry);
          if (blockSize === 0) continue; // Hidden
          dialog.setContentHeight(blockSize);
        }
      });
    return this._observer;
  }

  /** Watches the dialog's content element so the dialog height follows it */
  public static observe (dialog: Dialog): void {
    const content = dialog.$element[0];
    content.setAttribute("data-id", String(dialog.id));
    this.observer.observe(content);
  }

  public static unobserve (dialog: Dialog): void {
    this._observer?.unobserve(dialog.$element[0]);
  }

  // Older Firefox versions implemented borderBoxSize as a single object rather than an array
  private static blockSize (entry: ResizeObserverEntry): number {
    const size = entry.borderBoxSize as unknown as ResizeObserverSize[] | ResizeObserverSize | undefined;
    if (Array.isArray(size)) return size[0]?.blockSize ?? entry.contentRect.height;
    return size?.blockSize ?? entry.contentRect.height;
  }

  public static remToPx (rem: number): number {
    return rem * (parseFloat(getComputedStyle(document.documentElement).fontSize) || 16);
  }
}
