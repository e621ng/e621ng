import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import { NoteInit, NoteServerAttributes, NoteSnapshot, Point, Rect, Size } from "@/pages/posts/show/notes/Types";

/**
 * Represents a single note on the image.
 * Each note has a position, size, content, and associated DOM element.
 * Geometry (`x`, `y`, `width`, `height`) is stored in original-image pixels;
 * the `rel*` getters and the `moveTo` / `resizeTo` / `adjustTo` setters work
 * in container (on-screen) pixels.
 */
export default class Note {

  public id: string;
  public x: number;
  public y: number;
  public width: number;
  public height: number;
  public content: string;
  public isTemporary: boolean;

  public $box: JQuery<HTMLElement>;
  public $body: JQuery<HTMLElement>;

  private backupData?: NoteSnapshot;

  public constructor ({ id, x, y, width, height, content, html }: NoteInit) {
    this.id = id;
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.content = content;
    this.isTemporary = Note.isTemporaryID(id);

    // Build DOM
    this.$box = $("<div>")
      .addClass("note-box hidden")
      .attr("nid", id)
      .on("note:scale", () => { this.updateScale(); })
      .on("note:adjust", () => { this.adjustBodyPosition(); });

    // Handles
    $("<div>")
      .addClass("note-handle note-handle-nw")
      .appendTo(this.$box);
    $("<div>")
      .addClass("note-handle note-handle-se")
      .appendTo(this.$box);

    // Body
    this.$body = $("<div>")
      .addClass("note-body")
      .html(html)
      .appendTo(this.$box);

    // Append to container
    Note.noteIndex.set(id, this);
    this.$box.appendTo(NoteUtilities.container);

    // Initial scale
    this.updateScale();
    this.$box.removeClass("hidden");
  }


  /* ============================== */
  /* ========== Backups =========== */
  /* ============================== */

  public backup (): void {
    this.backupData = {
      id: this.id,
      x: this.x,
      y: this.y,
      width: this.width,
      height: this.height,
      content: this.content,
      html: this.$body.html(),
    };
  }

  public restore (): void {
    if (!this.backupData) return;

    this.id = this.backupData.id;
    this.x = this.backupData.x;
    this.y = this.backupData.y;
    this.width = this.backupData.width;
    this.height = this.backupData.height;
    this.content = this.backupData.content;
    this.$body.html(this.backupData.html);

    this.updateScale();
    this.adjustBodyPosition();

    this.backupData = undefined;
    this.pending = false;
  }

  public get hasBackup (): boolean { return this.backupData !== undefined; }

  /**
   * Applies the attributes returned by the server after a save.
   * Temporary notes are re-keyed in the index under their real ID.
   */
  public applyServerData (attrs: NoteServerAttributes, html: string): void {
    const newID = String(attrs.id);
    if (this.id !== newID) {
      Note.noteIndex.delete(this.id);
      this.id = newID;
      this.$box.attr("nid", newID);
      Note.noteIndex.set(newID, this);
    }
    this.isTemporary = false;

    this.x = attrs.x;
    this.y = attrs.y;
    this.width = attrs.width;
    this.height = attrs.height;
    this.content = attrs.body;
    this.$body.html(html);
    this.updateScale();

    this.pending = false;
    this.backupData = undefined;
  }


  /* ============================== */
  /* ========== Scaling =========== */
  /* ============================== */

  public updateScale (): void {
    const scale = NoteUtilities.scaleRatio;
    this.$box.css({
      width: `${Math.round(this.width * scale)}px`,
      height: `${Math.round(this.height * scale)}px`,
      left: `${Math.round(this.x * scale)}px`,
      top: `${Math.round(this.y * scale)}px`,
    });

    this.adjustBodyPosition();
    this.updateIsTiny();
  }

  /** Adjusts the note body position to keep it within the container bounds */
  public adjustBodyPosition (): void {
    if (!this.$box.is(":visible")) return;

    const containerDimensions = NoteUtilities.containerDimensions;
    const boxPosition = this.$box.position();
    const boxHeight = this.$box.outerHeight() || 0;

    const css: Record<string, string> = {};

    // Overflows to the right
    const bodyWidth = this.$body.outerWidth() || 0;
    if (boxPosition.left + bodyWidth > containerDimensions.width)
      css.left = `${containerDimensions.width - boxPosition.left - bodyWidth - 10}px`;

    // Overflows to the bottom
    const bodyHeight = this.$body.outerHeight() || 0;
    if (boxPosition.top + boxHeight + bodyHeight + 5 > containerDimensions.height) {
      css.top = `${-bodyHeight - 5}px`;
      css.bottom = "unset";
    }

    this.$body.css({ left: "", top: "", bottom: "" });
    this.$body.css(css);
  }

