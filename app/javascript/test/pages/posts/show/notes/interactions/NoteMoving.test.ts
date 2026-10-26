import { beforeEach, describe, expect, it, vi } from "vitest";
import { SAMPLE_NOTE, loadNoteManager, mouse, pressEscape, renderNotesPage, stubGeometry, stubPositionFromStyle } from "../fixtures";

const dialog = { open: vi.fn(), close: vi.fn(), setTitle: vi.fn() };
vi.mock("@/utility/dialog", () => ({
  default: class {
    open = dialog.open;
    close = dialog.close;
    setTitle = dialog.setTitle;
  },
}));

async function loadEditing () {
  const loaded = await loadNoteManager();
  loaded.NoteManager.editing = true;
  return { ...loaded, container: loaded.NoteManager.container, note: loaded.Note.getByID("7")! };
}

const box = () => document.querySelector(".note-box") as HTMLElement;

describe("NoteMoving", () => {
  beforeEach(() => {
    dialog.open.mockReset();
    renderNotesPage({ notes: [SAMPLE_NOTE] }); // On screen: (100,100) 200x100 in an 800x600 container
    stubGeometry();
    stubPositionFromStyle();
  });

  it("does nothing outside editing mode", async () => {
    const { Note, NoteManager } = await loadNoteManager();
    mouse(box(), "mousedown", { x: 150, y: 150 });
    mouse(NoteManager.container, "mousemove", { x: 170, y: 180 });
    expect(Note.getByID("7")!.x).toBe(200);
  });

  it("moves the note by the drag delta and opens the editor on release", async () => {
    const { NoteManager, container, note } = await loadEditing();

    mouse(box(), "mousedown", { x: 150, y: 150 });
    expect(note.editing).toBe(true);
    expect(note.pending).toBe(true);
    expect(note.hasBackup).toBe(true);
    expect(container.attr("dragging")).toBe("true");
    expect(document.querySelectorAll(".note-box").length).toBe(1); // No drawing started

    mouse(container, "mousemove", { x: 170, y: 180 });
    expect(note.x).toBe(240);
    expect(note.y).toBe(260);
    expect(note.width).toBe(400);
    expect(box().style.left).toBe("120px");
    expect(box().style.top).toBe("130px");

    mouse(container, "mouseup", { x: 170, y: 180 });
    expect(note.editing).toBe(false);
    expect(container.attr("dragging")).toBe("false");
    expect(NoteManager.Editor.id).toBe("7");
    expect(dialog.open).toHaveBeenCalledTimes(1);
  });

  it("keeps the note inside the container", async () => {
    const { container, note } = await loadEditing();

    mouse(box(), "mousedown", { x: 150, y: 150 });
    mouse(container, "mousemove", { x: 2000, y: 2000 });
    expect(box().style.left).toBe("600px");
    expect(box().style.top).toBe("500px");
    expect(note.x).toBe(1200);
    expect(note.y).toBe(1000);

    mouse(container, "mousemove", { x: -500, y: -500 });
    expect(box().style.left).toBe("0px");
    expect(box().style.top).toBe("0px");
  });

  it("ignores presses on the body and handles", async () => {
    const { container, note } = await loadEditing();
    const body = document.querySelector(".note-body") as HTMLElement;

    mouse(body, "mousedown", { x: 150, y: 150 });
    mouse(container, "mousemove", { x: 170, y: 180 });
    expect(note.x).toBe(200);
    expect(container.attr("dragging")).toBeUndefined();
  });

  it.each([
    ["note:abort", (container: JQuery<HTMLElement>) => container.trigger("note:abort")],
    ["mouseleave", (container: JQuery<HTMLElement>) => container.trigger("mouseleave")],
    ["Escape", () => pressEscape()],
    ["context menu", (container: JQuery<HTMLElement>) => container.trigger("contextmenu")],
  ])("stops moving on %s and leaves the note where it is", async (_label, abort) => {
    const { container, note } = await loadEditing();

    mouse(box(), "mousedown", { x: 150, y: 150 });
    mouse(container, "mousemove", { x: 170, y: 180 });

    abort(container);
    expect(note.x).toBe(240);
    expect(note.y).toBe(260);
    expect(note.editing).toBe(false);
    expect(note.pending).toBe(true);
    expect(container.attr("dragging")).toBe("false");

    mouse(container, "mouseup", { x: 170, y: 180 });
    expect(dialog.open).not.toHaveBeenCalled();
  });
});
