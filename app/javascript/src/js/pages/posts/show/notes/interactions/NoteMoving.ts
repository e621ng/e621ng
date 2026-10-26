import Note from "@/pages/posts/show/notes/Note";
import NoteEditor from "@/pages/posts/show/notes/NoteEditor";
import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import DragGesture from "@/pages/posts/show/notes/interactions/DragGesture";
import { Point } from "@/pages/posts/show/notes/Types";

/**
 * Moving an existing note by dragging its box.
 * A mouse starts moving immediately; a touch has to long-press first.
 * A plain tap on the box opens the editor.
 */
export default class NoteMoving {

  private start: Point = { x: 0, y: 0 };
  private originalPosition: Point = { x: 0, y: 0 }; // In container coordinates

  /** Note currently being moved */
  private movingNote: Note | null = null;

  private readonly gesture = new DragGesture({
    onStart: (point) => {
      const note = this.movingNote;
      if (!note) return;

      if (!note.hasBackup) note.backup();
      this.start = point;
      this.originalPosition = { x: note.relX, y: note.relY };

      note.editing = true;
      note.pending = true;
      NoteUtilities.dragging = true;
    },

    onMove: (point) => {
      const note = this.movingNote;
      if (!note) return;
      note.moveTo(this.clamp({
        x: this.originalPosition.x + point.x - this.start.x,
        y: this.originalPosition.y + point.y - this.start.y,
      }, note));
    },

    onEnd: () => {
      const note = this.movingNote;
      this.cleanUp();
      if (!note) return;

      NoteEditor.instance.open(note.id);

      // Wait for the UI to settle
      requestAnimationFrame(() => note.adjustBodyPosition());
    },

    onCancel: () => {
      const note = this.movingNote;
      this.cleanUp();
      if (!note) return;

      // Leave the note where it is, clamped to the edge of the container
      const position = note.$box.position();
      note.moveTo(this.clamp({ x: position.left, y: position.top }, note));

      // Wait for the UI to settle
      requestAnimationFrame(() => note.adjustBodyPosition());
    },

    onTap: () => {
      const note = this.movingNote;
      this.movingNote = null;
      if (note) NoteEditor.instance.open(note.id);
    },
  }, { longPress: true });

  public constructor () {
    const container = NoteUtilities.container;

    container.on("pointerdown.e6.note", ".note-box", (event) => {
      if (!NoteUtilities.editing) return;

      // Ignore presses on handles or body
      const $noteBox = $(event.target);
      if (!$noteBox.hasClass("note-box")) return;

      const note = Note.getByID($noteBox.attr("nid"));
      if (!note) return;

      this.movingNote = note;
      if (!this.gesture.begin(event)) {
        this.movingNote = null;
        return;
      }

      event.preventDefault();
      event.stopPropagation();
    });

    container.on("note:abort", () => this.gesture.abort());
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
    if (this.movingNote) this.movingNote.editing = false;
    NoteUtilities.dragging = false;
    this.movingNote = null;
  }
}
