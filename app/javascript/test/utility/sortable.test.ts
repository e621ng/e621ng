import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import Sortable from "@/utility/sortable";

// Internal state the tests assert on to prove nothing is left behind after a drag.
interface SortableInternals {
  _drag: unknown;
  _rafId: number;
  _scrollRafId: number;
  _lastPointer: { clientX: number; clientY: number } | null;
}

const ITEM_WIDTH = 100;
const ITEM_HEIGHT = 120;

beforeAll(() => {
  // jsdom doesn't implement these.
  if (!Element.prototype.setPointerCapture) Element.prototype.setPointerCapture = () => {};
  if (!document.elementFromPoint) document.elementFromPoint = () => null;
});

/**
 * Builds a grid of items laid out row by row (`cols` per row), ITEM_WIDTH x ITEM_HEIGHT
 * each, mirroring the pool ordering markup: a wrapper holding a thumbnail link and a handle.
 */
function buildGrid (ids = ["1", "2", "3", "4"], cols = ids.length) {
  const container = document.createElement("section");
  container.className = "posts-container sortable";

  const items = ids.map((id, index) => {
    const item = document.createElement("div");
    item.className = "sortable-thumbnail";
    item.dataset.id = id;

    const article = document.createElement("article");
    article.className = "thumbnail";
    const link = document.createElement("a");
    link.className = "thm-link";
    link.setAttribute("href", `/posts/${id}`);
    const img = document.createElement("img");
    link.appendChild(img);
    article.appendChild(link);

    const handle = document.createElement("span");
    handle.className = "sortable-handle";

    item.append(article, handle);
    container.appendChild(item);

    const left = (index % cols) * ITEM_WIDTH;
    const top = Math.floor(index / cols) * ITEM_HEIGHT;
    vi.spyOn(item, "getBoundingClientRect").mockReturnValue({
      left, top, right: left + ITEM_WIDTH, bottom: top + ITEM_HEIGHT,
      x: left, y: top, width: ITEM_WIDTH, height: ITEM_HEIGHT,
    } as DOMRect);

    return { item, link, img, handle };
  });

  document.body.appendChild(container);
  return { container, items };
}

function firePointer (type: string, el: Element, opts: Partial<PointerEventInit> = {}) {
  const event = new PointerEvent(type, {
    bubbles: true,
    cancelable: true,
    pointerId: 1,
    pointerType: "mouse",
    button: 0,
    clientX: 0,
    clientY: 0,
    ...opts,
  });
  el.dispatchEvent(event);
  return event;
}

function currentOrder (container: Element) {
  return Array.from(container.querySelectorAll<HTMLElement>(".sortable-thumbnail")).map((el) => el.dataset.id);
}

function placeholder () {
  return document.querySelector<HTMLElement>(".sortable-placeholder");
}

/**
 * Models a wrapping CSS grid for document.elementFromPoint: the point maps to a slot
 * (row * cols + col), and the slot holds whichever visible child is currently there.
 * The dragged source is display:none, so it occupies no slot; the placeholder does.
 * `offsetY` shifts the grid down the viewport, e.g. to model content scrolling into view.
 */
function mockGridLayout (container: Element, cols: number, offsetY: () => number = () => 0) {
  return vi.spyOn(document, "elementFromPoint").mockImplementation((x: number, y: number) => {
    const col = Math.floor(x / ITEM_WIDTH);
    const row = Math.floor((y - offsetY()) / ITEM_HEIGHT);
    if (col < 0 || col >= cols || row < 0) return null;

    const visible = Array.from(container.children).filter((el) => !el.classList.contains("dragging"));
    const slot = visible[(row * cols) + col];
    if (!slot) return null;
    return slot.querySelector("img") ?? slot;
  });
}

function setup (options: Record<string, unknown> = {}, ids?: string[], cols?: number) {
  const grid = buildGrid(ids, cols);
  const onReorder = vi.fn();
  const sortable = new Sortable(grid.container, {
    itemSelector: ".sortable-thumbnail",
    handleSelector: ".sortable-handle",
    onReorder,
    ...options,
  });
  const internals = sortable as unknown as SortableInternals;
  return { ...grid, sortable, internals, onReorder };
}

