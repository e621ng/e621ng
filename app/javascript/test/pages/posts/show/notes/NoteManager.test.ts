import { beforeEach, describe, expect, it, vi } from "vitest";
import { SAMPLE_NOTE, loadNoteManager, renderNotesPage, stubGeometry } from "./fixtures";

const dialog = { open: vi.fn(), close: vi.fn(), setTitle: vi.fn() };
vi.mock("@/components/dialog", () => ({
  default: class {
    open = dialog.open;
    close = dialog.close;
    setTitle = dialog.setTitle;
  },
}));

const SECOND_NOTE = { id: 8, x: 0, y: 0, width: 100, height: 100, body: "second" };

describe("NoteManager", () => {
  beforeEach(() => {
    dialog.open.mockReset();
    window.location.hash = "";
  });

  it("does nothing without an image container", async () => {
    renderNotesPage({ imageContainer: false, notes: [SAMPLE_NOTE] });
    stubGeometry();
    await loadNoteManager();
    expect(document.querySelector(".note-box")).toBeNull();
  });

  it("does nothing for file types that cannot have notes", async () => {
    renderNotesPage({ fileExt: "webm", notes: [SAMPLE_NOTE] });
    stubGeometry();
    await loadNoteManager();
    expect(document.querySelector(".note-box")).toBeNull();
  });

  it("loads staged notes into the container", async () => {
    renderNotesPage({ notes: [SAMPLE_NOTE, SECOND_NOTE] });
    stubGeometry();
    const { Note } = await loadNoteManager();

    const boxes = document.querySelectorAll("#note-container .note-box");
    expect(boxes.length).toBe(2);
    expect(boxes[0].getAttribute("nid")).toBe("7");
    expect(boxes[0].querySelector(".note-body")!.innerHTML).toBe("<p>hello</p>");
    expect(Note.getByID("8")!.width).toBe(100);
  });

  it("highlights the note named in the URL hash and follows hash changes", async () => {
    renderNotesPage({ notes: [SAMPLE_NOTE, SECOND_NOTE] });
    stubGeometry();
    window.location.hash = "#note-7";
    const { Note } = await loadNoteManager();

    expect(Note.getByID("7")!.highlighted).toBe(true);
    expect(Note.getByID("8")!.highlighted).toBe(false);
    expect(Element.prototype.scrollIntoView).toHaveBeenCalledTimes(1);

    window.location.hash = "#note-8";
    $(window).trigger("hashchange");
    expect(Note.getByID("7")!.highlighted).toBe(false);
    expect(Note.getByID("8")!.highlighted).toBe(true);

    window.location.hash = "#note-999";
    $(window).trigger("hashchange");
    expect(document.querySelector(".note-box.highlighted")).toBeNull();
  });

  it("does not wire editing controls for anonymous users", async () => {
    renderNotesPage({ member: false, notes: [SAMPLE_NOTE] });
    stubGeometry();
    const { NoteManager } = await loadNoteManager();

    $("#translate").trigger("click");
    expect(NoteManager.editing).toBe(false);

    $(".note-box").trigger("dblclick");
    expect(NoteManager.editing).toBe(false);
    expect(dialog.open).not.toHaveBeenCalled();
  });

  it("toggles editing mode from the Edit Notes link and the Close Editor button", async () => {
    renderNotesPage({ notes: [SAMPLE_NOTE] });
    stubGeometry();
    const animate = vi.spyOn($.fn, "animate").mockReturnThis();
    const { NoteManager } = await loadNoteManager();
    NoteManager.enabled = false;

    $("#translate").trigger("click");
    expect(NoteManager.editing).toBe(true);
    expect(NoteManager.container.attr("editing")).toBe("true");
    expect(NoteManager.enabled).toBe(true); // Notes are shown when editing starts
    expect(animate).toHaveBeenCalledTimes(1);

    $("#translation-cancel").trigger("click");
    expect(NoteManager.editing).toBe(false);
    expect(NoteManager.container.attr("editing")).toBe("false");
  });

  it("double-clicking a note enters editing mode and opens the editor", async () => {
    renderNotesPage({ notes: [SAMPLE_NOTE] });
    stubGeometry();
    const { NoteManager } = await loadNoteManager();

    $(".note-box").trigger("dblclick");
    expect(NoteManager.editing).toBe(true);
    expect(NoteManager.Editor.id).toBe("7");
    expect(dialog.open).toHaveBeenCalledTimes(1);
  });

  it("clicking a note body while editing opens the editor", async () => {
    renderNotesPage({ notes: [SAMPLE_NOTE, SECOND_NOTE] });
    stubGeometry();
    const { NoteManager } = await loadNoteManager();

    $(".note-box[nid='8'] .note-body").trigger("click");
    expect(dialog.open).not.toHaveBeenCalled();

    NoteManager.editing = true;
    $(".note-box[nid='8'] .note-body").trigger("click");
    expect(NoteManager.Editor.id).toBe("8");
    expect(dialog.open).toHaveBeenCalledTimes(1);
  });

  it("exposes the visibility toggle used by the toolbar", async () => {
    renderNotesPage({ notes: [SAMPLE_NOTE] });
    stubGeometry();
    const { NoteManager } = await loadNoteManager();
    const events: string[] = [];
    $("#note-container").on("note:visible:true note:visible:false", (event) => { events.push(event.type); });

    NoteManager.enabled = false;
    expect(NoteManager.container.attr("enabled")).toBe("false");
    NoteManager.enabled = true;
    expect(events).toEqual(["note:visible:false", "note:visible:true"]);
  });
});
