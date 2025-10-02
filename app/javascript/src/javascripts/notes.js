import User from "./models/User.js";
import Utility from "./utility.js";
import Dialog from "./utility/dialog";
import LStorage from "./utility/storage.js";
import TaskQueue from "./utility/task_queue";

export default class NoteManager {

  static PermittedFileTypes = ["jpg", "png", "gif", "webp"];

  /** Initialize the manager and load existing notes from the staging area. */
  constructor () {
    const container = $("#image-container");
    if (container.length == 0) return;
    if (!NoteManager.PermittedFileTypes.includes((container.data("file-ext") + ""))) return;

    // Load notes from the staging area
    $("#note-staging article").each((_, note) => { Note.fromStaged(note); });

    // Highlight notes based on URL hash
    this.highlightHashNotes();
    $(window).on("hashchange.e6.note", this.highlightHashNotes);

    if (!User.is.member) return;

    // Open editor when a note is double-clicked
    NoteUtilities.container.on("dblclick.e6.note", ".note-box", (event) => {
      if (NoteUtilities.editing) return;
      event.preventDefault();
      event.stopPropagation();

      const box = $(event.currentTarget);
      const noteID = box.attr("nid");
      if (!noteID) return;

      NoteUtilities.editing = true;
      NoteManager.Editor.open(noteID);
    });

    // Switch to note editing mode when the "Edit Notes" button is clicked
    $("#translate").on("click.e6.note", (event) => {
      event.preventDefault();
      NoteUtilities.toggleEditing();

      if (NoteUtilities.editing) {
        $("html, body").animate({ scrollTop: NoteUtilities.containerOffset.top }, 200);
        NoteUtilities.visible = true;
      }
    });

    $("#translation-cancel").on("click.e6.note", (event) => {
      event.preventDefault();
      NoteUtilities.editing = false;
    });

    // Initialize interactivity once editing is enabled
    NoteUtilities.container.one("note:editing:true", () => {
      this.handleNoteEditing();
      this.handleNoteDrawing();
      this.handleNoteResizing();
      this.handleNoteMoving();

      this.handleAbortEvents();
    });
  }

  // ====================== //
  // ==== Highlighting ==== //
  // ====================== //

