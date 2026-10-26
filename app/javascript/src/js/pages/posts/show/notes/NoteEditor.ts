import Dialog from "@/utility/dialog";
import HTTP from "@/utility/HTTP";
import TaskQueue from "@/utility/TaskQueue";
import ToastManager from "@/utility/Toast";
import Note from "@/pages/posts/show/notes/Note";
import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import { DTextPreviewResponse, NoteErrorResponse, NoteSaveResponse, NoteServerAttributes } from "@/pages/posts/show/notes/Types";

/**
 * The note editing dialog: edits the body of a single note, previews it as
 * DText, and persists create / update / delete requests.
 */
export default class NoteEditor {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: NoteEditor | null = null;
  public static get instance (): NoteEditor {
    if (!NoteEditor._instance)
      NoteEditor._instance = new NoteEditor();
    return NoteEditor._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private form: JQuery<HTMLElement>;
  private dialog: Dialog;
  private input: JQuery<HTMLElement>;

  /** ID of the note currently being edited */
  public id: string | null = null;

  private previewTimeout: ReturnType<typeof setTimeout> | null = null;

  private constructor () {
    if (NoteEditor._instance)
      throw new Error("NoteEditor is a singleton class. Use NoteEditor.instance to access the instance.");

    this.form = $("#note-editor");
    this.dialog = new Dialog(this.form);
    this.input = $("#note-editor-input");

    // Update note preview when the user makes changes
    this.input.on("input.e6.note", () => {
      const note = this.currentNote;
      if (!note) return;

      if (!note.hasBackup) note.backup();
      note.pending = true;
      note.content = this.getInputText();

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
        ToastManager.alert("Error: No note is currently being edited.");
        return false;
      }

      if (this.getInputText().length == 0) {
        ToastManager.alert("Error: Note content cannot be empty.");
        return false;
      }

      if (this.saving) return false;

      this.saveNote();
      return false;
    });

    // Cancel without saving
    this.form.find("button[name='note-cancel']").on("click.e6.note", () => { this.close(true); });

    // Close the dialog when the 'X' is clicked
    this.form.on("dialog:close", () => { this.close(true, false); });

    // Leaving editing mode closes the editor
    NoteUtilities.container.on("note:editing:false", () => { this.close(true); });

    // Delete note
    this.form.find("button[name='note-delete']").on("click.e6.note", () => {
      if (!this.id) {
        ToastManager.alert("Error: No note is currently being edited.");
        return;
      }

      if (!confirm(`Are you sure you want to delete note #${this.id}? This action cannot be undone.`))
        return;

      if (this.saving) return;

      this.deleteNote();
    });

    // Note history
    this.form.find("button[name='note-history']").on("click.e6.note", () => {
      if (!this.id) {
        ToastManager.alert("Error: No note is currently being edited.");
        return;
      }

      window.location.href = "/note_versions?search[note_id]=" + this.id;
    });
  }


  /* ============================== */
  /* =========== State ============ */
  /* ============================== */

  private _currentNote: Note | null = null;
  public get currentNote (): Note | null {
    if (!this._currentNote || this._currentNote.id !== this.id)
      this._currentNote = Note.getByID(this.id);
    return this._currentNote;
  }

  private _saving = false;
  public get saving (): boolean { return this._saving; }
  public set saving (value: boolean) {
    this._saving = value;
    this.form.find("button[type='submit']").prop("disabled", value);
    this.form.find("button[name='note-delete']").prop("disabled", value || !!this.currentNote?.isTemporary);
  }

  private getInputText (): string {
    return String(this.input.val() ?? "").trim();
  }


  /* ============================== */
  /* ========== Requests ========== */
  /* ============================== */

  /** Updates the note body preview with DText rendering */
  public updatePreview (): void {
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

    TaskQueue.add(async () => {
      const body = new URLSearchParams({ body: currentText, allow_color: "true" });
      try {
        const response = await HTTP.postJSON<DTextPreviewResponse>("/dtext_preview.json", body);
        if (this.input.data("cache") !== currentText || !this.currentNote) return;

        note.$body.html(response.html);
        if (response.posts)
          $(window).trigger("e621:add_deferred_posts", response.posts);
        note.adjustBodyPosition();
      } catch {
        // Force retry even if input hasn't changed
        this.input.removeData("cache");
      }
    }, { name: "NoteEditor.updatePreview" });
  }