beforeEach(() => {
  vi.useFakeTimers({ toFake: ["requestAnimationFrame", "cancelAnimationFrame", "performance"] });
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
  document.body.innerHTML = "";
});

describe("utility/Sortable", () => {
  describe("drag initiation", () => {
    it("starts a drag from the handle", () => {
      const { items, internals } = setup();
      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });

      expect(internals._drag).not.toBeNull();
      expect(items[0].item.classList.contains("dragging")).toBe(true);
      expect(document.querySelector(".sortable-ghost")).not.toBeNull();
      expect(placeholder()).not.toBeNull();
    });

    it("never starts a drag from the card itself, leaving its click untouched", () => {
      const { items, internals } = setup();

      const down = firePointer("pointerdown", items[0].img, { clientX: 50, clientY: 50 });
      expect(down.defaultPrevented).toBe(false);
      expect(internals._drag).toBeNull();
      expect(placeholder()).toBeNull();

      const click = new MouseEvent("click", { bubbles: true, cancelable: true });
      expect(items[0].link.dispatchEvent(click)).toBe(true);
    });

    it.each(["touch", "pen"])("starts a drag from the handle for %s pointers too", (pointerType) => {
      const { items, internals } = setup();
      firePointer("pointerdown", items[0].handle, { pointerType, clientX: 90, clientY: 10 });
      expect(internals._drag).not.toBeNull();
    });
  });

  describe("reordering", () => {
    it("moves the item to the slot under the pointer and reports the new order", () => {
      const { container, items, onReorder } = setup();
      mockGridLayout(container, 4);

      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });
      firePointer("pointermove", items[0].handle, { clientX: 260, clientY: 60 }); // right half of item 3
      vi.advanceTimersToNextFrame();
      firePointer("pointerup", items[0].handle, { clientX: 260, clientY: 60 });

      expect(currentOrder(container)).toEqual(["2", "3", "1", "4"]);
      expect(onReorder).toHaveBeenCalledWith(["2", "3", "1", "4"]);
    });

    it("restores the original order on pointercancel without reporting a reorder", () => {
      const { container, items, onReorder } = setup();
      mockGridLayout(container, 4);

      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });
      firePointer("pointermove", items[0].handle, { clientX: 260, clientY: 60 });
      vi.advanceTimersToNextFrame(); // placeholder moves next to item 3
      firePointer("pointercancel", items[0].handle, { clientX: 260, clientY: 60 });

      expect(currentOrder(container)).toEqual(["1", "2", "3", "4"]);
      expect(onReorder).not.toHaveBeenCalled();
    });
  });

  describe("slot-based targeting", () => {
    // Drags the item at `fromIndex` by its handle, moves to (x, y), lets the reposition
    // frame run, releases there, and returns the final DOM order.
    function dragTo (ctx: ReturnType<typeof setup>, fromIndex: number, x: number, y: number) {
      const handle = ctx.items[fromIndex].handle;
      firePointer("pointerdown", handle, { clientX: 1, clientY: 1 });
      firePointer("pointermove", handle, { clientX: x, clientY: y });
      vi.advanceTimersToNextFrame();
      firePointer("pointerup", handle, { clientX: x, clientY: y });
      return currentOrder(ctx.container);
    }

    it("moves forward one slot as soon as the pointer enters the next item", () => {
      const ctx = setup();
      mockGridLayout(ctx.container, 4);

      expect(dragTo(ctx, 0, 101, 60)).toEqual(["2", "1", "3", "4"]); // 1px into item 2
      expect(ctx.onReorder).toHaveBeenCalledWith(["2", "1", "3", "4"]);
    });

    it("moves backward one slot from anywhere inside the previous item", () => {
      const ctx = setup();
      mockGridLayout(ctx.container, 4);

      expect(dragTo(ctx, 1, 99, 60)).toEqual(["2", "1", "3", "4"]); // right edge of item 1
      expect(ctx.onReorder).toHaveBeenCalledWith(["2", "1", "3", "4"]);
    });

    it("gives the same destination for the left and right side of a target", () => {
      const left = setup();
      mockGridLayout(left.container, 4);
      const leftOrder = dragTo(left, 0, 205, 60);

      vi.restoreAllMocks();
      document.body.innerHTML = "";

      const right = setup();
      mockGridLayout(right.container, 4);
      const rightOrder = dragTo(right, 0, 295, 60);

      expect(leftOrder).toEqual(["2", "3", "1", "4"]);
      expect(rightOrder).toEqual(leftOrder);
    });

    describe("across a row boundary (3 columns: 1 2 3 / 4 5 6)", () => {
      const ids = ["1", "2", "3", "4", "5", "6"];

      it("dragging the first card of a row up onto the right side of the last card above takes that card's slot", () => {
        const ctx = setup({}, ids, 3);
        mockGridLayout(ctx.container, 3);

        // Right side of item 3 (row 1, col 3); halves would have read this as "after 3",
        // i.e. back in row 2.
        expect(dragTo(ctx, 3, 290, 60)).toEqual(["1", "2", "4", "3", "5", "6"]);
        expect(ctx.onReorder).toHaveBeenCalledWith(["1", "2", "4", "3", "5", "6"]);
      });

      it("dragging the last card of a row down onto the left side of the first card below takes that card's slot", () => {
        const ctx = setup({}, ids, 3);
        mockGridLayout(ctx.container, 3);

        // Left side of item 4 (row 2, col 1); halves would have read this as "before 4",
        // i.e. back in row 1.
        expect(dragTo(ctx, 2, 10, 180)).toEqual(["1", "2", "4", "3", "5", "6"]);
        expect(ctx.onReorder).toHaveBeenCalledWith(["1", "2", "4", "3", "5", "6"]);
      });

      it("jumps several slots across rows straight to the slot under the pointer", () => {
        const ctx = setup({}, ids, 3);
        mockGridLayout(ctx.container, 3);

        expect(dragTo(ctx, 0, 150, 180)).toEqual(["2", "3", "4", "5", "1", "6"]); // item 5's slot
      });
    });

    it("stays put while the pointer rests on the slot the placeholder just took", () => {
      const ctx = setup();
      mockGridLayout(ctx.container, 4);
      const handle = ctx.items[0].handle;

      firePointer("pointerdown", handle, { clientX: 1, clientY: 1 });
      for (let i = 0; i < 5; i++) {
        firePointer("pointermove", handle, { clientX: 250, clientY: 60 });
        vi.advanceTimersToNextFrame();
        expect(placeholder()?.previousSibling).toBe(ctx.items[2].item);
      }

      firePointer("pointerup", handle, { clientX: 250, clientY: 60 });
      expect(currentOrder(ctx.container)).toEqual(["2", "3", "1", "4"]);
    });

    it("flushes the release position into the same slot when the reposition frame never ran", () => {
      const ctx = setup();
      mockGridLayout(ctx.container, 4);
      const handle = ctx.items[0].handle;

      firePointer("pointerdown", handle, { clientX: 1, clientY: 1 });
      firePointer("pointermove", handle, { clientX: 201, clientY: 60 }); // left edge of item 3
      firePointer("pointerup", handle, { clientX: 201, clientY: 60 });

      expect(currentOrder(ctx.container)).toEqual(["2", "3", "1", "4"]);
      expect(ctx.onReorder).toHaveBeenCalledWith(["2", "3", "1", "4"]);
    });
  });

  describe("final pointer position on release", () => {
    it("lands the item at the release position even when the pending reposition frame never ran", () => {
      const { container, items, internals, onReorder } = setup();
      mockGridLayout(container, 4);

      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });
      firePointer("pointermove", items[0].handle, { clientX: 260, clientY: 60 });

      // The reposition is queued but hasn't run: the placeholder is still in the original slot.
      expect(internals._rafId).not.toBe(0);
      expect(placeholder()?.nextSibling).toBe(items[0].item);

      firePointer("pointerup", items[0].handle, { clientX: 260, clientY: 60 });

      expect(currentOrder(container)).toEqual(["2", "3", "1", "4"]);
      expect(onReorder).toHaveBeenCalledWith(["2", "3", "1", "4"]);
      expect(internals._rafId).toBe(0);
    });

    it("restores the original order on pointercancel in the same situation, discarding the pending frame", () => {
      const { container, items, internals, onReorder } = setup();
      const elementFromPoint = mockGridLayout(container, 4);

      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });
      firePointer("pointermove", items[0].handle, { clientX: 260, clientY: 60 });
      expect(internals._rafId).not.toBe(0);

      firePointer("pointercancel", items[0].handle, { clientX: 260, clientY: 60 });

      expect(currentOrder(container)).toEqual(["1", "2", "3", "4"]);
      expect(onReorder).not.toHaveBeenCalled();
      expect(internals._rafId).toBe(0);

      elementFromPoint.mockClear();
      vi.advanceTimersToNextFrame();
      expect(elementFromPoint).not.toHaveBeenCalled(); // the queued reposition never runs
    });
  });

  describe("ghost and placeholder", () => {
    it("sizes the placeholder from the dragged item and keeps it out of the order", () => {
      const { items, sortable } = setup();
      firePointer("pointerdown", items[1].handle, { clientX: 190, clientY: 10 });

      const ph = placeholder();
      expect(ph?.classList.contains("sortable-placeholder")).toBe(true);
      expect(ph?.classList.contains("sortable-thumbnail")).toBe(false);
      expect(ph?.style.width).toBe(`${ITEM_WIDTH}px`);
      expect(ph?.style.height).toBe(`${ITEM_HEIGHT}px`);
      expect(ph?.hasAttribute("data-id")).toBe(false);

      sortable.refresh();
      expect(sortable.order).toEqual(["1", "2", "3", "4"]);
    });

    it("sizes the ghost from the dragged item and strips the dragging state from it", () => {
      const { items } = setup();
      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });

      const ghost = document.querySelector<HTMLElement>(".sortable-ghost");
      expect(ghost?.style.width).toBe(`${ITEM_WIDTH}px`);
      expect(ghost?.style.height).toBe(`${ITEM_HEIGHT}px`);
      expect(ghost?.classList.contains("dragging")).toBe(false);
    });

    it("keeps the item's own classes on the ghost, so page styles can still target it", () => {
      const { items } = setup();
      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });

      const ghost = document.querySelector<HTMLElement>(".sortable-ghost");
      expect(ghost?.classList.contains("sortable-thumbnail")).toBe(true);
      expect(ghost?.parentElement).toBe(document.body);
    });

    it.each(["pointerup", "pointercancel"])("removes the ghost and placeholder after %s", (type) => {
      const { items } = setup();
      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });
      firePointer(type, items[0].handle, { clientX: 90, clientY: 10 });

      expect(document.querySelector(".sortable-ghost")).toBeNull();
      expect(placeholder()).toBeNull();
      expect(items[0].item.classList.contains("dragging")).toBe(false);
    });

    it("never includes the placeholder in the final order", () => {
      const { container, items, sortable } = setup();
      mockGridLayout(container, 4);
      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });
      firePointer("pointerup", items[0].handle, { clientX: 360, clientY: 60 });

      expect(sortable.order).toEqual(["2", "3", "4", "1"]);
    });
  });

  describe("destroy()", () => {
    it("tears down an active drag and leaves nothing running", () => {
      const { container, items, sortable, internals } = setup();
      mockGridLayout(container, 4);
      vi.spyOn(window, "innerHeight", "get").mockReturnValue(800);
      const scrollBy = vi.spyOn(window, "scrollBy").mockImplementation(() => {});

      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });
      firePointer("pointermove", items[0].handle, { clientX: 260, clientY: 790 }); // queues reposition + autoscroll
      sortable.destroy();

      expect(document.querySelector(".sortable-ghost")).toBeNull();
      expect(placeholder()).toBeNull();
      expect(currentOrder(container)).toEqual(["1", "2", "3", "4"]);
      expect(internals._drag).toBeNull();
      expect(internals._rafId).toBe(0);
      expect(internals._scrollRafId).toBe(0);
      expect(internals._lastPointer).toBeNull();

      vi.advanceTimersToNextFrame();
      expect(scrollBy).not.toHaveBeenCalled();

      firePointer("pointerdown", items[0].handle, { clientX: 90, clientY: 10 });
      expect(internals._drag).toBeNull(); // handlers are unbound
    });
  });

  describe("edge autoscroll", () => {
    function autoscrollSetup (startScrollY = 1000) {
      const ctx = setup();
      vi.spyOn(window, "innerHeight", "get").mockReturnValue(800);
      let scrollY = startScrollY;
      vi.spyOn(window, "scrollY", "get").mockImplementation(() => scrollY);
      const scrollBy = vi.spyOn(window, "scrollBy").mockImplementation(((_x: number, y: number) => {
        scrollY = Math.max(0, scrollY + y);
      }) as typeof window.scrollBy);
      const elementFromPoint = vi.spyOn(document, "elementFromPoint").mockReturnValue(null);

      firePointer("pointerdown", ctx.items[0].handle, { clientX: 50, clientY: 400 });
      return { ...ctx, scrollBy, elementFromPoint, setScrollY: (y: number) => { scrollY = y; }, scrollY: () => scrollY };
    }

    function moveTo (handle: Element, clientY: number, clientX = 50) {
      firePointer("pointermove", handle, { clientX, clientY });
    }

    it("does not scroll while the pointer stays away from the edges", () => {
      const { items, scrollBy } = autoscrollSetup();
      moveTo(items[0].handle, 400);
      vi.advanceTimersToNextFrame();
      vi.advanceTimersToNextFrame();
      expect(scrollBy).not.toHaveBeenCalled();
    });

    it("scrolls down near the bottom edge and up near the top edge", () => {
      const { items, scrollBy } = autoscrollSetup();

      moveTo(items[0].handle, 790);
      vi.advanceTimersToNextFrame();
      expect(scrollBy.mock.calls.at(-1)?.[1]).toBeGreaterThan(0);

      moveTo(items[0].handle, 10);
      vi.advanceTimersToNextFrame();
      expect(scrollBy.mock.calls.at(-1)?.[1]).toBeLessThan(0);
    });

    it("scrolls faster the closer the pointer is to the edge", () => {
      const { items, scrollBy } = autoscrollSetup();

      moveTo(items[0].handle, 760); // just inside the zone
      vi.advanceTimersToNextFrame();
      const slow = scrollBy.mock.calls.at(-1)?.[1] as number;

      moveTo(items[0].handle, 798); // almost at the edge
      vi.advanceTimersToNextFrame();
      const fast = scrollBy.mock.calls.at(-1)?.[1] as number;

      expect(slow).toBeGreaterThan(0);
      expect(fast).toBeGreaterThan(slow);
    });

    it("caps the speed at the maximum for a captured pointer above the viewport", () => {
      const atEdge = autoscrollSetup();
      moveTo(atEdge.items[0].handle, 0);
      vi.advanceTimersToNextFrame();
      const edgeDelta = atEdge.scrollBy.mock.calls.at(-1)?.[1] as number;

      for (const y of [-1, -200, -5000]) {
        moveTo(atEdge.items[0].handle, y);
        vi.advanceTimersToNextFrame();
        expect(atEdge.scrollBy.mock.calls.at(-1)?.[1]).toBeCloseTo(edgeDelta);
      }
      // 1200px/s over the 16ms first frame
      expect(edgeDelta).toBeCloseTo(-19.2);
    });

    it("caps the speed at the maximum for a captured pointer below the viewport", () => {
      const atEdge = autoscrollSetup();
      moveTo(atEdge.items[0].handle, 800); // innerHeight
      vi.advanceTimersToNextFrame();
      const edgeDelta = atEdge.scrollBy.mock.calls.at(-1)?.[1] as number;

      for (const y of [801, 1200, 9000]) {
        moveTo(atEdge.items[0].handle, y);
        vi.advanceTimersToNextFrame();
        expect(atEdge.scrollBy.mock.calls.at(-1)?.[1]).toBeCloseTo(edgeDelta);
      }
      expect(edgeDelta).toBeCloseTo(19.2);
    });

    it("keeps scrolling while the pointer is held in the zone", () => {
      const { items, scrollBy } = autoscrollSetup();
      moveTo(items[0].handle, 790);
      vi.advanceTimersToNextFrame();
      vi.advanceTimersToNextFrame();
      vi.advanceTimersToNextFrame();
      expect(scrollBy).toHaveBeenCalledTimes(3);
    });

    it("stops promptly once the pointer leaves the zone", () => {
      const { items, scrollBy, internals } = autoscrollSetup();
      moveTo(items[0].handle, 790);
      vi.advanceTimersToNextFrame();
      moveTo(items[0].handle, 400);
      vi.advanceTimersToNextFrame();
      vi.advanceTimersToNextFrame();

      expect(scrollBy).toHaveBeenCalledTimes(1);
      expect(internals._scrollRafId).toBe(0);
    });

    it("stops at the top of the page", () => {
      const { items, scrollBy, setScrollY } = autoscrollSetup();
      setScrollY(0);
      moveTo(items[0].handle, 10);
      vi.advanceTimersToNextFrame();
      vi.advanceTimersToNextFrame();
      expect(scrollBy).toHaveBeenCalledTimes(1); // the attempt that found nothing left to scroll
    });

    it.each(["pointerup", "pointercancel"])("stops on %s and leaves no state behind", (type) => {
      const { items, scrollBy, internals } = autoscrollSetup();
      moveTo(items[0].handle, 790);
      firePointer(type, items[0].handle, { clientX: 50, clientY: 790 });

      vi.advanceTimersToNextFrame();
      vi.advanceTimersToNextFrame();
      expect(scrollBy).not.toHaveBeenCalled();
      expect(internals._drag).toBeNull();
      expect(internals._rafId).toBe(0);
      expect(internals._scrollRafId).toBe(0);
      expect(internals._lastPointer).toBeNull();
    });

    it("keeps updating the drop slot while the page scrolls under a stationary pointer", () => {
      const { container, items, elementFromPoint, onReorder, scrollY } = autoscrollSetup();
      // The single row of items starts just below the pointer (top at y=810) and moves up
      // as the page scrolls; the pointer stays at y=790, so the row reaches it after
      // the first scroll step.
      elementFromPoint.mockRestore();
      mockGridLayout(container, 4, () => 810 - (scrollY() - 1000));

      moveTo(items[0].handle, 790, 360); // where item 4's slot will scroll in
      vi.advanceTimersToNextFrame();
      expect(placeholder()?.nextSibling).toBe(items[0].item); // nothing under the pointer yet

      // The row scrolls in under the unmoved pointer; no pointermove is sent.
      vi.advanceTimersToNextFrame();
      expect(placeholder()?.previousSibling).toBe(items[3].item);

      // Still stationary: the placeholder now fills the slot under the pointer and stays put.
      vi.advanceTimersToNextFrame();
      vi.advanceTimersToNextFrame();
      expect(placeholder()?.previousSibling).toBe(items[3].item);

      firePointer("pointerup", items[0].handle, { clientX: 360, clientY: 790 });
      expect(currentOrder(container)).toEqual(["2", "3", "4", "1"]);
      expect(onReorder).toHaveBeenCalledWith(["2", "3", "4", "1"]);
    });
  });
});
