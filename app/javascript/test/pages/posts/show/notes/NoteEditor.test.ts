import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse } from "../../../../helpers";
import { POST_ID, SAMPLE_NOTE, loadNoteManager, renderNotesPage, stubGeometry } from "./fixtures";

const dialog = { open: vi.fn(), close: vi.fn(), setTitle: vi.fn() };
vi.mock("@/utility/dialog", () => ({
  default: class {
    open = dialog.open;
    close = dialog.close;
    setTitle = dialog.setTitle;
  },
}));

const alertSpy = vi.fn();
vi.mock("@/utility/Toast", () => ({ default: { alert: (message: string) => alertSpy(message), create: vi.fn() } }));

// Run queued tasks immediately; the queue's own pacing is covered elsewhere
vi.mock("@/utility/TaskQueue", () => ({ default: { add: (task: () => unknown) => Promise.resolve().then(task) } }));

const SERVER_NOTE = { id: 7, post_id: POST_ID, x: 200, y: 200, width: 400, height: 200, body: "hello" };

async function loadEditing () {
  const loaded = await loadNoteManager();
  loaded.NoteManager.editing = true;
  return { ...loaded, editor: loaded.NoteManager.Editor, note: loaded.Note.getByID("7")! };
}

function submit () {
  $("#note-editor").trigger("submit");
}

function lastRequest (fetchSpy: ReturnType<typeof vi.fn>) {
  const [url, init] = fetchSpy.mock.calls[fetchSpy.mock.calls.length - 1];
  return { url: String(url), method: init?.method, body: new URLSearchParams(String(init?.body ?? "")) };
}

