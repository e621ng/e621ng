import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { LONG_PRESS_MS, SAMPLE_NOTE, loadNoteManager, nativeTouchMove, pointer, pressEscape, renderNotesPage, stubGeometry, stubPositionFromStyle, touch } from "../fixtures";

const dialog = { open: vi.fn(), close: vi.fn(), setTitle: vi.fn() };
vi.mock("@/components/dialog", () => ({
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
    pointer(box(), "pointerdown", { x: 150, y: 150 });
    pointer(NoteManager.container, "pointermove", { x: 170, y: 180 });
    expect(Note.getByID("7")!.x).toBe(200);
  });

  it("moves the note by the drag delta and opens the editor on release", async () => {
    const { NoteManager, container, note } = await loadEditing();

    pointer(box(), "pointerdown", { x: 150, y: 150 });
    expect(note.editing).toBe(true);
    expect(note.pending).toBe(true);
    expect(note.hasBackup).toBe(true);
    expect(container.attr("dragging")).toBe("true");
    expect(document.querySelectorAll(".note-box").length).toBe(1); // No drawing started

    pointer(container, "pointermove", { x: 170, y: 180 });
    expect(note.x).toBe(240);
    expect(note.y).toBe(260);
    expect(note.width).toBe(400);
    expect(box().style.left).toBe("120px");
    expect(box().style.top).toBe("130px");

    pointer(container, "pointerup", { x: 170, y: 180 });
    expect(note.editing).toBe(false);
    expect(container.attr("dragging")).toBe("false");
    expect(NoteManager.Editor.id).toBe("7");
    expect(dialog.open).toHaveBeenCalledTimes(1);
  });

  it("keeps the note inside the container", async () => {
    const { container, note } = await loadEditing();

    pointer(box(), "pointerdown", { x: 150, y: 150 });
    pointer(container, "pointermove", { x: 2000, y: 2000 });
    expect(box().style.left).toBe("600px");
    expect(box().style.top).toBe("500px");
    expect(note.x).toBe(1200);
    expect(note.y).toBe(1000);

    pointer(container, "pointermove", { x: -500, y: -500 });
    expect(box().style.left).toBe("0px");
    expect(box().style.top).toBe("0px");
  });

  it("ignores presses on the body and handles", async () => {
    const { container, note } = await loadEditing();
    const body = document.querySelector(".note-body") as HTMLElement;

    pointer(body, "pointerdown", { x: 150, y: 150 });
    pointer(container, "pointermove", { x: 170, y: 180 });
    expect(note.x).toBe(200);
    expect(container.attr("dragging")).toBeUndefined();
  });

  it.each([
    ["note:abort", (container: JQuery<HTMLElement>) => container.trigger("note:abort")],
    ["pointercancel", (container: JQuery<HTMLElement>) => pointer(container, "pointercancel", { x: 170, y: 180 })],
    ["Escape", () => pressEscape()],
    ["context menu", (container: JQuery<HTMLElement>) => container.trigger("contextmenu")],
  ])("stops moving on %s and leaves the note where it is", async (_label, abort) => {
    const { container, note } = await loadEditing();

    pointer(box(), "pointerdown", { x: 150, y: 150 });
    pointer(container, "pointermove", { x: 170, y: 180 });

    abort(container);
    expect(note.x).toBe(240);
    expect(note.y).toBe(260);
    expect(note.editing).toBe(false);
    expect(note.pending).toBe(true);
    expect(container.attr("dragging")).toBe("false");

    pointer(container, "pointerup", { x: 170, y: 180 });
    expect(dialog.open).not.toHaveBeenCalled();
  });

  describe("on touch", () => {
    beforeEach(() => { vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] }); });
    afterEach(() => { vi.useRealTimers(); });

    it("opens the editor on a tap without touching the note", async () => {
      const { NoteManager, container, note } = await loadEditing();

      touch(box(), "pointerdown", { x: 150, y: 150 });
      expect(note.editing).toBe(false);
      expect(container.attr("dragging")).toBeUndefined();

      touch(container, "pointerup", { x: 151, y: 150 });
      expect(note.hasBackup).toBe(false);
      expect(note.pending).toBe(false);
      expect(NoteManager.Editor.id).toBe("7");
      expect(dialog.open).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(LONG_PRESS_MS);
      expect(note.editing).toBe(false);
    });

    it("lets a quick drag scroll the page instead of moving", async () => {
      const { container, note } = await loadEditing();

      touch(box(), "pointerdown", { x: 150, y: 150 });
      touch(container, "pointermove", { x: 150, y: 190 });
      expect(nativeTouchMove(container[0])).toBe(false);

      vi.advanceTimersByTime(LONG_PRESS_MS);
      touch(container, "pointermove", { x: 150, y: 250 });
      touch(container, "pointercancel", { x: 150, y: 250 });

      expect(note.x).toBe(200);
      expect(note.y).toBe(200);
      expect(note.pending).toBe(false);
      expect(note.hasBackup).toBe(false);
      expect(dialog.open).not.toHaveBeenCalled();
    });

    it("moves after a long press", async () => {
      const { NoteManager, container, note } = await loadEditing();

      touch(box(), "pointerdown", { x: 150, y: 150 });
      vi.advanceTimersByTime(LONG_PRESS_MS);
      expect(note.editing).toBe(true);
      expect(note.hasBackup).toBe(true);
      expect(container.attr("dragging")).toBe("true");
      expect(nativeTouchMove(container[0])).toBe(true);

      touch(container, "pointermove", { x: 170, y: 180 });
      expect(note.x).toBe(240);
      expect(note.y).toBe(260);

      touch(container, "pointerup", { x: 170, y: 180 });
      expect(note.editing).toBe(false);
      expect(container.attr("dragging")).toBe("false");
      expect(NoteManager.Editor.id).toBe("7");
      expect(dialog.open).toHaveBeenCalledTimes(1);
    });

    it("keeps the moved position when the browser cancels the pointer", async () => {
      const { container, note } = await loadEditing();

      touch(box(), "pointerdown", { x: 150, y: 150 });
      vi.advanceTimersByTime(LONG_PRESS_MS);
      touch(container, "pointermove", { x: 170, y: 180 });
      touch(container, "pointercancel", { x: 170, y: 180 });

      expect(note.x).toBe(240);
      expect(note.editing).toBe(false);
      expect(note.pending).toBe(true);
      expect(container.attr("dragging")).toBe("false");
      expect(dialog.open).not.toHaveBeenCalled();
    });
  });
});
