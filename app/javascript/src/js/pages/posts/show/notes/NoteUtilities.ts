import LStorage from "@/utility/storage/Local";
import { Point, Size } from "@/pages/posts/show/notes/Types";

/**
 * Shared state for the note overlay: the container element, its cached
 * geometry, the image scale ratio, and the editing / visibility flags.
 */
export default class NoteUtilities {

  /* ============================== */
  /* ========= Container ========== */
  /* ============================== */

  private static _container: JQuery<HTMLElement> | null = null;

  // Cached container properties, invalidated on resize
  private static _containerDimensions: Size | null = null;
  private static _containerOffset: Point | null = null;

  // Container states
  private static _editing = false;
  private static _visible: boolean = LStorage.Posts.Notes;
  private static _dragging = false;
  private static _resizing = false;

  /** Returns the container to which all notes are appended */
  public static get container (): JQuery<HTMLElement> {
    if (this._container !== null) return this._container;
    this._container = $("#note-container");

    // Load container state from storage
    this._container.attr("enabled", String(LStorage.Posts.Notes));

    // Track size changes so that notes can be rescaled
    const resizeObserver = new ResizeObserver(() => {
      this._scaleRatio = null;
      this._containerDimensions = null;
      this._containerOffset = null;
      $("#note-container .note-box").trigger("note:scale");
    });
    resizeObserver.observe(this._container[0]);

    return this._container;
  }

  public static get containerDimensions (): Size {
    if (this._containerDimensions === null)
      this._containerDimensions = {
        width: this.container.width() || 0,
        height: this.container.height() || 0,
      };
    return this._containerDimensions;
  }

  public static get containerOffset (): Point {
    if (this._containerOffset === null) {
      const offset = this.container.offset();
      this._containerOffset = { x: offset?.left || 0, y: offset?.top || 0 };
    }
    return this._containerOffset;
  }


  /* ============================== */
  /* =========== States =========== */
  /* ============================== */

  /** Whether the note editor is currently active */
  public static toggleEditing (): void { this.editing = !this.editing; }
  public static get editing (): boolean { return this._editing; }
  public static set editing (value: boolean) {
    this._editing = value;
    this.container
      .trigger(`note:editing:${value}`)
      .attr("editing", value ? "true" : "false");

    // The NoteEditor listens for `note:editing:false` and closes itself
    if (value) {
      $("#mark-as-translated-section").show();
    } else {
      $("#mark-as-translated-section").hide();
      this.container.trigger("note:abort");
    }
  }

  /** Whether the note container is visible */
  public static get visible (): boolean { return this._visible; }
  public static set visible (value: boolean) {
    this._visible = value;
    LStorage.Posts.Notes = value;
    this.container
      .attr("enabled", String(value))
      .trigger(`note:visible:${value}`);

    // Cannot scale note bodies if notes are hidden
    if (value) $("#note-container .note-box").trigger("note:scale");
  }

  /** Whether a note is currently being moved */
  public static get dragging (): boolean { return this._dragging; }
  public static set dragging (value: boolean) {
    this._dragging = value;
    this.container.attr("dragging", value ? "true" : "false");
  }

  /** Whether a note is currently being resized */
  public static get resizing (): boolean { return this._resizing; }
  public static set resizing (value: boolean) {
    this._resizing = value;
    this.container.attr("resizing", value ? "true" : "false");
  }


  /* ============================== */
  /* =========== Scaling ========== */
  /* ============================== */

  private static _scaleRatio: number | null = null;
  private static _originalImageWidth: number | null = null;

  /** Returns the ratio between the current container size and that of the original image */
  public static get scaleRatio (): number {
    if (this._scaleRatio !== null) return this._scaleRatio;

    if (!this._originalImageWidth)
      this._originalImageWidth = parseFloat($("#image-container").attr("data-width") || "") || 1;

    this._scaleRatio = (this.container.width() || 0) / this._originalImageWidth;
    return this._scaleRatio;
  }

  /** Minimum note size (20 original-image pixels), in container coordinates */
  public static get noteMinWidth (): number {
    return Math.round(20 * this.scaleRatio);
  }
}