describe("NoteEditor", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    dialog.open.mockReset();
    dialog.close.mockReset();
    dialog.setTitle.mockReset();
    alertSpy.mockReset();
    renderNotesPage({ notes: [SAMPLE_NOTE] });
    stubGeometry();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe("open", () => {
    it("ignores requests outside of editing mode", async () => {
      const { NoteManager } = await loadNoteManager();
      NoteManager.Editor.open("7");
      expect(NoteManager.Editor.id).toBeNull();
      expect(dialog.open).not.toHaveBeenCalled();
    });

    it("loads the note into the form and focuses it", async () => {
      const { editor, note } = await loadEditing();
      editor.open("7");

      expect(editor.id).toBe("7");
      expect(editor.currentNote).toBe(note);
      expect(note.focused).toBe(true);
      expect(dialog.setTitle).toHaveBeenCalledWith("Edit note #7");
      expect($("#note-editor").hasClass("temporary")).toBe(false);
      expect($("#note-editor-input").val()).toBe("hello");
      expect($("button[name='note-delete']").prop("disabled")).toBe(false);
      expect(dialog.open).toHaveBeenCalledTimes(1);
    });

    it("presents temporary notes as new and disables delete", async () => {
      const { editor, Note } = await loadEditing();
      const temp = Note.createTemporary();
      editor.open(temp.id);

      expect(dialog.setTitle).toHaveBeenCalledWith("Create new note");
      expect($("#note-editor").hasClass("temporary")).toBe(true);
      expect($("button[name='note-delete']").prop("disabled")).toBe(true);
    });

    it("throws for unknown notes", async () => {
      const { editor } = await loadEditing();
      expect(() => editor.open("999")).toThrow("Note with ID 999 not found.");
    });
  });

  describe("preview", () => {
    it("debounces input and renders the DText preview", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ html: "<p>new <b>text</b></p>", posts: { 1: {} } }));
      const deferred = vi.fn();
      $(window).on("e621:add_deferred_posts", deferred);
      const { editor, note } = await loadEditing();
      editor.open("7");

      $("#note-editor-input").val("new text").trigger("input");
      expect(note.pending).toBe(true);
      expect(note.hasBackup).toBe(true);
      expect(note.content).toBe("new text");
      expect(fetchSpy).not.toHaveBeenCalled();

      await vi.advanceTimersByTimeAsync(300);
      await vi.waitFor(() => expect(note.$body.html()).toBe("<p>new <b>text</b></p>"));

      const { url, method, body } = lastRequest(fetchSpy);
      expect(url).toBe("/dtext_preview.json");
      expect(method).toBe("POST");
      expect(body.get("body")).toBe("new text");
      expect(body.get("allow_color")).toBe("true");
      expect(deferred).toHaveBeenCalledTimes(1);
    });

    it("clears the preview when the input is emptied", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch");
      const { editor, note } = await loadEditing();
      editor.open("7");

      $("#note-editor-input").val("   ").trigger("input");
      await vi.advanceTimersByTimeAsync(300);
      expect(note.$body.html()).toBe("");
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });

  describe("save", () => {
    it("refuses to save an empty note", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch");
      const { editor } = await loadEditing();
      editor.open("7");

      $("#note-editor-input").val("");
      submit();
      expect(alertSpy).toHaveBeenCalledWith("Error: Note content cannot be empty.");
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it("updates an existing note and applies the server response", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({
        note: JSON.stringify({ ...SERVER_NOTE, x: 210, body: "edited" }),
        dtext: "<p>edited</p>",
        posts: {},
      }));
      const { editor, note } = await loadEditing();
      editor.open("7");
      note.moveTo({ x: 105, y: 100 });
      note.pending = true;

      $("#note-editor-input").val("edited");
      submit();
      await vi.waitFor(() => expect(editor.id).toBeNull());

      const { url, method, body } = lastRequest(fetchSpy);
      expect(url).toBe("/notes/7.json");
      expect(method).toBe("PUT");
      expect(body.get("note[x]")).toBe("210");
      expect(body.get("note[y]")).toBe("200");
      expect(body.get("note[width]")).toBe("400");
      expect(body.get("note[body]")).toBe("edited");
      expect(body.has("note[post_id]")).toBe(false);

      expect(note.content).toBe("edited");
      expect(note.$body.html()).toBe("<p>edited</p>");
      expect(note.pending).toBe(false);
      expect(note.focused).toBe(false);
      expect(dialog.close).toHaveBeenCalledWith(true);
      expect($("#note-editor-input").val()).toBe("");
    });

    it("creates a temporary note and re-keys it with the server id", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({
        note: JSON.stringify({ ...SERVER_NOTE, id: 99, x: 10, y: 20, width: 30, height: 40, body: "fresh" }),
        dtext: "<p>fresh</p>",
      }));
      const { editor, Note } = await loadEditing();
      const temp = Note.createTemporary();
      temp.adjustTo({ x: 5, y: 10, width: 15, height: 20 });
      editor.open(temp.id);

      $("#note-editor-input").val("fresh");
      submit();
      await vi.waitFor(() => expect(editor.id).toBeNull());

      const { url, method, body } = lastRequest(fetchSpy);
      expect(url).toBe("/notes.json");
      expect(method).toBe("POST");
      expect(body.get("note[post_id]")).toBe(String(POST_ID));
      expect(body.get("note[x]")).toBe("10");
      expect(body.get("note[width]")).toBe("30");

      expect(temp.id).toBe("99");
      expect(temp.isTemporary).toBe(false);
      expect(Note.getByID("99")).toBe(temp);
      expect(temp.$box.attr("nid")).toBe("99");
      expect(document.querySelectorAll(".note-box").length).toBe(2);
    });

    it("reports validation errors and keeps the editor open", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ success: false, reasons: ["Body is too long", "X is invalid"] }, { status: 422 }));
      const { editor, note } = await loadEditing();
      editor.open("7");

      $("#note-editor-input").val("edited");
      submit();
      await vi.waitFor(() => expect(alertSpy).toHaveBeenCalled());

      expect(alertSpy).toHaveBeenCalledWith("Error saving note: Body is too long; X is invalid");
      expect(editor.id).toBe("7");
      expect(editor.saving).toBe(false);
      expect(note.content).toBe("hello");
      expect(dialog.close).not.toHaveBeenCalled();
    });

    it("rejects malformed responses", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ note: "{}" }));
      const { editor } = await loadEditing();
      editor.open("7");

      $("#note-editor-input").val("edited");
      submit();
      await vi.waitFor(() => expect(alertSpy).toHaveBeenCalledWith("Error: Invalid response from server."));
      expect(editor.id).toBe("7");
      expect(editor.saving).toBe(false);
    });
  });

  describe("delete", () => {
    it("deletes the note after confirmation", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 204 }));
      vi.stubGlobal("confirm", vi.fn(() => true));
      const { editor, Note } = await loadEditing();
      editor.open("7");

      $("button[name='note-delete']").trigger("click");
      await vi.waitFor(() => expect(editor.id).toBeNull());

      const { url, method } = lastRequest(fetchSpy);
      expect(url).toBe("/notes/7.json");
      expect(method).toBe("DELETE");
      expect(Note.getByID("7")).toBeNull();
      expect(document.querySelector(".note-box")).toBeNull();
    });

    it("does nothing when the confirmation is declined", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch");
      vi.stubGlobal("confirm", vi.fn(() => false));
      const { editor } = await loadEditing();
      editor.open("7");

      $("button[name='note-delete']").trigger("click");
      expect(fetchSpy).not.toHaveBeenCalled();
      expect(editor.id).toBe("7");
    });

    it("reports server errors", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ reason: "Access denied" }, { status: 403 }));
      vi.stubGlobal("confirm", vi.fn(() => true));
      const { editor, Note } = await loadEditing();
      editor.open("7");

      $("button[name='note-delete']").trigger("click");
      await vi.waitFor(() => expect(alertSpy).toHaveBeenCalledWith("Error deleting note: Access denied"));
      expect(Note.getByID("7")).not.toBeNull();
      expect(editor.saving).toBe(false);
    });
  });

  describe("close", () => {
    async function openWithUnsavedMove () {
      const loaded = await loadEditing();
      loaded.editor.open("7");
      loaded.note.backup();
      loaded.note.moveTo({ x: 0, y: 0 });
      loaded.note.pending = true;
      return loaded;
    }

    it("Cancel restores the backup and closes the dialog", async () => {
      const { editor, note } = await openWithUnsavedMove();
      $("button[name='note-cancel']").trigger("click");

      expect(note.x).toBe(200);
      expect(note.pending).toBe(false);
      expect(note.focused).toBe(false);
      expect(editor.id).toBeNull();
      expect(dialog.close).toHaveBeenCalledWith(true);
    });

    it("the dialog's own close restores the backup without re-closing the dialog", async () => {
      const { editor, note } = await openWithUnsavedMove();
      $("#note-editor").trigger("dialog:close");

      expect(note.x).toBe(200);
      expect(note.pending).toBe(false);
      expect(editor.id).toBeNull();
      expect(dialog.close).not.toHaveBeenCalled();
    });

    it("leaving editing mode restores the backup", async () => {
      const { NoteManager, editor, note } = await openWithUnsavedMove();
      NoteManager.editing = false;

      expect(note.x).toBe(200);
      expect(note.pending).toBe(false);
      expect(editor.id).toBeNull();
      expect(dialog.close).toHaveBeenCalledWith(true);
    });

    it("discards an unsaved temporary note", async () => {
      const { editor, Note } = await loadEditing();
      const temp = Note.createTemporary();
      editor.open(temp.id);

      $("button[name='note-cancel']").trigger("click");
      expect(Note.getByID(temp.id)).toBeNull();
      expect(document.querySelectorAll(".note-box").length).toBe(1);
    });
  });
});
