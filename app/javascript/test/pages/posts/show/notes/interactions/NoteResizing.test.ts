import { beforeEach, describe, expect, it, vi } from "vitest";
import { SAMPLE_NOTE, loadNoteManager, mouse, pressEscape, renderNotesPage, stubGeometry } from "../fixtures";

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

const se = () => document.querySelector(".note-handle-se") as HTMLElement;
const nw = () => document.querySelector(".note-handle-nw") as HTMLElement;

describe("NoteResizing", () => {
  beforeEach(() => {
    dialog.open.mockReset();
    renderNotesPage({ notes: [SAMPLE_NOTE] }); // On screen: (100,100) 200x100
    stubGeometry();
  });

  it("does nothing outside editing mode", async () => {
    const { Note, NoteManager } = await loadNoteManager();
    mouse(se(), "mousedown", { x: 300, y: 200 });
    mouse(NoteManager.container, "mousemove", { x: 340, y: 230 });
    expect(Note.getByID("7")!.width).toBe(400);
    expect(NoteManager.container.attr("resizing")).toBeUndefined();
  });

  it("grows from the south-east handle and opens the editor on release", async () => {
    const { NoteManager, container, note } = await loadEditing();

    mouse(se(), "mousedown", { x: 300, y: 200 });
    expect(note.editing).toBe(true);
    expect(note.pending).toBe(true);
    expect(note.hasBackup).toBe(true);
    expect(container.attr("resizing")).toBe("true");
    expect(document.querySelectorAll(".note-box").length).toBe(1); // No drawing started

    mouse(container, "mousemove", { x: 340, y: 230 });
    expect(note.x).toBe(200);
    expect(note.y).toBe(200);
    expect(note.width).toBe(480);
    expect(note.height).toBe(260);
    expect(note.$box[0].style.width).toBe("240px");

    mouse(container, "mouseup", { x: 340, y: 230 });
    expect(note.editing).toBe(false);
    expect(note.pending).toBe(true);
    expect(container.attr("resizing")).toBe("false");
    expect(NoteManager.Editor.id).toBe("7");
    expect(dialog.open).toHaveBeenCalledTimes(1);
  });

  it("moves the origin from the north-west handle", async () => {
    const { container, note } = await loadEditing();

    mouse(nw(), "mousedown", { x: 100, y: 100 });
    mouse(container, "mousemove", { x: 120, y: 110 });
    expect(note.x).toBe(240);
    expect(note.y).toBe(220);
    expect(note.width).toBe(360);
    expect(note.height).toBe(180);
  });

  it("enforces the minimum size", async () => {
    const { container, note } = await loadEditing();

    mouse(se(), "mousedown", { x: 300, y: 200 });
    mouse(container, "mousemove", { x: 50, y: 50 });
    expect(note.width).toBe(20);
    expect(note.height).toBe(20);
    expect(note.x).toBe(200);
    mouse(container, "mouseup", { x: 50, y: 50 });

    mouse(nw(), "mousedown", { x: 100, y: 100 });
    mouse(container, "mousemove", { x: 500, y: 500 });
    // Origin is pinned so the bottom-right corner stays put
    expect(note.width).toBe(20);
    expect(note.height).toBe(20);
    expect(note.x).toBe(200);
    expect(note.y).toBe(200);
  });

  it.each([
    ["note:abort", (container: JQuery<HTMLElement>) => container.trigger("note:abort")],
    ["mouseleave", (container: JQuery<HTMLElement>) => container.trigger("mouseleave")],
    ["Escape", () => pressEscape()],
    ["context menu", (container: JQuery<HTMLElement>) => container.trigger("contextmenu")],
  ])("restores the original bounds on %s", async (_label, abort) => {
    const { container, note } = await loadEditing();

    mouse(se(), "mousedown", { x: 300, y: 200 });
    mouse(container, "mousemove", { x: 340, y: 230 });
    expect(note.width).toBe(480);

    abort(container);
    expect(note.width).toBe(400);
    expect(note.height).toBe(200);
    expect(note.editing).toBe(false);
    expect(container.attr("resizing")).toBe("false");

    mouse(container, "mouseup", { x: 340, y: 230 });
    expect(dialog.open).not.toHaveBeenCalled();
  });
});
