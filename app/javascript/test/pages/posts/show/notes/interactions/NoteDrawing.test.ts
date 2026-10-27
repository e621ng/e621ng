import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { LONG_PRESS_MS, SAMPLE_NOTE, loadNoteManager, nativeTouchMove, pointer, pressEscape, renderNotesPage, stubGeometry, touch } from "../fixtures";

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

const boxes = () => document.querySelectorAll(".note-box").length;

describe("NoteDrawing", () => {
  beforeEach(() => {
    dialog.open.mockReset();
    renderNotesPage({ notes: [SAMPLE_NOTE] });
    stubGeometry(); // scale 0.5, min size 10px
  });

  it("does nothing outside editing mode", async () => {
    const { NoteManager } = await loadNoteManager();
    const container = NoteManager.container;
    pointer(container, "pointerdown", { x: 400, y: 400 });
    pointer(container, "pointerup", { x: 500, y: 460 });
    expect(boxes()).toBe(1);
  });

  it("creates a note from the dragged rectangle and opens the editor", async () => {
    const { NoteManager, Note, container } = await loadEditing();

    pointer(container, "pointerdown", { x: 400, y: 400 });
    expect(boxes()).toBe(2);
    const box = document.querySelector(".note-box.editing") as HTMLElement;
    expect(box.getAttribute("nid")).toMatch(/^temp-/);

    pointer(container, "pointermove", { x: 500, y: 460 });
    expect(box.style.width).toBe("100px");
    expect(box.style.height).toBe("60px");

    // Dragging up and to the left normalizes the origin
    pointer(container, "pointermove", { x: 300, y: 350 });
    expect(box.style.left).toBe("300px");
    expect(box.style.top).toBe("350px");

    pointer(container, "pointerup", { x: 500, y: 460 });
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

    pointer(container, "pointerdown", { x: 400, y: 400 });
    pointer(container, "pointermove", { x: 405, y: 430 });
    pointer(container, "pointerup", { x: 405, y: 430 });

    expect(boxes()).toBe(1);
    expect(dialog.open).not.toHaveBeenCalled();
  });

  it("does not start drawing on top of an existing note", async () => {
    const { container } = await loadEditing();
    const body = document.querySelector(".note-box .note-body") as HTMLElement;

    pointer(body, "pointerdown", { x: 150, y: 150 });
    pointer(container, "pointermove", { x: 250, y: 250 });
    pointer(container, "pointerup", { x: 250, y: 250 });

    expect(boxes()).toBe(1);
  });

  it("ignores other pointers while drawing", async () => {
    const { container } = await loadEditing();

    pointer(container, "pointerdown", { x: 400, y: 400 });
    const box = document.querySelector(".note-box.editing") as HTMLElement;

    pointer(container, "pointermove", { x: 600, y: 600, pointerId: 2 });
    expect(box.style.width).toBe("1px"); // Untouched temporary note
    pointer(container, "pointerup", { x: 600, y: 600, pointerId: 2 });
    expect(boxes()).toBe(2);

    pointer(container, "pointermove", { x: 500, y: 460 });
    expect(box.style.width).toBe("100px");
  });

  it.each([
    ["note:abort", (container: JQuery<HTMLElement>) => container.trigger("note:abort")],
    ["pointercancel", (container: JQuery<HTMLElement>) => pointer(container, "pointercancel", { x: 500, y: 460 })],
    ["Escape", () => pressEscape()],
    ["window blur", () => $(window).triggerHandler("blur")],
    ["right click", (container: JQuery<HTMLElement>) => pointer(container, "pointerdown", { x: 450, y: 450, button: 2 })],
    ["context menu", (container: JQuery<HTMLElement>) => container.trigger("contextmenu")],
  ])("aborts an in-progress drawing on %s", async (_label, abort) => {
    const { container } = await loadEditing();

    pointer(container, "pointerdown", { x: 400, y: 400 });
    pointer(container, "pointermove", { x: 500, y: 460 });
    expect(boxes()).toBe(2);

    abort(container);
    expect(boxes()).toBe(1);

    // A later pointerup is ignored
    pointer(container, "pointerup", { x: 500, y: 460 });
    expect(boxes()).toBe(1);
    expect(dialog.open).not.toHaveBeenCalled();
  });

  describe("on touch", () => {
    beforeEach(() => { vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] }); });
    afterEach(() => { vi.useRealTimers(); });

    it("creates nothing on a tap", async () => {
      const { container } = await loadEditing();

      touch(container, "pointerdown", { x: 400, y: 400 });
      expect(boxes()).toBe(1);
      touch(container, "pointerup", { x: 400, y: 400 });
      vi.advanceTimersByTime(LONG_PRESS_MS);

      expect(boxes()).toBe(1);
      expect(dialog.open).not.toHaveBeenCalled();
    });

    it("lets a quick drag scroll the page instead of drawing", async () => {
      const { container } = await loadEditing();

      touch(container, "pointerdown", { x: 400, y: 400 });
      touch(container, "pointermove", { x: 430, y: 400 });
      expect(nativeTouchMove(container[0])).toBe(false);

      vi.advanceTimersByTime(LONG_PRESS_MS);
      expect(boxes()).toBe(1);

      // The browser takes over the gesture
      touch(container, "pointercancel", { x: 450, y: 400 });
      touch(container, "pointerup", { x: 450, y: 400 });
      expect(boxes()).toBe(1);
    });

    it("draws after a long press and blocks scrolling meanwhile", async () => {
      const { NoteManager, Note, container } = await loadEditing();

      touch(container, "pointerdown", { x: 400, y: 400 });
      touch(container, "pointermove", { x: 404, y: 403 }); // Finger jitter within the slop
      expect(boxes()).toBe(1);

      vi.advanceTimersByTime(LONG_PRESS_MS);
      expect(boxes()).toBe(2);
      expect(nativeTouchMove(container[0])).toBe(true);

      touch(container, "pointermove", { x: 500, y: 460 });
      const box = document.querySelector(".note-box.editing") as HTMLElement;
      expect(box.style.width).toBe("100px");

      touch(container, "pointerup", { x: 500, y: 460 });
      const note = Note.getByID(box.getAttribute("nid"))!;
      expect(note.width).toBe(200);
      expect(NoteManager.Editor.id).toBe(note.id);
      expect(dialog.open).toHaveBeenCalledTimes(1);
      expect(nativeTouchMove(container[0])).toBe(false);
    });

    it("does not abort a long press on the context menu", async () => {
      const { container } = await loadEditing();

      touch(container, "pointerdown", { x: 400, y: 400 });
      vi.advanceTimersByTime(LONG_PRESS_MS);
      expect(boxes()).toBe(2);

      const menu = $.Event("contextmenu");
      container.trigger(menu);
      expect(menu.isDefaultPrevented()).toBe(true);
      expect(boxes()).toBe(2);

      touch(container, "pointercancel", { x: 400, y: 400 });
      expect(boxes()).toBe(1);
    });

    it("ignores a second finger", async () => {
      const { container } = await loadEditing();

      touch(container, "pointerdown", { x: 400, y: 400, pointerId: 2, isPrimary: false });
      vi.advanceTimersByTime(LONG_PRESS_MS);
      expect(boxes()).toBe(1);
    });
  });
});