  public updateIsTiny (): void {
    const scale = NoteUtilities.scaleRatio;
    this.$box.toggleClass("tiny", (this.width * scale < 70) || (this.height * scale < 70));
  }


  /* ============================== */
  /* ======== State flags ========= */
  /* ============================== */

  public get focused (): boolean { return this.$box.hasClass("focused"); }
  public set focused (value: boolean) { this.$box.toggleClass("focused", value); }
  public get pending (): boolean { return this.$box.hasClass("pending"); }
  public set pending (value: boolean) { this.$box.toggleClass("pending", value); }
  public get editing (): boolean { return this.$box.hasClass("editing"); }
  public set editing (value: boolean) { this.$box.toggleClass("editing", value); }
  public get highlighted (): boolean { return this.$box.hasClass("highlighted"); }
  public set highlighted (value: boolean) { this.$box.toggleClass("highlighted", value); }


  /* ============================== */
  /* === Container coordinates ==== */
  /* ============================== */

  public get relX (): number { return Math.round(this.x * NoteUtilities.scaleRatio); }
  public get relY (): number { return Math.round(this.y * NoteUtilities.scaleRatio); }
  public get relWidth (): number { return Math.round(this.width * NoteUtilities.scaleRatio); }
  public get relHeight (): number { return Math.round(this.height * NoteUtilities.scaleRatio); }

  /** Set position using container-relative coordinates */
  public moveTo ({ x, y }: Point): void {
    const scale = NoteUtilities.scaleRatio;
    this.x = Math.round(x / scale);
    this.y = Math.round(y / scale);
    this.$box.css({
      left: x + "px",
      top: y + "px",
    });
  }

  /** Set dimensions using container-relative coordinates */
  public resizeTo ({ width, height }: Size): void {
    const scale = NoteUtilities.scaleRatio;
    this.width = Math.round(width / scale);
    this.height = Math.round(height / scale);
    this.$box.css({
      width: width + "px",
      height: height + "px",
    });
    this.updateIsTiny();
  }

  /** Set both position and dimensions using container-relative coordinates */
  public adjustTo ({ x, y, width, height }: Rect): void {
    const scale = NoteUtilities.scaleRatio;
    this.x = Math.round(x / scale);
    this.y = Math.round(y / scale);
    this.width = Math.max(1, Math.round(width / scale));
    this.height = Math.max(1, Math.round(height / scale));
    this.$box.css({
      left: x + "px",
      top: y + "px",
      width: width + "px",
      height: height + "px",
    });
    this.updateIsTiny();
  }

  /** Remove the note from the DOM and index */
  public destroy (): void {
    this.$box.remove();
    Note.noteIndex.delete(this.id);
  }


  /* ============================== */
  /* ======== Construction ======== */
  /* ============================== */

  /** Retrieves data from a staged note element and converts it into a Note instance */
  public static fromStaged (stagedElement: HTMLElement): Note | null {
    const data = stagedElement.dataset;

    // Guard against elements that aren't staged notes
    for (const field of ["id", "x", "y", "width", "height", "body"])
      if (typeof data[field] === "undefined") return null;

    return new Note({
      id: data.id as string,
      x: parseInt(data.x as string) || 0,
      y: parseInt(data.y as string) || 0,
      width: parseInt(data.width as string) || 1,
      height: parseInt(data.height as string) || 1,
      content: data.body as string,
      html: stagedElement.innerHTML,
    });
  }

  /** Creates an unsaved note with a temporary ID */
  public static createTemporary (): Note {
    return new Note({
      id: `temp-${Date.now()}`,
      x: 0,
      y: 0,
      width: 1,
      height: 1,
      content: "",
      html: "",
    });
  }

  public static isTemporaryID (id: string): boolean {
    return typeof id === "string" && id.startsWith("temp-");
  }


  /* ============================== */
  /* ========= Note Lookup ======== */
  /* ============================== */

  private static noteIndex = new Map<string, Note>();

  /** Returns a Note instance by its ID, or null if not found */
  public static getByID (id: string | null | undefined): Note | null {
    if (!id) return null;
    return this.noteIndex.get(id) || null;
  }
}
