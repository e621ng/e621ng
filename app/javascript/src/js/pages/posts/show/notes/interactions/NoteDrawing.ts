import Note from "@/pages/posts/show/notes/Note";
import NoteEditor from "@/pages/posts/show/notes/NoteEditor";
import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import DragGesture from "@/pages/posts/show/notes/interactions/DragGesture";
import { Point } from "@/pages/posts/show/notes/Types";

/**
 * Drawing a new note by dragging on an empty area of the container.
 * A mouse starts drawing immediately; a touch has to long-press first,
 * so that a plain finger drag still scrolls the page.
 */
export default class NoteDrawing {

  private start: Point = { x: 0, y: 0 };

  /** Note currently being drawn */
  private drawingNote: Note | null = null;

  private readonly gesture = new DragGesture({
    onStart: (point) => {
      this.start = point;
      this.drawingNote = Note.createTemporary();
      this.drawingNote.moveTo(point);
      this.drawingNote.editing = true;
    },

    onMove: (point) => {
      this.drawingNote?.adjustTo(this.rectTo(point));
    },

    onEnd: (point) => {
      const note = this.drawingNote;
      this.drawingNote = null;
      if (!note) return;

      const rect = this.rectTo(point);

      // Only create the note if the area is large enough
      const minSize = NoteUtilities.noteMinWidth;
      if (rect.width < minSize || rect.height < minSize) {
        note.destroy();
        return;
      }

      note.adjustTo(rect);
      note.editing = false;
      note.adjustBodyPosition();
      NoteEditor.instance.open(note.id);
    },

    onCancel: () => {
      this.drawingNote?.destroy();
      this.drawingNote = null;
    },
  }, { longPress: true });

  public constructor () {
    const container = NoteUtilities.container;

    container.on("pointerdown.e6.note", (event) => {
      if (!NoteUtilities.editing) return;

      // Any other button cancels a drawing in progress
      if (event.button !== 0) {
        if (!this.gesture.active) return;
        event.preventDefault();
        this.gesture.abort();
        return;
      }

      // Don't start drawing if pressing on an existing note
      if ($(event.target).closest(".note-box").length > 0) return;

      if (!this.gesture.begin(event)) return;
      event.preventDefault();
      event.stopPropagation();
    });

    container.on("note:abort", () => this.gesture.abort());
  }

  /** Rectangle spanned by the start point and the current pointer position */
  private rectTo (point: Point) {
    return {
      x: Math.min(this.start.x, point.x),
      y: Math.min(this.start.y, point.y),
      width: Math.abs(point.x - this.start.x),
      height: Math.abs(point.y - this.start.y),
    };
  }
}
