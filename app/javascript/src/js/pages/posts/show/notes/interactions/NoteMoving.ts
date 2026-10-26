import Note from "@/pages/posts/show/notes/Note";
import NoteEditor from "@/pages/posts/show/notes/NoteEditor";
import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import { Point } from "@/pages/posts/show/notes/Types";

/** Moving an existing note by dragging its box. */
export default class NoteMoving {

  private isMoving = false;
  private startX = 0;
  private startY = 0;
  private originalPosition: Point | null = null; // In container coordinates
  private throttleId: number | null = null;

  /** Note currently being moved */
  private movingNote: Note | null = null;

  public constructor () {
    const container = NoteUtilities.container;

    container.on("mousedown.e6.note", ".note-box", (event) => {
      if (!NoteUtilities.editing) return;

      // Ignore clicks on handles or body
      const $noteBox = $(event.target);
      if (!$noteBox.hasClass("note-box")) return;

      event.preventDefault();
      event.stopPropagation();

      const note = Note.getByID($noteBox.attr("nid"));
      if (!note) return;

      if (!note.hasBackup) note.backup();
      this.isMoving = true;
      this.movingNote = note;

      this.startX = event.pageX - NoteUtilities.containerOffset.x;
      this.startY = event.pageY - NoteUtilities.containerOffset.y;
      this.originalPosition = { x: note.relX, y: note.relY };

      note.editing = true;
      note.pending = true;
      NoteUtilities.dragging = true;
    });

    container.on("mousemove.e6.note", (event) => {
      if (!this.isMoving || !this.movingNote) return;

      event.preventDefault();

      if (this.throttleId) cancelAnimationFrame(this.throttleId);
      this.throttleId = requestAnimationFrame(() => {
        if (!this.movingNote || !this.originalPosition) return;

        const deltaX = event.pageX - NoteUtilities.containerOffset.x - this.startX;
        const deltaY = event.pageY - NoteUtilities.containerOffset.y - this.startY;

        this.movingNote.moveTo(this.clamp({
          x: this.originalPosition.x + deltaX,
          y: this.originalPosition.y + deltaY,
        }, this.movingNote));
      });
    });

    container.on("mouseup.e6.note", (event) => {
      if (!this.isMoving || !this.movingNote) return;

      event.preventDefault();
      event.stopPropagation();

      const note = this.movingNote;
      this.cleanUp();

      NoteEditor.instance.open(note.id);

      // Wait for the UI to settle
      requestAnimationFrame(() => note.adjustBodyPosition());
    });

    container.on("note:abort mouseleave.e6.note", () => {
      if (!this.isMoving || !this.movingNote) return;

      // Clamp the note to the edge of the container
      const note = this.movingNote;
      const position = note.$box.position();
      note.moveTo(this.clamp({ x: position.left, y: position.top }, note));

      this.cleanUp();

      // Wait for the UI to settle
      requestAnimationFrame(() => note.adjustBodyPosition());
    });

    container.on("contextmenu.e6.note", (event) => {
      if (!this.isMoving) return;
      event.preventDefault();
      container.trigger("note:abort");
    });
  }

  /** Keeps the note within the container bounds */
  private clamp ({ x, y }: Point, note: Note): Point {
    const dimensions = NoteUtilities.containerDimensions;
    return {
      x: Math.max(0, Math.min(x, dimensions.width - note.relWidth)),
      y: Math.max(0, Math.min(y, dimensions.height - note.relHeight)),
    };
  }

  private cleanUp (): void {
    if (this.throttleId) {
      cancelAnimationFrame(this.throttleId);
      this.throttleId = null;
    }

    if (this.movingNote) this.movingNote.editing = false;
    NoteUtilities.dragging = false;
    this.movingNote = null;
    this.originalPosition = null;
    this.isMoving = false;
  }
}