  /** Saves the current note */
  public async saveNote (): Promise<void> {
    const note = this.currentNote;
    if (!note) return;

    this.saving = true;

    const url = note.isTemporary ? "/notes.json" : `/notes/${this.id}.json`;
    const method = note.isTemporary ? "POST" : "PUT";

    const body = new URLSearchParams({
      "note[x]": String(note.x),
      "note[y]": String(note.y),
      "note[width]": String(note.width),
      "note[height]": String(note.height),
      "note[body]": this.getInputText(),
    });

    // Add post_id for new notes
    if (note.isTemporary) {
      const postId = $("#image-container").attr("data-id");
      if (!postId) {
        ToastManager.alert("Error: Could not determine post ID.");
        this.saving = false;
        return;
      }
      body.set("note[post_id]", postId);
    }

    let response: Response;
    try {
      response = await HTTP.request(url, { method, body });
    } catch {
      this.saving = false;
      ToastManager.alert("Error saving note: Unknown error");
      return;
    }

    if (!response.ok) {
      this.saving = false;
      ToastManager.alert("Error saving note: " + await NoteEditor.errorMessage(response));
      return;
    }

    const data = await response.json().catch(() => null) as NoteSaveResponse | null;
    if (!data || !data.note || !data.dtext) {
      ToastManager.alert("Error: Invalid response from server.");
      this.saving = false;
      return;
    }

    // The server double-encodes the note attributes
    const attrs = JSON.parse(data.note) as NoteServerAttributes;
    note.applyServerData(attrs, data.dtext);
    this.id = note.id;

    if (data.posts)
      $(window).trigger("e621:add_deferred_posts", data.posts);

    this.saving = false;
    this.close();
  }

  /** Deletes the current note */
  public async deleteNote (): Promise<void> {
    const note = this.currentNote;
    if (!note) return;

    this.saving = true;

    let response: Response;
    try {
      response = await HTTP.request(`/notes/${this.id}.json`, { method: "DELETE" });
    } catch {
      this.saving = false;
      ToastManager.alert("Error deleting note: Unknown error");
      return;
    }

    if (!response.ok) {
      this.saving = false;
      ToastManager.alert("Error deleting note: " + await NoteEditor.errorMessage(response));
      return;
    }

    note.destroy();
    this.saving = false;
    this.close();
  }

  private static async errorMessage (response: Response): Promise<string> {
    try {
      const json = await response.json() as NoteErrorResponse;
      return json.reasons?.join("; ") || json.reason || "Unknown error";
    } catch {
      return "Unknown error";
    }
  }


  /* ============================== */
  /* ======== Open / Close ======== */
  /* ============================== */

  /** Open the editor for a specific note */
  public open (noteID: string): void {
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

    this.saving = false;
    this.dialog.open();
  }

  /**
   * Close the editor and clean up.
   * @param restoreBackup Revert unsaved changes to the note's geometry and content
   * @param closeDialog Hide the dialog; false when the dialog is already closing itself
   */
  public close (restoreBackup = false, closeDialog = true): void {
    const note = Note.getByID(this.id);
    if (note) {
      // If we're closing a temporary note without saving, remove it
      if (note.isTemporary) note.destroy();
      else if (restoreBackup) note.restore();
    }

    // Quiet close: the dialog's own `dialog:close` event would re-enter this method
    if (closeDialog) this.dialog.close(true);
    $(".note-box.focused").removeClass("focused");

    // Clean up editor state
    this.id = null;
    this.saving = false;
    this.dialog.setTitle("");
    this.input.val("");
    this.form.removeClass("temporary");

    // Clear DText preview
    this.input.removeData("cache");
    if (this.previewTimeout) {
      clearTimeout(this.previewTimeout);
      this.previewTimeout = null;
    }
  }
}
