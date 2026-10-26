import Note from "@/pages/posts/show/notes/Note";
import NoteEditor from "@/pages/posts/show/notes/NoteEditor";
import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";

/** Drawing a new note by click-dragging on an empty area of the container. */
export default class NoteDrawing {

  private isDrawing = false;
  private startX = 0;
  private startY = 0;
  private throttleId: number | null = null;

  /** Note currently being drawn */
  private drawingNote: Note | null = null;

  public constructor () {
    const container = NoteUtilities.container;

    // Initial click to start drawing
    container.on("mousedown.e6.note", (event) => {
      if (!NoteUtilities.editing) return;

      // Only respond to left mouse button
      if (event.button !== 0) {
        if (!this.isDrawing) return;
        event.preventDefault();
        this.abort();
        return;
      }

      // Don't start drawing if clicking on an existing note
      if ($(event.target).closest(".note-box").length > 0) return;

      event.preventDefault();
      event.stopPropagation();

      this.isDrawing = true;
      this.startX = event.pageX - NoteUtilities.containerOffset.x;
      this.startY = event.pageY - NoteUtilities.containerOffset.y;

      // Create a temporary note immediately
      this.drawingNote = Note.createTemporary();
      this.drawingNote.moveTo({ x: this.startX, y: this.startY });
      this.drawingNote.editing = true;
    });

    // Mousemove to update the drawing
    container.on("mousemove.e6.note", (event) => {
      if (!this.isDrawing || !this.drawingNote) return;

      event.preventDefault();

      if (this.throttleId) cancelAnimationFrame(this.throttleId);
      this.throttleId = requestAnimationFrame(() => {
        if (!this.drawingNote) return;
        const currentX = event.pageX - NoteUtilities.containerOffset.x;
        const currentY = event.pageY - NoteUtilities.containerOffset.y;

        this.drawingNote.adjustTo({
          x: Math.min(this.startX, currentX),
          y: Math.min(this.startY, currentY),
          width: Math.abs(currentX - this.startX),
          height: Math.abs(currentY - this.startY),
        });
      });
    });

    // Mouseup to finalize the drawing
    container.on("mouseup.e6.note", (event) => {
      if (!this.isDrawing || !this.drawingNote) return;

      event.preventDefault();
      event.stopPropagation();

      const endX = event.pageX - NoteUtilities.containerOffset.x;
      const endY = event.pageY - NoteUtilities.containerOffset.y;

      const width = Math.abs(endX - this.startX);
      const height = Math.abs(endY - this.startY);

      this.isDrawing = false;
      this.cancelFrame();

      const note = this.drawingNote;
      this.drawingNote = null;

      // Only create the note if the area is large enough
      const minSize = NoteUtilities.noteMinWidth;
      if (width < minSize || height < minSize) {
        note.destroy();
        return;
      }

      note.adjustTo({
        x: Math.min(this.startX, endX),
        y: Math.min(this.startY, endY),
        width: width,
        height: height,
      });

      note.editing = false;
      note.adjustBodyPosition();
      NoteEditor.instance.open(note.id);
    });

    container.on("note:abort mouseleave.e6.note", () => this.abort());

    container.on("contextmenu.e6.note", (event) => {
      if (!this.isDrawing) return;
      event.preventDefault();
      this.abort();
    });
  }

  private abort (): void {
    if (!this.isDrawing || !this.drawingNote) return;

    this.drawingNote.destroy();
    this.drawingNote = null;
    this.isDrawing = false;
    this.cancelFrame();
  }

  private cancelFrame (): void {
    if (!this.throttleId) return;
    cancelAnimationFrame(this.throttleId);
    this.throttleId = null;
  }
}
