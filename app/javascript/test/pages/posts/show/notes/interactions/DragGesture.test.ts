import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { LONG_PRESS_MS, nativeTouchMove, pointer, renderNotesPage, stubGeometry, touch } from "../fixtures";

async function load () {
  vi.resetModules();
  const DragGesture = (await import("@/pages/posts/show/notes/interactions/DragGesture")).default;
  const NoteUtilities = (await import("@/pages/posts/show/notes/NoteUtilities")).default;
  const callbacks = { onStart: vi.fn(), onMove: vi.fn(), onEnd: vi.fn(), onCancel: vi.fn(), onTap: vi.fn() };
  return { DragGesture, callbacks, container: NoteUtilities.container };
}

describe("DragGesture", () => {
  beforeEach(() => {
    renderNotesPage();
    stubGeometry();
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
  });
  afterEach(() => { vi.useRealTimers(); });

  it("starts a mouse drag immediately and reports container coordinates", async () => {
    const { DragGesture, callbacks, container } = await load();
    const gesture = new DragGesture(callbacks, { longPress: true });

    const down = $.Event("pointerdown", { pageX: 50, pageY: 60, button: 0, pointerId: 1, pointerType: "mouse" });
    expect(gesture.begin(down)).toBe(true);
    expect(gesture.active).toBe(true);
    expect(callbacks.onStart).toHaveBeenCalledWith({ x: 50, y: 60 });

    pointer(container, "pointermove", { x: 80, y: 90 });
    expect(callbacks.onMove).toHaveBeenCalledWith({ x: 80, y: 90 });

    pointer(container, "pointerup", { x: 85, y: 95 });
    expect(callbacks.onEnd).toHaveBeenCalledWith({ x: 85, y: 95 });
    expect(gesture.active).toBe(false);
    expect(callbacks.onTap).not.toHaveBeenCalled();
  });

  it("refuses non-primary buttons and secondary pointers", async () => {
    const { DragGesture, callbacks } = await load();
    const gesture = new DragGesture(callbacks, { longPress: false });

    expect(gesture.begin($.Event("pointerdown", { button: 2, pointerId: 1 }))).toBe(false);
    expect(gesture.begin($.Event("pointerdown", { button: 0, pointerId: 2, isPrimary: false }))).toBe(false);
    expect(callbacks.onStart).not.toHaveBeenCalled();
  });

  it("only allows one gesture at a time", async () => {
    const { DragGesture, callbacks, container } = await load();
    const first = new DragGesture(callbacks, { longPress: false });
    const second = new DragGesture(callbacks, { longPress: false });

    expect(first.begin($.Event("pointerdown", { button: 0, pointerId: 1 }))).toBe(true);
    expect(second.begin($.Event("pointerdown", { button: 0, pointerId: 2 }))).toBe(false);

    pointer(container, "pointerup", { pointerId: 1 });
    expect(second.begin($.Event("pointerdown", { button: 0, pointerId: 2 }))).toBe(true);
  });

  describe("long press", () => {
    it("waits for the hold before starting, and blocks touch scrolling only while active", async () => {
      const { DragGesture, callbacks, container } = await load();
      const gesture = new DragGesture(callbacks, { longPress: true });

      gesture.begin($.Event("pointerdown", { pageX: 10, pageY: 10, button: 0, pointerId: 1, pointerType: "touch" }));
      expect(gesture.pending).toBe(true);
      expect(gesture.active).toBe(false);
      expect(nativeTouchMove(container[0])).toBe(false);

      vi.advanceTimersByTime(LONG_PRESS_MS - 1);
      expect(callbacks.onStart).not.toHaveBeenCalled();

      vi.advanceTimersByTime(1);
      expect(gesture.active).toBe(true);
      expect(callbacks.onStart).toHaveBeenCalledWith({ x: 10, y: 10 });
      expect(nativeTouchMove(container[0])).toBe(true);

      touch(container, "pointerup", { x: 30, y: 40 });
      expect(callbacks.onEnd).toHaveBeenCalledWith({ x: 30, y: 40 });
      expect(nativeTouchMove(container[0])).toBe(false);
    });

    it("is cancelled by movement past the slop, with no callbacks", async () => {
      const { DragGesture, callbacks, container } = await load();
      const gesture = new DragGesture(callbacks, { longPress: true });

      gesture.begin($.Event("pointerdown", { pageX: 10, pageY: 10, button: 0, pointerId: 1, pointerType: "touch" }));
      touch(container, "pointermove", { x: 17, y: 17 }); // Within slop
      expect(gesture.pending).toBe(true);

      touch(container, "pointermove", { x: 10, y: 25 }); // Past it
      expect(gesture.pending).toBe(false);

      vi.advanceTimersByTime(LONG_PRESS_MS);
      touch(container, "pointerup", { x: 10, y: 25 });
      expect(callbacks.onStart).not.toHaveBeenCalled();
      expect(callbacks.onTap).not.toHaveBeenCalled();
      expect(callbacks.onCancel).not.toHaveBeenCalled();
    });

    it("reports a release before the hold as a tap", async () => {
      const { DragGesture, callbacks, container } = await load();
      const gesture = new DragGesture(callbacks, { longPress: true });

      gesture.begin($.Event("pointerdown", { pageX: 10, pageY: 10, button: 0, pointerId: 1, pointerType: "touch" }));
      touch(container, "pointerup", { x: 12, y: 11 });
      expect(callbacks.onTap).toHaveBeenCalledWith({ x: 12, y: 11 });
      expect(callbacks.onEnd).not.toHaveBeenCalled();

      vi.advanceTimersByTime(LONG_PRESS_MS);
      expect(callbacks.onStart).not.toHaveBeenCalled();
    });

    it("is not required for a pen when longPress is off", async () => {
      const { DragGesture, callbacks } = await load();
      const gesture = new DragGesture(callbacks, { longPress: false });

      gesture.begin($.Event("pointerdown", { button: 0, pointerId: 1, pointerType: "pen" }));
      expect(gesture.active).toBe(true);
    });

    it("ignores a pointercancel during the hold", async () => {
      const { DragGesture, callbacks, container } = await load();
      const gesture = new DragGesture(callbacks, { longPress: true });

      gesture.begin($.Event("pointerdown", { button: 0, pointerId: 1, pointerType: "touch" }));
      touch(container, "pointercancel");
      vi.advanceTimersByTime(LONG_PRESS_MS);

      expect(gesture.pending).toBe(false);
      expect(gesture.active).toBe(false);
      expect(callbacks.onStart).not.toHaveBeenCalled();
      expect(callbacks.onCancel).not.toHaveBeenCalled();
    });
  });

  describe("context menu", () => {
    it("aborts a mouse drag", async () => {
      const { DragGesture, callbacks, container } = await load();
      const gesture = new DragGesture(callbacks, { longPress: true });

      gesture.begin($.Event("pointerdown", { button: 0, pointerId: 1, pointerType: "mouse" }));
      container.trigger("contextmenu");
      expect(gesture.active).toBe(false);
      expect(callbacks.onCancel).toHaveBeenCalledTimes(1);
    });

    it("leaves a touch drag alone", async () => {
      const { DragGesture, callbacks, container } = await load();
      const gesture = new DragGesture(callbacks, { longPress: true });

      gesture.begin($.Event("pointerdown", { button: 0, pointerId: 1, pointerType: "touch" }));
      vi.advanceTimersByTime(LONG_PRESS_MS);
      container.trigger("contextmenu");
      expect(gesture.active).toBe(true);
      expect(callbacks.onCancel).not.toHaveBeenCalled();
    });
  });

  it("unbinds its listeners once finished", async () => {
    const { DragGesture, callbacks, container } = await load();
    const gesture = new DragGesture(callbacks, { longPress: false });

    gesture.begin($.Event("pointerdown", { button: 0, pointerId: 1 }));
    gesture.abort();
    expect(callbacks.onCancel).toHaveBeenCalledTimes(1);

    pointer(container, "pointermove", { x: 5, y: 5 });
    pointer(container, "pointerup", { x: 5, y: 5 });
    expect(callbacks.onMove).not.toHaveBeenCalled();
    expect(callbacks.onEnd).not.toHaveBeenCalled();
  });
});
