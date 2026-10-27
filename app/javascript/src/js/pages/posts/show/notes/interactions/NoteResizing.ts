import Note from "@/pages/posts/show/notes/Note";
import NoteEditor from "@/pages/posts/show/notes/NoteEditor";
import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import DragGesture from "@/pages/posts/show/notes/interactions/DragGesture";
import { Point, Rect, ResizeHandle } from "@/pages/posts/show/notes/Types";

/**
 * Resizing an existing note by dragging one of its corner handles.
 * Handles are explicit affordances, so every pointer type starts immediately.
 */
export default class NoteResizing {

  private handle: ResizeHandle = "se";
  private start: Point = { x: 0, y: 0 };
  private originalBounds: Rect = { x: 0, y: 0, width: 0, height: 0 }; // In container coordinates

  /** Note currently being resized */
  private resizingNote: Note | null = null;

  private readonly gesture = new DragGesture({
    onStart: (point) => {
      const note = this.resizingNote;
      if (!note) return;

      if (!note.hasBackup) note.backup();
      this.start = point;
      this.originalBounds = {
        x: note.relX,
        y: note.relY,
        width: note.relWidth,
        height: note.relHeight,
      };

      note.editing = true;
      note.pending = true;
      NoteUtilities.resizing = true;
    },

    onMove: (point) => {
      const note = this.resizingNote;
      if (!note) return;
      const bounds = this.originalBounds;

      const deltaX = point.x - this.start.x;
      const deltaY = point.y - this.start.y;

      let newX = bounds.x;
      let newY = bounds.y;
      let newWidth: number;
      let newHeight: number;

      if (this.handle === "nw") {
        // Northwest handle: resize from top-left corner
        newX = bounds.x + deltaX;
        newY = bounds.y + deltaY;
        newWidth = bounds.width - deltaX;
        newHeight = bounds.height - deltaY;
      } else {
        // Southeast handle: resize from bottom-right corner
        newWidth = bounds.width + deltaX;
        newHeight = bounds.height + deltaY;
      }

      // Enforce minimum dimensions
      const minSize = NoteUtilities.noteMinWidth;
      if (newWidth < minSize) {
        if (this.handle === "nw") newX = bounds.x + bounds.width - minSize;
        newWidth = minSize;
      }
      if (newHeight < minSize) {
        if (this.handle === "nw") newY = bounds.y + bounds.height - minSize;
        newHeight = minSize;
      }

      note.adjustTo({ x: newX, y: newY, width: newWidth, height: newHeight });
    },

    onEnd: () => {
      const note = this.resizingNote;
      this.cleanUp();
      if (!note) return;

      NoteEditor.instance.open(note.id);

      // Wait for the UI to settle
      requestAnimationFrame(() => note.adjustBodyPosition());
    },

    onCancel: () => {
      const note = this.resizingNote;
      this.cleanUp();
      if (!note) return;

      note.adjustTo(this.originalBounds);

      // Wait for the UI to settle
      requestAnimationFrame(() => note.adjustBodyPosition());
    },
  }, { longPress: false });

  public constructor () {
    const container = NoteUtilities.container;

    container.on("pointerdown.e6.note", ".note-handle", (event) => {
      if (!NoteUtilities.editing) return;

      const $handle = $(event.currentTarget);
      const note = Note.getByID($handle.closest(".note-box").attr("nid"));
      if (!note) return;

      this.resizingNote = note;
      this.handle = $handle.hasClass("note-handle-nw") ? "nw" : "se";
      if (!this.gesture.begin(event)) {
        this.resizingNote = null;
        return;
      }

      event.preventDefault();
      event.stopPropagation();
    });

    container.on("note:abort", () => this.gesture.abort());
  }

  private cleanUp (): void {
    if (this.resizingNote) this.resizingNote.editing = false;
    NoteUtilities.resizing = false;
    this.resizingNote = null;
  }
}
