import Utility from "./utility.js";
import Dialog from "./utility/dialog";

export default class NoteManager {

  /** Initialize the manager and load existing notes from the staging area. */
  constructor () {
    $("#note-staging article").each((_, note) => { Note.fromStaged(note); });

    // Switch to note editing mode when the "Edit Notes" button is clicked
    $("#translate").on("click", (event) => {
      event.preventDefault();
      NoteUtilities.toggleEditing();

      if (NoteUtilities.editing)
        $("html, body").animate({ scrollTop: NoteUtilities.containerOffset.top }, 200);
    });

    // Listen to clicks on note bodies
    $("#note-container").on("click", ".note-body", (event) => {
      if (!NoteUtilities.editing) return;
      event.preventDefault();
      event.stopPropagation();

      const box = $(event.currentTarget).parents(".note-box");
      if (box.length == 0) return;
      const noteID = box.attr("nid");
      if (!noteID) return;

      NoteManager.Editor.open(noteID);
    });

    // Set up interactivity
    this.handleNoteDrawing();
    this.handleNoteResizing();
    this.handleNoteMoving();
  }


  // ====================== //
  // ==== Note Drawing ==== //
  // ====================== //

  handleNoteDrawing () {

    let isDrawing = false;
    let startX = 0;
    let startY = 0;
    let $drawingNote = null;
    let drawingNoteId = null;
    let mouseMoveThrottleId = null;

    // Initial click to start drawing
    $("#note-container").on("mousedown", (event) => {
      if (!NoteUtilities.editing) return;

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

      $drawingNote.containerX = startX;
      $drawingNote.containerY = startY;
      $drawingNote.updateScale();

      $drawingNote.$box.addClass("editing");
    });

    // Mousemove to update the drawing
    $("#note-container").on("mousemove", (event) => {
      if (!isDrawing || !$drawingNote) return;

      event.preventDefault();

      // Throttle mousemove events
      if (mouseMoveThrottleId) cancelAnimationFrame(mouseMoveThrottleId);

      mouseMoveThrottleId = requestAnimationFrame(() => {
        const currentX = event.pageX - NoteUtilities.containerOffset.left;
        const currentY = event.pageY - NoteUtilities.containerOffset.top;

        // Update the note dimensions
        $drawingNote.containerX = Math.min(startX, currentX);
        $drawingNote.containerY = Math.min(startY, currentY);
        $drawingNote.containerWidth = Math.abs(currentX - startX);
        $drawingNote.containerHeight = Math.abs(currentY - startY);
        $drawingNote.updateScale();
      });
    });

    // Mouseup to finalize the drawing
    $("#note-container").on("mouseup", (event) => {
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
      if (width >= 20 && height >= 20) {
        $drawingNote.containerX = Math.min(startX, endX);
        $drawingNote.containerY = Math.min(startY, endY);
        $drawingNote.containerWidth = width;
        $drawingNote.containerHeight = height;
        $drawingNote.updateScale();

        $drawingNote.$box.removeClass("editing");
        NoteManager.Editor.open(drawingNoteId);

        $drawingNote = null;
        drawingNoteId = null;
      } else {
        $drawingNote.destroy();
        $drawingNote = null;
        drawingNoteId = null;
      }
    });

    // Abort if mouse leaves the container
    $("#note-container").on("mouseleave", () => {
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
    });

  }


  // ====================== //
  // ==== Note Resizing === //
  // ====================== //