  highlightHashNotes () {
    $(".note-box.highlighted").removeClass("highlighted");

    const anchorMatch = window.location.hash.match(/^#note-(\d+)$/);
    if (!anchorMatch) return;
    const note = Note.getByID(anchorMatch[1]);
    if (!note) return;

    note.highlighted = true;
    note.$box[0].scrollIntoView({ behavior: "smooth", block: "center" });
  }

  // ====================== //
  // ==== Note Editing ==== //
  // ====================== //

  handleNoteEditing () {
    NoteUtilities.container.on("click.e6.note", ".note-body", (event) => {
      if (!NoteUtilities.editing) return;
      event.preventDefault();
      event.stopPropagation();

      const box = $(event.currentTarget).parents(".note-box");
      if (box.length == 0) return;
      const noteID = box.attr("nid");
      if (!noteID) return;

      NoteManager.Editor.open(noteID);
    });
  }


  // ====================== //
  // ==== Note Drawing ==== //
  // ====================== //

  handleNoteDrawing () {

    let isDrawing = false;
    let startX = 0;
    let startY = 0;
    let drawingNoteId = null;
    let mouseMoveThrottleId = null;

    /** @type {Note} Note currently being drawn */
    let $drawingNote = null;

    const abortDrawing = () => {
      if (!isDrawing || !$drawingNote) return;

      $drawingNote.destroy();
      $drawingNote = null;
      drawingNoteId = null;
      isDrawing = false;

      // Cancel any pending animation frame
      if (mouseMoveThrottleId) {
        cancelAnimationFrame(mouseMoveThrottleId);
        mouseMoveThrottleId = null;
      }
    };

    // Initial click to start drawing
    NoteUtilities.container.on("mousedown.e6.note", (event) => {
      if (!NoteUtilities.editing) return;

      // Only respond to left mouse button
      if (event.button !== 0) {
        if (!isDrawing) return;
        event.preventDefault();
        abortDrawing();
        return;
      }

      // Don't start drawing if clicking on an existing note
      const $target = $(event.target);
      if ($target.closest(".note-box").length > 0) return;

      event.preventDefault();
      event.stopPropagation();

      // Start drawing
      isDrawing = true;
      startX = event.pageX - NoteUtilities.containerOffset.left;
      startY = event.pageY - NoteUtilities.containerOffset.top;

      // Create a temporary note immediately
      drawingNoteId = `temp-${Date.now()}`;
      $drawingNote = new Note({
        id: drawingNoteId,
        x: 0,
        y: 0,
        width: 1,
        height: 1,
        content: "",
        html: "",
      });

      $drawingNote.moveTo({ x: startX, y: startY });
      $drawingNote.editing = true;
    });

    // Mousemove to update the drawing
    NoteUtilities.container.on("mousemove.e6.note", (event) => {
      if (!isDrawing || !$drawingNote) return;

      event.preventDefault();

      // Throttle mousemove events
      if (mouseMoveThrottleId) cancelAnimationFrame(mouseMoveThrottleId);
      mouseMoveThrottleId = requestAnimationFrame(() => {
        const currentX = event.pageX - NoteUtilities.containerOffset.left;
        const currentY = event.pageY - NoteUtilities.containerOffset.top;

        $drawingNote.adjustTo({
          x: Math.min(startX, currentX),
          y: Math.min(startY, currentY),
          width: Math.abs(currentX - startX),
          height: Math.abs(currentY - startY),
        });
      });
    });

    // Mouseup to finalize the drawing
    NoteUtilities.container.on("mouseup.e6.note", (event) => {
      if (!isDrawing || !$drawingNote) return;

      event.preventDefault();
      event.stopPropagation();

      const endX = event.pageX - NoteUtilities.containerOffset.left;
      const endY = event.pageY - NoteUtilities.containerOffset.top;

      const width = Math.abs(endX - startX);
      const height = Math.abs(endY - startY);

      isDrawing = false;

      // Cancel any pending animation frame
      if (mouseMoveThrottleId) {
        cancelAnimationFrame(mouseMoveThrottleId);
        mouseMoveThrottleId = null;
      }

      // Only create note if the area is large enough (minimum 20x20 pixels)
      let minSize = NoteUtilities.noteMinWidth;
      if (width >= minSize && height >= minSize) {
        $drawingNote.adjustTo({
          x: Math.min(startX, endX),
          y: Math.min(startY, endY),
          width: width,
          height: height,
        });

        $drawingNote.$box.removeClass("editing");
        $drawingNote.adjustBodyPosition();
        NoteManager.Editor.open(drawingNoteId);

        $drawingNote = null;
        drawingNoteId = null;
      } else {
        $drawingNote.destroy();
        $drawingNote = null;
        drawingNoteId = null;
      }
    });

    NoteUtilities.container.on("note:abort mouseleave.e6.note", abortDrawing);

    NoteUtilities.container.on("contextmenu.e6.note", (event) => {
      if (!isDrawing) return;
      event.preventDefault();
      abortDrawing();
    });
  }


  // ====================== //
  // ==== Note Resizing === //
  // ====================== //

  handleNoteResizing () {

    // Handle note resizing
    let isResizing = false;
    let resizeHandle = null; // 'nw' or 'se'
    let resizeStartX = 0;
    let resizeStartY = 0;
    let resizeOriginalBounds = null;
    let resizeThrottleId = null;

    /** @type {Note} Note currently being resized */
    let $resizingNote = null;

    // Mousedown to start resizing
    NoteUtilities.container.on("mousedown.e6.note", ".note-handle", (event) => {
      if (!NoteUtilities.editing) return;

      event.preventDefault();
      event.stopPropagation();

      const $handle = $(event.currentTarget);
      const $noteBox = $handle.closest(".note-box");
      const noteId = $noteBox.attr("nid");
      const note = Note.getByID(noteId);

      if (!note) return;

      if (!note.hasBackup) note.backup();
      isResizing = true;
      $resizingNote = note;
      resizeHandle = $handle.hasClass("note-handle-nw") ? "nw" : "se";

      resizeStartX = event.pageX - NoteUtilities.containerOffset.left;
      resizeStartY = event.pageY - NoteUtilities.containerOffset.top;

      // Store original bounds in container coordinates
      const ratio = NoteUtilities.scaleRatio;
      resizeOriginalBounds = {
        x: Math.round(note.x * ratio),
        y: Math.round(note.y * ratio),
        width: Math.round(note.width * ratio),
        height: Math.round(note.height * ratio),
      };

      note.editing = true;
      note.pending = true;
      NoteUtilities.resizing = true;
    });

    // Mousemove to resize the note
    NoteUtilities.container.on("mousemove.e6.note", (event) => {
      if (!isResizing || !$resizingNote) return;

      event.preventDefault();

      // Throttle resize events
      if (resizeThrottleId) cancelAnimationFrame(resizeThrottleId);
      resizeThrottleId = requestAnimationFrame(() => {
        const currentX = event.pageX - NoteUtilities.containerOffset.left;
        const currentY = event.pageY - NoteUtilities.containerOffset.top;

        const deltaX = currentX - resizeStartX;
        const deltaY = currentY - resizeStartY;

        let newX = resizeOriginalBounds.x;
        let newY = resizeOriginalBounds.y;
        let newWidth = resizeOriginalBounds.width;
        let newHeight = resizeOriginalBounds.height;

        if (resizeHandle === "nw") {
          // Northwest handle: resize from top-left corner
          newX = resizeOriginalBounds.x + deltaX;
          newY = resizeOriginalBounds.y + deltaY;
          newWidth = resizeOriginalBounds.width - deltaX;
          newHeight = resizeOriginalBounds.height - deltaY;
        } else if (resizeHandle === "se") {
          // Southeast handle: resize from bottom-right corner
          newWidth = resizeOriginalBounds.width + deltaX;
          newHeight = resizeOriginalBounds.height + deltaY;
        }

        // Enforce minimum dimensions
        const minSize = NoteUtilities.noteMinWidth;
        if (newWidth < minSize) {
          if (resizeHandle === "nw")
            newX = resizeOriginalBounds.x + resizeOriginalBounds.width - minSize;
          newWidth = minSize;
        }
        if (newHeight < minSize) {
          if (resizeHandle === "nw")
            newY = resizeOriginalBounds.y + resizeOriginalBounds.height - minSize;
          newHeight = minSize;
        }

        // Update the note's bounds
        $resizingNote.adjustTo({
          x: newX,
          y: newY,
          width: newWidth,
          height: newHeight,
        });
      });
    });

    // Mouseup to finalize resizing
    NoteUtilities.container.on("mouseup.e6.note", (event) => {
      // Handle note resizing
      if (!isResizing || !$resizingNote) return;

      event.preventDefault();
      event.stopPropagation();

      // Cancel any pending animation frame
      if (resizeThrottleId) {
        cancelAnimationFrame(resizeThrottleId);
        resizeThrottleId = null;
      }

      // Clean up
      $resizingNote.editing = false;
      NoteUtilities.resizing = false;
      resizeOriginalBounds = null;
      resizeHandle = null;
      isResizing = false;

      NoteManager.Editor.open($resizingNote.id);

      // Wait for the UI to settle
      requestAnimationFrame(() => {
        $resizingNote.adjustBodyPosition();
        $resizingNote = null;
      });
    });

    NoteUtilities.container.on("note:abort mouseleave.e6.note", () => {
      if (!isResizing || !$resizingNote) return;

      // Revert to original bounds
      if (resizeOriginalBounds)
        $resizingNote.adjustTo(resizeOriginalBounds);

      // Cancel any pending animation frame
      if (resizeThrottleId) {
        cancelAnimationFrame(resizeThrottleId);
        resizeThrottleId = null;
      }

      // Clean up resizing state
      $resizingNote.editing = false;
      NoteUtilities.resizing = false;
      resizeOriginalBounds = null;
      resizeHandle = null;
      isResizing = false;

      // Wait for the UI to settle
      requestAnimationFrame(() => {
        $resizingNote.adjustBodyPosition();
        $resizingNote = null;
      });
    });

    // Handle context menu during resizing
    NoteUtilities.container.on("contextmenu.e6.note", (event) => {
      if (!isResizing) return;
      event.preventDefault();
      NoteUtilities.container.trigger("note:abort");
    });
  }


  // ====================== //
  // ===== Note Moving ==== //
  // ====================== //

  handleNoteMoving () {

    let isMoving = false;
    let moveStartX = 0;
    let moveStartY = 0;
    let moveOriginalPosition = null;
    let moveThrottleId = null;

    /** @type {Note} Note currently being moved */
    let $movingNote = null;

    NoteUtilities.container.on("mousedown.e6.note", ".note-box", (event) => {
      if (!NoteUtilities.editing) return;

      // Ignore clicks on handles or body
      const $noteBox = $(event.target);
      if (!$noteBox.hasClass("note-box")) return;

      event.preventDefault();
      event.stopPropagation();

      const noteId = $noteBox.attr("nid");
      const note = Note.getByID(noteId);
      if (!note) return;

      if (!note.hasBackup) note.backup();
      isMoving = true;
      $movingNote = note;

      moveStartX = event.pageX - NoteUtilities.containerOffset.left;
      moveStartY = event.pageY - NoteUtilities.containerOffset.top;

      // Store original position in container coordinates
      moveOriginalPosition = {
        x: note.relX,
        y: note.relY,
      };

      // Add visual feedback
      note.editing = true;
      note.pending = true;
      NoteUtilities.dragging = true;
    });

    // Handle mousemove for note moving
    NoteUtilities.container.on("mousemove.e6.note", (event) => {
      if (!isMoving || !$movingNote) return;

      event.preventDefault();

      // Throttle move events
      if (moveThrottleId) cancelAnimationFrame(moveThrottleId);
      moveThrottleId = requestAnimationFrame(() => {
        const currentX = event.pageX - NoteUtilities.containerOffset.left;
        const currentY = event.pageY - NoteUtilities.containerOffset.top;

        const deltaX = currentX - moveStartX;
        const deltaY = currentY - moveStartY;

        const newX = moveOriginalPosition.x + deltaX;
        const newY = moveOriginalPosition.y + deltaY;

        // Keep the note within the container bounds
        const clampedX = Math.max(0, Math.min(newX, NoteUtilities.containerDimensions.width - $movingNote.relWidth));
        const clampedY = Math.max(0, Math.min(newY, NoteUtilities.containerDimensions.height - $movingNote.relHeight));

        // Update the note's position
        $movingNote.moveTo({ x: clampedX, y: clampedY });
      });
    });

    // Handle mouseup for note moving
    NoteUtilities.container.on("mouseup.e6.note", (event) => {
      if (!isMoving || !$movingNote) return;

      event.preventDefault();
      event.stopPropagation();

      // Cancel any pending animation frame
      if (moveThrottleId) {
        cancelAnimationFrame(moveThrottleId);
        moveThrottleId = null;
      }

      // Clean up
      $movingNote.editing = false;
      NoteUtilities.dragging = false;
      moveOriginalPosition = null;
      isMoving = false;

      NoteManager.Editor.open($movingNote.id);

      // Wait for the UI to settle
      requestAnimationFrame(() => {
        $movingNote.adjustBodyPosition();
        $movingNote = null;
      });
    });

    // Handle mouse leave to cancel moving
    NoteUtilities.container.on("note:abort mouseleave.e6.note", () => {
      if (!isMoving || !$movingNote) return;

      // Clamp the note to the edge of the container
      const currentPosition = $movingNote.$box.position();
      const clampedX = Math.max(0, Math.min(currentPosition.left, NoteUtilities.containerDimensions.width - $movingNote.relWidth));
      const clampedY = Math.max(0, Math.min(currentPosition.top, NoteUtilities.containerDimensions.height - $movingNote.relHeight));
      $movingNote.moveTo({ x: clampedX, y: clampedY });

      // Cancel any pending animation frame
      if (moveThrottleId) {
        cancelAnimationFrame(moveThrottleId);
        moveThrottleId = null;
      }

      // Clean up
      $movingNote.editing = false;
      NoteUtilities.dragging = false;
      moveOriginalPosition = null;
      isMoving = false;

      // Wait for the UI to settle
      requestAnimationFrame(() => {
        $movingNote.adjustBodyPosition();
        $movingNote = null;
      });
    });

    // Handle context menu during moving
    NoteUtilities.container.on("contextmenu.e6.note", (event) => {
      if (!isMoving) return;
      event.preventDefault();
      NoteUtilities.container.trigger("note:abort");
    });
  }


  // ====================== //
  //  Abort Events Handler  //
  // ====================== //

  handleAbortEvents () {

    // Window losing focus causes the script to think that the mouse button is still held down
    // Resize events will affect coordinate calculations
    $(window).on("blur.e6.note resize.e6.note", () => {
      NoteUtilities.container.trigger("note:abort");
    });

    // Escape key is pressed
    $(document).on("keydown.e6.note", (event) => {
      if (event.key !== "Escape") return;
      NoteUtilities.container.trigger("note:abort");
    });

    // Page visibility changes
    $(document).on("visibilitychange.e6.note", () => {
      if (!document.hidden) return;
      NoteUtilities.container.trigger("note:abort");
    });
  }


  // ====================== //
  //  Pass-through Methods  //
  // ====================== //

  // Pass-throughs to NoteUtilities
  static get container () { return NoteUtilities.container; }
  static get editing () { return NoteUtilities.editing; }
  static set editing (value) { NoteUtilities.editing = value; }

  static get enabled () { return NoteUtilities.visible; }
  static set enabled (value) { NoteUtilities.visible = value; }


  // ====================== //
  // ==== Persistence ===== //
  // ====================== //

  // Singleton pattern
  static _instance = null;
  static get instance () {
    if (this._instance === null)
      this._instance = new NoteManager();
    return this._instance;
  }

  // Note editor instance
  static get Editor () {
    return NoteEditor.instance;
  }
}


/**
 * Represents a single note on the image.
 * Each note has a position, size, content, and associated DOM element.
 */
class Note {

