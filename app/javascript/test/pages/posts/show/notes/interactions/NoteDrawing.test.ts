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
  return { ...loaded, container: loaded.NoteManager.container };
}

describe("NoteDrawing", () => {
  beforeEach(() => {
    dialog.open.mockReset();
    renderNotesPage({ notes: [SAMPLE_NOTE] });
    stubGeometry(); // scale 0.5, min size 10px
  });

  it("does nothing outside editing mode", async () => {
    const { NoteManager } = await loadNoteManager();
    const container = NoteManager.container;
    mouse(container, "mousedown", { x: 400, y: 400 });
    mouse(container, "mouseup", { x: 500, y: 460 });
    expect(document.querySelectorAll(".note-box").length).toBe(1);
  });

  it("creates a note from the dragged rectangle and opens the editor", async () => {
    const { NoteManager, Note, container } = await loadEditing();

    mouse(container, "mousedown", { x: 400, y: 400 });
    expect(document.querySelectorAll(".note-box").length).toBe(2);
    const box = document.querySelector(".note-box.editing") as HTMLElement;
    expect(box.getAttribute("nid")).toMatch(/^temp-/);

    mouse(container, "mousemove", { x: 500, y: 460 });
    expect(box.style.width).toBe("100px");
    expect(box.style.height).toBe("60px");

    // Dragging up and to the left normalizes the origin
    mouse(container, "mousemove", { x: 300, y: 350 });
    expect(box.style.left).toBe("300px");
    expect(box.style.top).toBe("350px");

    mouse(container, "mouseup", { x: 500, y: 460 });
    const note = Note.getByID(box.getAttribute("nid"))!;
    expect(note.isTemporary).toBe(true);
    expect(note.x).toBe(800);
    expect(note.y).toBe(800);
    expect(note.width).toBe(200);
    expect(note.height).toBe(120);
    expect(note.editing).toBe(false);
    expect(NoteManager.Editor.id).toBe(note.id);
    expect(dialog.open).toHaveBeenCalledTimes(1);
  });

  it("discards rectangles smaller than the minimum size", async () => {
    const { container } = await loadEditing();

    mouse(container, "mousedown", { x: 400, y: 400 });
    mouse(container, "mousemove", { x: 405, y: 430 });
    mouse(container, "mouseup", { x: 405, y: 430 });

    expect(document.querySelectorAll(".note-box").length).toBe(1);
    expect(dialog.open).not.toHaveBeenCalled();
  });

  it("does not start drawing on top of an existing note", async () => {
    const { container } = await loadEditing();
    const body = document.querySelector(".note-box .note-body") as HTMLElement;

    mouse(body, "mousedown", { x: 150, y: 150 });
    mouse(container, "mousemove", { x: 250, y: 250 });
    mouse(container, "mouseup", { x: 250, y: 250 });

    expect(document.querySelectorAll(".note-box").length).toBe(1);
  });

  it.each([
    ["note:abort", (container: JQuery<HTMLElement>) => container.trigger("note:abort")],
    ["mouseleave", (container: JQuery<HTMLElement>) => container.trigger("mouseleave")],
    ["Escape", () => pressEscape()],
    ["window blur", () => $(window).triggerHandler("blur")],
    ["right click", (container: JQuery<HTMLElement>) => mouse(container, "mousedown", { x: 450, y: 450, button: 2 })],
    ["context menu", (container: JQuery<HTMLElement>) => container.trigger("contextmenu")],
  ])("aborts an in-progress drawing on %s", async (_label, abort) => {
    const { container } = await loadEditing();

    mouse(container, "mousedown", { x: 400, y: 400 });
    mouse(container, "mousemove", { x: 500, y: 460 });
    expect(document.querySelectorAll(".note-box").length).toBe(2);

    abort(container);
    expect(document.querySelectorAll(".note-box").length).toBe(1);

    // A later mouseup is ignored
    mouse(container, "mouseup", { x: 500, y: 460 });
    expect(document.querySelectorAll(".note-box").length).toBe(1);
    expect(dialog.open).not.toHaveBeenCalled();
  });
});