  handleNoteResizing () {

    // Handle note resizing
    let isResizing = false;
    let resizeHandle = null; // 'nw' or 'se'
    let $resizingNote = null;
    let resizeStartX = 0;
    let resizeStartY = 0;
    let resizeOriginalBounds = null;
    let resizeThrottleId = null;

    // Mousedown to start resizing
    $("#note-container").on("mousedown", ".note-handle", (event) => {
      if (!NoteUtilities.editing) return;

      event.preventDefault();
      event.stopPropagation();

      const $handle = $(event.currentTarget);
      const $noteBox = $handle.closest(".note-box");
      const noteId = $noteBox.attr("nid");
      const note = Note.getByID(noteId);

      if (!note) return;

      isResizing = true;
      $resizingNote = note;
      resizeHandle = $handle.hasClass("note-handle-nw") ? "nw" : "se";

      resizeStartX = event.pageX - NoteUtilities.containerOffset.left;
      resizeStartY = event.pageY - NoteUtilities.containerOffset.top;

      // Store original bounds in container coordinates
      resizeOriginalBounds = {
        x: NoteUtilities.scaleDown(note.x),
        y: NoteUtilities.scaleDown(note.y),
        width: NoteUtilities.scaleDown(note.width),
        height: NoteUtilities.scaleDown(note.height),
      };

      $noteBox.addClass("editing pending");
    });

    // Mousemove to resize the note
    $("#note-container").on("mousemove", (event) => {
      if (!isResizing || !$resizingNote) return;

      event.preventDefault();

      // Throttle resize events
      if (resizeThrottleId) {
        cancelAnimationFrame(resizeThrottleId);
      }

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

        // Enforce minimum dimensions (20x20 pixels in container coordinates)
        const minSize = 20;
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
        $resizingNote.containerX = newX;
        $resizingNote.containerY = newY;
        $resizingNote.containerWidth = newWidth;
        $resizingNote.containerHeight = newHeight;
        $resizingNote.updateScale();
      });
    });

    // Mouseup to finalize resizing
    $("#note-container").on("mouseup", (event) => {
      // Handle note resizing
      if (!isResizing || !$resizingNote) return;

      event.preventDefault();
      event.stopPropagation();

      // Clean up resizing state
      isResizing = false;

      // Cancel any pending animation frame
      if (resizeThrottleId) {
        cancelAnimationFrame(resizeThrottleId);
        resizeThrottleId = null;
      }

      // Remove visual feedback
      $resizingNote.$box.removeClass("editing");

      // Open the note editor to let user save when ready
      NoteManager.Editor.open($resizingNote.id);

      // Clean up resizing state
      $resizingNote = null;
      resizeHandle = null;
      resizeOriginalBounds = null;
    });

    // Abort if mouse leaves the container
    $("#note-container").on("mouseleave", () => {
      if (!isResizing || !$resizingNote) return;

      // Cancel resize operation and revert to original bounds
      if (resizeOriginalBounds) {
        $resizingNote.containerX = resizeOriginalBounds.x;
        $resizingNote.containerY = resizeOriginalBounds.y;
        $resizingNote.containerWidth = resizeOriginalBounds.width;
        $resizingNote.containerHeight = resizeOriginalBounds.height;
        $resizingNote.updateScale();
      }

      // Clean up resizing state
      $resizingNote.$box.removeClass("editing");
      isResizing = false;
      $resizingNote = null;
      resizeHandle = null;
      resizeOriginalBounds = null;

      // Cancel any pending animation frame
      if (resizeThrottleId) {
        cancelAnimationFrame(resizeThrottleId);
        resizeThrottleId = null;
      }
    });
  }


  // ====================== //
  // ===== Note Moving ==== //
  // ====================== //

  handleNoteMoving () {

    let isMoving = false;
    let $movingNote = null;
    let moveStartX = 0;
    let moveStartY = 0;
    let moveOriginalPosition = null;
    let moveThrottleId = null;

    $("#note-container").on("mousedown", ".note-box", (event) => {
      if (!NoteUtilities.editing) return;

      // Don't start moving if clicking on a handle (those are for resizing)
      const $target = $(event.target);
      if ($target.hasClass("note-handle") || $target.closest(".note-handle").length > 0) return;

      // Don't start moving if clicking on the note body (that opens the editor)
      if ($target.hasClass("note-body") || $target.closest(".note-body").length > 0) return;

      event.preventDefault();
      event.stopPropagation();

      const $noteBox = $(event.currentTarget);
      const noteId = $noteBox.attr("nid");
      const note = Note.getByID(noteId);

      if (!note) return;

      isMoving = true;
      $movingNote = note;

      moveStartX = event.pageX - NoteUtilities.containerOffset.left;
      moveStartY = event.pageY - NoteUtilities.containerOffset.top;

      // Store original position in container coordinates
      moveOriginalPosition = {
        x: note.containerX,
        y: note.containerY,
      };

      // Add visual feedback
      $noteBox.addClass("editing pending");
      $("#note-container").addClass("note-dragging");
    });

    // Handle mousemove for note moving
    $("#note-container").on("mousemove", (event) => {
      if (!isMoving || !$movingNote) return;

      event.preventDefault();

      // Throttle move events
      if (moveThrottleId) {
        cancelAnimationFrame(moveThrottleId);
      }

      moveThrottleId = requestAnimationFrame(() => {
        const currentX = event.pageX - NoteUtilities.containerOffset.left;
        const currentY = event.pageY - NoteUtilities.containerOffset.top;

        const deltaX = currentX - moveStartX;
        const deltaY = currentY - moveStartY;

        const newX = moveOriginalPosition.x + deltaX;
        const newY = moveOriginalPosition.y + deltaY;

        // Keep the note within the container bounds
        const clampedX = Math.max(0, Math.min(newX, NoteUtilities.containerDimensions.width - $movingNote.containerWidth));
        const clampedY = Math.max(0, Math.min(newY, NoteUtilities.containerDimensions.height - $movingNote.containerHeight));

        // Update the note's position
        $movingNote.containerX = clampedX;
        $movingNote.containerY = clampedY;
        $movingNote.updateScale();
      });
    });

    // Handle mouseup for note moving
    $("#note-container").on("mouseup", (event) => {
      if (!isMoving || !$movingNote) return;

      event.preventDefault();
      event.stopPropagation();

      // Clean up moving state
      isMoving = false;

      // Cancel any pending animation frame
      if (moveThrottleId) {
        cancelAnimationFrame(moveThrottleId);
        moveThrottleId = null;
      }

      // Remove visual feedback
      $movingNote.$box.removeClass("editing");
      $("#note-container").removeClass("note-dragging");

      // Open the note editor to let user save the new position
      NoteManager.Editor.open($movingNote.id);

      // Clean up moving state
      $movingNote = null;
      moveOriginalPosition = null;
    });

    // Handle mouse leave to cancel moving
    $("#note-container").on("mouseleave", () => {
      if (!isMoving || !$movingNote) return;

      // Cancel move operation and revert to original position
      if (moveOriginalPosition) {
        $movingNote.containerX = moveOriginalPosition.x;
        $movingNote.containerY = moveOriginalPosition.y;
        $movingNote.updateScale();
      }

      // Clean up moving state
      $movingNote.$box.removeClass("editing");
      $("#note-container").removeClass("note-dragging");
      isMoving = false;
      $movingNote = null;
      moveOriginalPosition = null;

      // Cancel any pending animation frame
      if (moveThrottleId) {
        cancelAnimationFrame(moveThrottleId);
        moveThrottleId = null;
      }
    });
  }


  // ====================== //
  //  Pass-through Methods  //
  // ====================== //

  static updateScale () {
    // This may no longer be necessary, since ResizeObserver
    // is used to automatically track size changes.
    return true;
  }

  // Pass-throughs to NoteUtilities
  static get container () { return NoteUtilities.container; }
  static get editing () { return NoteUtilities.editing; }
  static set editing (value) { NoteUtilities.editing = value; }


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
      .on("note:scale", () => {
        this.updateScale();
      });

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
    Note._noteIndex[id] = this;
    this.$box.appendTo(NoteUtilities.container);

    // Initial scale
    this.updateScale();
    this.$box.removeClass("hidden");
  }

  updateScale () {
    this.$box.css({
      width: `${NoteUtilities.scaleDown(this.width)}px`,
      height: `${NoteUtilities.scaleDown(this.height)}px`,
      left: `${NoteUtilities.scaleDown(this.x)}px`,
      top: `${NoteUtilities.scaleDown(this.y)}px`,
    });
  }

  get focused () { return this.$box.hasClass("focused"); }
  set focused (value) { this.$box.toggleClass("focused", value); }


  // Set attributes using container-relative coordinates
  set containerX (value) { this.x = NoteUtilities.scaleUp(value); }
  set containerY (value) { this.y = NoteUtilities.scaleUp(value); }
  set containerWidth (value) { this.width = Math.max(1, NoteUtilities.scaleUp(value)); }
  set containerHeight (value) { this.height = Math.max(1, NoteUtilities.scaleUp(value)); }
  get containerX () { return NoteUtilities.scaleDown(this.x); }
  get containerY () { return NoteUtilities.scaleDown(this.y); }
  get containerWidth () { return NoteUtilities.scaleDown(this.width); }
  get containerHeight () { return NoteUtilities.scaleDown(this.height); }

  /** Set position using container-relative coordinates */
  setContainerPosition (x, y) {
    this.x = NoteUtilities.scaleUp(x);
    this.y = NoteUtilities.scaleUp(y);
  }

  /** Set dimensions using container-relative coordinates */
  setContainerDimensions (width, height) {
    this.width = Math.max(1, NoteUtilities.scaleUp(width));
    this.height = Math.max(1, NoteUtilities.scaleUp(height));
  }

  /** Set both position and dimensions using container-relative coordinates */
  setContainerBounds (x, y, width, height) {
    this.setContainerPosition(x, y);
    this.setContainerDimensions(width, height);
  }

  destroy () {
    this.$box.remove();
    delete Note._noteIndex[this.id];
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

  static _noteIndex = {};

  /** Returns a Note instance by its ID, or null if not found */
  static getByID (id) { return this._noteIndex[id] || null; }
}