  constructor ({ id, x, y, width, height, content, html }) {
    this.id = id;
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.content = content;
    this.isTemporary = typeof id === "string" && id.startsWith("temp-");

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
    Note._noteIndex.set(id, this);
    this.$box.appendTo(NoteUtilities.container);

    // Initial scale
    this.updateScale();
    this.$box.removeClass("hidden");
  }

  backup () {
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

  restore () {
    if (!this.hasBackup) return;

    this.id = this.backupData.id;
    this.x = this.backupData.x;
    this.y = this.backupData.y;
    this.width = this.backupData.width;
    this.height = this.backupData.height;
    this.content = this.backupData.content;
    this.$body.html(this.backupData.html);

    this.updateScale();
    this.adjustBodyPosition();

    delete this.backupData;
    this.pending = false;
  }

  get hasBackup () { return typeof this.backupData !== "undefined"; }

  updateScale () {
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
  adjustBodyPosition () {
    if (!this.$box.is(":visible")) return;

    const containerDimensions = NoteUtilities.containerDimensions;
    const boxPosition = this.$box.position();
    const boxHeight = this.$box.outerHeight();

    const css = {};

    // Overflows to the right
    const bodyWidth = this.$body.outerWidth();
    if (boxPosition.left + bodyWidth > containerDimensions.width)
      css.left = `${containerDimensions.width - boxPosition.left - bodyWidth - 10}px`;

    // Overflows to the bottom
    const bodyHeight = this.$body.outerHeight();
    if (boxPosition.top + boxHeight + bodyHeight + 5 > containerDimensions.height) {
      css.top = `${-bodyHeight - 5}px`;
      css.bottom = "unset";
    }

    this.$body.css({ left: "", top: "", bottom: "" });
    this.$body.css(css);
  }

  updateIsTiny () {
    const scale = NoteUtilities.scaleRatio;
    this.$box.toggleClass("tiny", (this.width * scale < 70) || (this.height * scale < 70));
  }

  get focused () { return this.$box.hasClass("focused"); }
  set focused (value) { this.$box.toggleClass("focused", value); }
  get pending () { return this.$box.hasClass("pending"); }
  set pending (value) { this.$box.toggleClass("pending", value); }
  get editing () { return this.$box.hasClass("editing"); }
  set editing (value) { this.$box.toggleClass("editing", value); }
  get highlighted () { return this.$box.hasClass("highlighted"); }
  set highlighted (value) { this.$box.toggleClass("highlighted", value); }

  // Automatically converted attributes using container-relative coordinates
  get relX () { return Math.round(this.x * NoteUtilities.scaleRatio); }
  get relY () { return Math.round(this.y * NoteUtilities.scaleRatio); }
  get relWidth () { return Math.round(this.width * NoteUtilities.scaleRatio); }
  get relHeight () { return Math.round(this.height * NoteUtilities.scaleRatio); }


  /** Set position using container-relative coordinates */
  moveTo ({x, y}) {
    const scale = NoteUtilities.scaleRatio;
    this.x = Math.round(x / scale);
    this.y = Math.round(y / scale);
    this.$box.css({
      left: x + "px",
      top: y + "px",
    });
  }

  /** Set dimensions using container-relative coordinates */
  resizeTo ({width, height}) {
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
  adjustTo ({x, y, width, height}) {
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
  destroy () {
    this.$box.remove();
    Note._noteIndex.delete(this.id);
  }

  /** Retrieves data from saved notes and converts it into a Note instance */
  static fromStaged (stagedElement) {
    const $staged = $(stagedElement);
    const noteData = stagedElement.dataset;
    const html = $staged.html();

    return new Note({
      id: noteData.id,
      x: noteData.x,
      y: noteData.y,
      width: noteData.width,
      height: noteData.height,
      content: noteData.body,
      html: html,
    });
  }


  // ====================== //
  // ==== Note Lookup ===== //
  // ====================== //

  static _noteIndex = new Map();

  /** Returns a Note instance by its ID, or null if not found */
  static getByID (id) { return this._noteIndex.get(id) || null; }
}


class NoteEditor {

  constructor () {
    this.form = $("#note-editor");
    this.dialog = new Dialog(this.form);
    this.input = $("#note-editor-input");

    this.id = null;

    // Update note preview when the user makes changes
    this.previewTimeout = null;
    this.input.on("input.e6.note", () => {
      if (!this.id) return;

      if (!this.currentNote.hasBackup) this.currentNote.backup();
      this.currentNote.pending = true;
      this.currentNote.content = this.getInputText();

      // Wait for the user to stop typing
      if (this.previewTimeout) clearTimeout(this.previewTimeout);
      this.previewTimeout = setTimeout(() => {
        this.updatePreview();
        this.previewTimeout = null;
      }, 300);
    });

    // Save note on form submit
    this.form.on("submit.e6.note", (event) => {
      event.preventDefault();

      if (!this.id) {
        Utility.error("Error: No note is currently being edited.");
        return false;
      }

      if (this.getInputText().length == 0) {
        Utility.error("Error: Note content cannot be empty.");
        return false;
      }

      this.saveNote();
      return false;
    });

    // Cancel without saving
    this.form.find("button[name='note-cancel']").on("click.e6.note", () => { this.close(true); });

    // Close the dialog when the 'X' is clicked
    this.form.on("dialog:close", () => { this.close(false, false); });

    // Delete note
    this.form.find("button[name='note-delete']").on("click.e6.note", () => {
      if (!this.id) {
        Utility.error("Error: No note is currently being edited.");
        return false;
      }

      if (!confirm(`Are you sure you want to delete note #${this.id}? This action cannot be undone.`))
        return;

      this.deleteNote();
    });

    // Note history
    this.form.find("button[name='note-history']").on("click.e6.note", () => {
      if (!this.id) {
        Utility.error("Error: No note is currently being edited.");
        return false;
      }

      window.location.href = "/note_versions?search[note_id]=" + this.id;
    });
  }

  _currentNote = null;
  get currentNote () {
    if (!this._currentNote || this._currentNote.id !== this.id)
      this._currentNote = Note.getByID(this.id);
    return this._currentNote;
  }

  getCurrentNote () {
    if (!this.id) return null;
    return Note.getByID(this.id);
  }

  getInputText () {
    return (this.input.val() + "").trim();
  }

  /** Updates the note body preview with DText rendering */
  updatePreview () {
    const note = this.currentNote;
    if (!note) return;

    const currentText = this.getInputText();
    if (!currentText) {
      note.$body.html("");
      this.input.removeData("cache");
      return;
    }

    // Input has not changed since last time
    if (this.input.data("cache") === currentText) return;
    this.input.data("cache", currentText);

    TaskQueue.add(() => {
      $.ajax({
        type: "POST",
        url: "/dtext_preview.json",
        dataType: "json",
        data: {
          body: currentText,
          allow_color: true,
        },
        success: (response) => {
          if (this.input.data("cache") !== currentText || !this.currentNote) return;

          note.$body.html(response.html);
          if (response.posts)
            $(window).trigger("e621:add_deferred_posts", response.posts);
          note.adjustBodyPosition();
        },
        error: () => {
          // Force retry even if input hasn't changed
          this.input.removeData("cache");
        },
      });
    }, { name: "NoteEditor.updatePreview" });
  }

  /** Saves the current note */
  saveNote () {
    const note = this.currentNote;
    if (!note) return;

    const url = note.isTemporary ? "/notes.json" : `/notes/${this.id}.json`;
    const method = note.isTemporary ? "POST" : "PUT";

    const noteData = {
      x: note.x,
      y: note.y,
      width: note.width,
      height: note.height,
      body: this.getInputText(),
    };

    // Add post_id for new notes
    if (note.isTemporary) {
      const postId = $("#image-container").data("id");
      if (!postId) {
        Utility.error("Error: Could not determine post ID.");
        return;
      }
      noteData.post_id = postId;
    }

    $.ajax(url, {
      type: method,
      data: { note: noteData },
      error: (xhr) => {
        const errorMessage = xhr.responseJSON?.reasons?.join("; ") || xhr.responseJSON?.reason || "Unknown error";
        Utility.error("Error saving note: " + errorMessage);
      },
      success: (data) => {
        if (!data || !data.note || !data.dtext) {
          Utility.error("Error: Invalid response from server.");
          return;
        }

        const newData = JSON.parse(data.note);
        if (note.isTemporary) {
          // Remove the temporary note from the index
          Note._noteIndex.delete(this.id);

          // Update the note with the real ID and data from server
          // Convert to string to maintain consistency
          note.id = String(newData.id);
          note.isTemporary = false; // No longer temporary
          note.$box.attr("nid", note.id);
          this.id = note.id;

          // Add back to index with new ID
          Note._noteIndex.set(note.id, note);
        }

        // Update note properties
        note.x = newData.x;
        note.y = newData.y;
        note.width = newData.width;
        note.height = newData.height;
        note.content = newData.body;
        note.$body.html(data.dtext);
        note.updateScale();

        note.pending = false;
        if (note.hasBackup) delete note.backupData;

        if (data.posts) {
          $(window).trigger("e621:add_deferred_posts", data.posts);
        }

        this.close();
      },
    });
  }

  /** Deletes the current note */
  deleteNote () {
    const note = this.currentNote;
    if (!note) return;

    $.ajax("/notes/" + this.id + ".json", {
      type: "DELETE",
      success: () => {
        note.destroy();
        this.close();
      },
    });
  }

  /** Open the editor for a specific note */
  open (noteID) {
    if (!NoteUtilities.editing) return;
    if (!noteID) throw new Error("Note ID is required to open the editor.");

    const note = Note.getByID(noteID);
    if (!note) throw new Error(`Note with ID ${noteID} not found.`);
    this.id = noteID;

    $(".note-box.focused").removeClass("focused");
    note.focused = true;

    // Check if this is a new note being created
    const isTemporary = note.isTemporary;
    this.dialog.setTitle(isTemporary ? "Create new note" : `Edit note #${noteID}`);
    this.form.toggleClass("temporary", isTemporary);
    this.input.val(note.content || "");

    this.dialog.open();
  }

  /** Close the editor and clean up */
  close (restoreBackup = false, closeDialog = true) {
    // Check if content was changed and remove pending class if not
    if (this.id) {
      const note = Note.getByID(this.id);
      if (note) {
        // If we're closing a temporary note without saving, remove it
        if (note.isTemporary) note.destroy();
        else if (restoreBackup) note.restore();
      }
    }

    if (closeDialog) this.dialog.close();
    $(".note-box.focused").removeClass("focused");

    // Clean up editor state
    this.dialog.setTitle("");
    this.input.val("");
    this.form.removeClass("temporary");

    // Clear DText preview
    this.input.removeData("cache");
    if (this.previewTimeout) {
      clearTimeout(this.previewTimeout);
      this.previewTimeout = null;
    }

    this.id = null;
  }


  // ====================== //
  // ==== Persistence ===== //
  // ====================== //

  // Singleton pattern
  static _instance = null;
  static get instance () {
    if (this._instance === null)
      this._instance = new NoteEditor();
    return this._instance;
  }
}


/**
 * Utility class for note-related operations, such as scaling and container management.
 */
class NoteUtilities {

  // ==================== //
  // ==== Container ===== //
  // ==================== //

  static _container = null; // Container element to which notes are appended

  // Cached container properties
  static _containerDimensions = null;
  static _containerOffset = null;

  // Container states
  static _editing = false; // Editing mode is engaged
  static _visible = LStorage.Posts.Notes; // Container is visible
  static _dragging = false;
  static _resizing = false;


  /** Returns the container to which all notes are appended */
  static get container () {
    if (this._container !== null) return this._container;
    this._container = $("#note-container");

    // Load container state from storage
    this._container.attr("enabled", LStorage.Posts.Notes + "");

    // Set up ResizeObserver to track size changes
    const resizeObserver = new ResizeObserver(() => {
      this._scaleRatio = null;
      this._containerDimensions = null;
      this._containerOffset = null;
      $("#note-container .note-box").trigger("note:scale");
    });
    resizeObserver.observe(this._container[0]);

    return this._container;
  }

  static get containerDimensions () {
    if (this._containerDimensions === null)
      this._containerDimensions = {
        width: this.container.width(),
        height: this.container.height(),
      };
    return this._containerDimensions;
  }

  static get containerOffset () {
    if (this._containerOffset === null)
      this._containerOffset = this.container.offset();
    return this._containerOffset;
  }

  /** Whether the note editor is currently active */
  static toggleEditing () { this.editing = !this.editing; }
  static get editing () { return this._editing; }
  static set editing (value) {
    this._editing = value;
    this.container
      .trigger(`note:editing:${value}`)
      .attr("editing", value ? "true" : "false");

    if (value) {
      $("#mark-as-translated-section").show();
    } else {
      $("#mark-as-translated-section").hide();
      NoteEditor.instance.close();
      this.container.trigger("note:abort");
    }
  }

  /** Whether the note container is visible */
  static get visible () { return this._visible; }
  static set visible (value) {
    this._visible = value;
    LStorage.Posts.Notes = value;
    NoteUtilities.container
      .attr("enabled", value)
      .trigger(`note:visible:${value}`);

    // Cannot scale note bodies if notes are hidden
    if (value) $("#note-container .note-box").trigger("note:scale");
  }

  /** Whether a note is currently being moved, resized, or drawn */
  static get dragging () { return this._dragging; }
  static set dragging (value) {
    this._dragging = value;
    this.container.attr("dragging", value ? "true" : "false");
  }

  static get resizing () { return this._resizing; }
  static set resizing (value) {
    this._resizing = value;
    this.container.attr("resizing", value ? "true" : "false");
  }

  // ==================== //
  // ==== Scaling ======= //
  // ==================== //

  static _scaleRatio = null;
  static _originalImageWidth = null;
  static _originalImageHeight = null;

  /** Returns the ratio between the current container size and that of the original image */
  static get scaleRatio () {
    if (this._scaleRatio !== null) return this._scaleRatio;

    if (!this._originalImageWidth) {
      const $image = $("#image-container");
      this._originalImageWidth = parseFloat($image.data("width")) || 1;
      this._originalImageHeight = parseFloat($image.data("height")) || 1;
    }

    this._scaleRatio = this.container.width() / this._originalImageWidth;
    return this._scaleRatio;
  }

  /** Returns the minimum width of a note in container coordinates */
  static get noteMinWidth () {
    return Math.round(20 * NoteUtilities.scaleRatio);
  }
}


$(() => { NoteManager.instance; });
