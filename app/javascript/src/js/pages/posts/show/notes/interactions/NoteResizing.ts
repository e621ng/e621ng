import Note from "@/pages/posts/show/notes/Note";
import NoteEditor from "@/pages/posts/show/notes/NoteEditor";
import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import { Rect, ResizeHandle } from "@/pages/posts/show/notes/Types";

/** Resizing an existing note by dragging one of its corner handles. */
export default class NoteResizing {

  private isResizing = false;
  private handle: ResizeHandle | null = null;
  private startX = 0;
  private startY = 0;
  private originalBounds: Rect | null = null; // In container coordinates
  private throttleId: number | null = null;

  /** Note currently being resized */
  private resizingNote: Note | null = null;

  public constructor () {
    const container = NoteUtilities.container;

    // Mousedown on a handle to start resizing
    container.on("mousedown.e6.note", ".note-handle", (event) => {
      if (!NoteUtilities.editing) return;

      event.preventDefault();
      event.stopPropagation();

      const $handle = $(event.currentTarget);
      const note = Note.getByID($handle.closest(".note-box").attr("nid"));
      if (!note) return;

      if (!note.hasBackup) note.backup();
      this.isResizing = true;
      this.resizingNote = note;
      this.handle = $handle.hasClass("note-handle-nw") ? "nw" : "se";

      this.startX = event.pageX - NoteUtilities.containerOffset.x;
      this.startY = event.pageY - NoteUtilities.containerOffset.y;

      this.originalBounds = {
        x: note.relX,
        y: note.relY,
        width: note.relWidth,
        height: note.relHeight,
      };

      note.editing = true;
      note.pending = true;
      NoteUtilities.resizing = true;
    });

    // Mousemove to resize the note
    container.on("mousemove.e6.note", (event) => {
      if (!this.isResizing || !this.resizingNote) return;

      event.preventDefault();

      if (this.throttleId) cancelAnimationFrame(this.throttleId);
      this.throttleId = requestAnimationFrame(() => {
        if (!this.resizingNote || !this.originalBounds) return;
        const bounds = this.originalBounds;

        const deltaX = event.pageX - NoteUtilities.containerOffset.x - this.startX;
        const deltaY = event.pageY - NoteUtilities.containerOffset.y - this.startY;

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

        this.resizingNote.adjustTo({ x: newX, y: newY, width: newWidth, height: newHeight });
      });
    });

    // Mouseup to finalize resizing
    container.on("mouseup.e6.note", (event) => {
      if (!this.isResizing || !this.resizingNote) return;

      event.preventDefault();
      event.stopPropagation();

      const note = this.resizingNote;
      this.cleanUp();

      NoteEditor.instance.open(note.id);

      // Wait for the UI to settle
      requestAnimationFrame(() => note.adjustBodyPosition());
    });

    container.on("note:abort mouseleave.e6.note", () => {
      if (!this.isResizing || !this.resizingNote) return;

      const note = this.resizingNote;
      if (this.originalBounds) note.adjustTo(this.originalBounds);
      this.cleanUp();

      // Wait for the UI to settle
      requestAnimationFrame(() => note.adjustBodyPosition());
    });

    container.on("contextmenu.e6.note", (event) => {
      if (!this.isResizing) return;
      event.preventDefault();
      container.trigger("note:abort");
    });
  }

  private cleanUp (): void {
    if (this.throttleId) {
      cancelAnimationFrame(this.throttleId);
      this.throttleId = null;
    }

    if (this.resizingNote) this.resizingNote.editing = false;
    NoteUtilities.resizing = false;
    this.resizingNote = null;
    this.originalBounds = null;
    this.handle = null;
    this.isResizing = false;
  }
}
