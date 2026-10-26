import CurrentUser from "@/models/CurrentUser";
import Note from "@/pages/posts/show/notes/Note";
import NoteEditor from "@/pages/posts/show/notes/NoteEditor";
import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";
import NoteAbortEvents from "@/pages/posts/show/notes/interactions/NoteAbortEvents";
import NoteDrawing from "@/pages/posts/show/notes/interactions/NoteDrawing";
import NoteMoving from "@/pages/posts/show/notes/interactions/NoteMoving";
import NoteResizing from "@/pages/posts/show/notes/interactions/NoteResizing";

/**
 * Entry point for the posts#show note overlay.
 * Loads the server-rendered notes, handles hash highlighting, and (for members)
 * wires up the editing mode toggles and drag interactions.
 * Exposed as `E621.Note`, so the static API below is public.
 */
export default class NoteManager {

  public static readonly PermittedFileTypes = ["jpg", "png", "gif", "webp"];

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: NoteManager | null = null;
  public static get instance (): NoteManager {
    if (!NoteManager._instance)
      NoteManager._instance = new NoteManager();
    return NoteManager._instance;
  }

  /** The note editor dialog */
  public static get Editor (): NoteEditor {
    return NoteEditor.instance;
  }

  // Pass-throughs to NoteUtilities
  public static get container (): JQuery<HTMLElement> { return NoteUtilities.container; }
  public static get editing (): boolean { return NoteUtilities.editing; }
  public static set editing (value: boolean) { NoteUtilities.editing = value; }
  public static get enabled (): boolean { return NoteUtilities.visible; }
  public static set enabled (value: boolean) { NoteUtilities.visible = value; }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (NoteManager._instance)
      throw new Error("NoteManager is a singleton class. Use NoteManager.instance to access the instance.");

    const imageContainer = $("#image-container");
    if (imageContainer.length == 0) return;
    if (!NoteManager.PermittedFileTypes.includes(imageContainer.attr("data-file-ext") || "")) return;

    // Load notes from the staging area.
    // Note bodies may contain rendered DText thumbnails, so the selector has to be precise
    $("#note-staging > article.staged-note").each((_, element) => { Note.fromStaged(element); });

    // Highlight notes based on URL hash
    this.highlightHashNotes();
    $(window).on("hashchange.e6.note", () => this.highlightHashNotes());

    if (!CurrentUser.is.member) return;

    const container = NoteUtilities.container;

    // Open editor when a note is double-clicked
    container.on("dblclick.e6.note", ".note-box", (event) => {
      if (NoteUtilities.editing) return;
      event.preventDefault();
      event.stopPropagation();

      const noteID = $(event.currentTarget).attr("nid");
      if (!noteID) return;

      NoteUtilities.editing = true;
      NoteEditor.instance.open(noteID);
    });

    // Switch to note editing mode when the "Edit Notes" button is clicked
    $("#translate").on("click.e6.note", (event) => {
      event.preventDefault();
      NoteUtilities.toggleEditing();

      if (NoteUtilities.editing) {
        $("html, body").animate({ scrollTop: NoteUtilities.containerOffset.y }, 200);
        NoteUtilities.visible = true;
      }
    });

    $("#translation-cancel").on("click.e6.note", (event) => {
      event.preventDefault();
      NoteUtilities.editing = false;
    });

    // Initialize interactivity once editing is enabled for the first time
    container.one("note:editing:true", () => {
      const editor = NoteEditor.instance; // Binds the editor's own `note:editing:false` listener

      // Open the editor when a note body is clicked
      container.on("click.e6.note", ".note-body", (event) => {
        if (!NoteUtilities.editing) return;
        event.preventDefault();
        event.stopPropagation();

        const noteID = $(event.currentTarget).parents(".note-box").attr("nid");
        if (!noteID) return;

        editor.open(noteID);
      });

      // A touch long press would otherwise open the context menu
      container.on("contextmenu.e6.note", (event) => {
        if (NoteUtilities.editing) event.preventDefault();
      });

      new NoteDrawing();
      new NoteResizing();
      new NoteMoving();
      new NoteAbortEvents();
    });
  }


  /* ============================== */
  /* ======== Highlighting ======== */
  /* ============================== */

  private highlightHashNotes (): void {
    $(".note-box.highlighted").removeClass("highlighted");

    const anchorMatch = window.location.hash.match(/^#note-(\d+)$/);
    if (!anchorMatch) return;
    const note = Note.getByID(anchorMatch[1]);
    if (!note) return;

    note.highlighted = true;
    note.$box[0].scrollIntoView({ behavior: "smooth", block: "center" });
  }
}

$(() => { void NoteManager.instance; });