class NoteEditor {

  constructor () {
    this.form = $("#note-editor");
    this.dialog = new Dialog(this.form);
    this.input = $("#note-editor-input");

    this.id = null;

    // Mark note as pending when user starts typing
    this.input.on("input", () => {
      this.currentNote?.$box.addClass("pending");
    });

    // Save note on form submit
    this.form.on("submit", (event) => {
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
    this.form.find("button[name='note-cancel']").on("click", () => { this.close(); });

    // Close the dialog when the 'X' is clicked
    this.form.on("dialog:close", () => { this.close(true); });

    // Delete note
    this.form.find("button[name='note-delete']").on("click", () => {
      if (!this.id) {
        Utility.error("Error: No note is currently being edited.");
        return false;
      }

      if (!confirm(`Are you sure you want to delete note #${this.id}? This action cannot be undone.`))
        return;

      this.deleteNote();
    });

    // Note history
    this.form.find("button[name='note-history']").on("click", () => {
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
          delete Note._noteIndex[this.id];

          // Update the note with the real ID and data from server
          // Convert to string to maintain consistency
          note.id = String(newData.id);
          note.isTemporary = false; // No longer temporary
          note.$box.attr("nid", note.id);
          this.id = note.id;

          // Add back to index with new ID
          Note._noteIndex[note.id] = note;
        }

        // Update note properties
        note.x = newData.x;
        note.y = newData.y;
        note.width = newData.width;
        note.height = newData.height;
        note.content = newData.body;
        note.$body.html(data.dtext);
        note.updateScale();

        // Remove pending changes indicator
        note.$element.removeClass("pending");

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

    // Check if this is a temporary note (needs to be created)
    const isTemporary = note.isTemporary;
    this.dialog.setTitle(isTemporary ? "Create new note" : `Edit note #${noteID}`);
    this.input.val(note.content || "");

    // Add class to form to indicate temporary note
    this.form.toggleClass("note-temporary", isTemporary);

    this.dialog.open();
  }

  /** Close the editor and clean up */
  close (onClose = false) {
    // Check if content was changed and remove pending class if not
    if (this.id) {
      const note = Note.getByID(this.id);
      if (note) {
        // If we're closing a temporary note without saving, remove it
        if (note.isTemporary) {
          note.destroy();
        }
      }
    }

    if (!onClose) this.dialog.close();
    $(".note-box.focused").removeClass("focused");

    // Clean up editor state
    this.dialog.setTitle("");
    this.input.val("");
    this.id = null;

    // Remove temporary class
    this.form.removeClass("note-temporary");
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

  static _container = null;
  static _containerDimensions = null;
  static _containerOffset = null;
  static _editing = false;

  /** Returns the container to which all notes are appended */
  static get container () {
    if (this._container !== null) return this._container;
    this._container = $("#note-container");

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
    this.container.attr("editing", value ? "true" : "false");
    if (value) {
      $("#mark-as-translated-section").show();
    } else {
      $("#mark-as-translated-section").hide();
      NoteEditor.instance.close();
    }
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

  static scaleDown (value) {
    return Math.round(value * this.scaleRatio);
  }

  static scaleUp (value) {
    return Math.round(value / this.scaleRatio);
  }
}


$(() => { NoteManager.instance; });
