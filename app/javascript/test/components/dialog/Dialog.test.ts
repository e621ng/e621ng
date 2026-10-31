import { beforeEach, describe, expect, it, vi } from "vitest";
import type DialogClass from "@/components/dialog";

type ObserverCallback = (entries: Partial<ResizeObserverEntry>[]) => void;

interface Geometry {
  setContainer (width: number, height: number): void;
  observed: Element[];
  unobserved: Element[];
  resize (target: Element, blockSize: number): void;
}

/** jsdom has no layout: fake the container size, content observer, frames, and pointer capture */
function stubGeometry ({ width = 800, height = 600 } = {}): Geometry {
  let containerWidth = width, containerHeight = height;
  const observed: Element[] = [], unobserved: Element[] = [];
  const callbacks: ObserverCallback[] = [];

  vi.stubGlobal("ResizeObserver", class {
    constructor (callback: ObserverCallback) { callbacks.push(callback); }
    observe (target: Element) { observed.push(target); }
    unobserve (target: Element) { unobserved.push(target); }
    disconnect () {}
  });

  vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) => {
    callback(0);
    return 1;
  });
  vi.stubGlobal("cancelAnimationFrame", () => {});

  vi.spyOn($.fn, "innerWidth").mockImplementation(() => containerWidth);
  vi.spyOn($.fn, "innerHeight").mockImplementation(() => containerHeight);

  Element.prototype.setPointerCapture = () => {};
  Element.prototype.releasePointerCapture = () => {};

  return {
    setContainer (w, h) { containerWidth = w; containerHeight = h; },
    observed,
    unobserved,
    resize (target, blockSize) {
      for (const callback of callbacks)
        callback([{ target, borderBoxSize: [{ blockSize, inlineSize: 0 }], contentRect: { height: blockSize } as DOMRectReadOnly }]);
    },
  };
}

function content (attrs: Record<string, string | number> = {}): JQuery<HTMLElement> {
  return $("<div>").attr(attrs).appendTo("body");
}

function pointer (type: string, props: Record<string, number>): JQuery.Event {
  return $.Event(type, props) as JQuery.Event;
}

describe("Dialog", () => {
  let Dialog: typeof DialogClass;
  let geometry: Geometry;

  beforeEach(async () => {
    geometry = stubGeometry();
    Dialog = (await import("@/components/dialog")).default;
  });

  describe("construction", () => {
    it("builds the frame inside a single shared container", () => {
      const a = new Dialog(content());
      const b = new Dialog(content());

      expect($("#dialog-container").length).toBe(1);
      expect($("#dialog-container > .dialog").length).toBe(2);
      expect(a.$dialog.hasClass("hidden")).toBe(true);
      expect(a.$dialog.attr("role")).toBe("dialog");
      expect(a.$dialog.attr("aria-labelledby")).toBe(`dialog-title-${a.id}`);
      expect(a.$dialog.attr("data-id")).toBe(String(a.id));
      expect(a.$dialog.find(".dialog-content").children()[0]).toBe(a.$element[0]);
      expect(b.id).not.toBe(a.id);
    });

    it("reads parameters from data attributes, letting explicit ones win", () => {
      const dialog = new Dialog(content({ "data-title": "From data", "data-width": 300 }), { title: "Explicit" });

      expect(dialog.$dialog.find(".dialog-header span").text()).toBe("Explicit");
      expect(dialog.width).toBe(300);
    });

    it("does not mutate the caller's parameters", () => {
      const params = { title: "Kept" };
      new Dialog(content({ "data-width": 300 }), params);
      expect(params).toEqual({ title: "Kept" });
    });

    it("sets the title as text, not markup", () => {
      const dialog = new Dialog(content(), { title: "<b>x</b>" });
      expect(dialog.$dialog.find(".dialog-header span").html()).toBe("&lt;b&gt;x&lt;/b&gt;");
      dialog.setTitle("<i>y</i>");
      expect(dialog.$dialog.find(".dialog-header span").text()).toBe("<i>y</i>");
    });

    it("opens immediately with startOpen", () => {
      const dialog = new Dialog(content({ "data-start-open": "true" }));
      expect(dialog.isOpen).toBe(true);
      expect(dialog.$dialog.hasClass("hidden")).toBe(false);
    });
  });

  describe("resolvePosition", () => {
    it("maps every label, including the zero-valued ones", () => {
      expect(Dialog.resolvePosition("top")).toBe(0);
      expect(Dialog.resolvePosition("left")).toBe(0);
      expect(Dialog.resolvePosition("center")).toBe(0.5);
      expect(Dialog.resolvePosition("bottom")).toBe(1);
      expect(Dialog.resolvePosition("right")).toBe(1);
    });

    it("clamps numbers and numeric strings", () => {
      expect(Dialog.resolvePosition(0.25)).toBe(0.25);
      expect(Dialog.resolvePosition(7)).toBe(1);
      expect(Dialog.resolvePosition(-1)).toBe(0);
      expect(Dialog.resolvePosition("0.75")).toBe(0.75);
    });

    it("centers on unknown input", () => {
      expect(Dialog.resolvePosition("nope")).toBe(0.5);
      expect(Dialog.resolvePosition("")).toBe(0.5);
      expect(Dialog.resolvePosition(undefined)).toBe(0.5);
    });
  });

  describe("placement", () => {
    // Container 800x600, dialog 300 wide, fallback height 200 while unmeasurable
    it("places 'top left' in the corner", () => {
      const dialog = new Dialog(content({ "data-width": 300 }), { position: "top left" });
      expect(dialog.$dialog[0].style.left).toBe("0px");
      expect(dialog.$dialog[0].style.top).toBe("0px");
    });

    it("places 'bottom right' against the far edges", () => {
      const dialog = new Dialog(content({ "data-width": 300 }), { position: "bottom right" });
      expect(dialog.$dialog[0].style.left).toBe("500px");
      expect(dialog.$dialog[0].style.top).toBe("400px");
    });

    it("centers by default and on a single-word position", () => {
      const dialog = new Dialog(content({ "data-width": 300 }), { position: "center" });
      expect(dialog.$dialog[0].style.left).toBe("250px");
      expect(dialog.$dialog[0].style.top).toBe("200px");
    });
  });

  describe("sizing", () => {
    it("adds the header to an explicit height and does not observe the content", () => {
      const dialog = new Dialog(content({ "data-height": 100 }));
      expect(dialog.height).toBe(132);
      expect(dialog.$dialog[0].style.height).toBe("132px");
      expect(geometry.observed).toHaveLength(0);
    });

    it("follows the content height when none is given", () => {
      const dialog = new Dialog(content({ "data-width": 300 }));
      expect(geometry.observed).toEqual([dialog.$element[0]]);
      expect(dialog.$element.attr("data-id")).toBe(String(dialog.id));

      geometry.resize(dialog.$element[0], 268);
      expect(dialog.height).toBe(300);
      expect(dialog.$dialog[0].style.height).toBe("300px");
      expect(dialog.$dialog[0].style.top).toBe("150px");
    });

    it("ignores a zero content size from a hidden dialog", () => {
      const dialog = new Dialog(content());
      geometry.resize(dialog.$element[0], 0);
      expect(dialog.height).toBe(200);
    });
  });

  describe("visibility", () => {
    it("opens, focuses, and fires dialog:open", () => {
      const dialog = new Dialog(content());
      const opened = vi.fn();
      dialog.$element.on("dialog:open", opened);

      dialog.open();
      expect(dialog.isOpen).toBe(true);
      expect(dialog.$dialog.hasClass("hidden")).toBe(false);
      expect(document.activeElement).toBe(dialog.$dialog[0]);
      expect(opened).toHaveBeenCalledOnce();
    });

    it("closes with dialog:close, unless quiet", () => {
      const dialog = new Dialog(content());
      const closed = vi.fn();
      dialog.$element.on("dialog:close", closed);

      dialog.open();
      dialog.close();
      expect(dialog.isOpen).toBe(false);
      expect(dialog.$dialog.hasClass("hidden")).toBe(true);
      expect(closed).toHaveBeenCalledOnce();

      dialog.open();
      dialog.close(true);
      expect(closed).toHaveBeenCalledOnce();
    });

    it("toggles and accepts the isOpen setter", () => {
      const dialog = new Dialog(content());
      dialog.toggle();
      expect(dialog.isOpen).toBe(true);
      dialog.toggle();
      expect(dialog.isOpen).toBe(false);
      dialog.isOpen = true;
      expect(dialog.$dialog.hasClass("hidden")).toBe(false);
    });

    it("closes from the X button and the Escape key", () => {
      const dialog = new Dialog(content());
      dialog.open();
      dialog.$dialog.find(".dialog-header button").trigger("click");
      expect(dialog.isOpen).toBe(false);

      dialog.open();
      dialog.$dialog.trigger($.Event("keydown", { key: "Escape" }));
      expect(dialog.isOpen).toBe(false);
    });
  });

  describe("stacking", () => {
    const zIndex = (dialog: DialogClass) => dialog.$dialog[0].style.zIndex;

    it("stacks in creation order and raises on pointerdown", () => {
      const a = new Dialog(content()), b = new Dialog(content()), c = new Dialog(content());
      expect([zIndex(a), zIndex(b), zIndex(c)]).toEqual(["250", "251", "252"]);

      a.$dialog.trigger("pointerdown");
      expect([zIndex(a), zIndex(b), zIndex(c)]).toEqual(["252", "250", "251"]);
    });

    it("raises on open and restacks after destroy", () => {
      const a = new Dialog(content()), b = new Dialog(content()), c = new Dialog(content());
      a.open();
      expect(zIndex(a)).toBe("252");

      b.destroy();
      expect([zIndex(c), zIndex(a)]).toEqual(["250", "251"]);
    });
  });

  describe("dragging", () => {
    function build () {
      const dialog = new Dialog(content({ "data-width": 300 }));
      const header = dialog.$dialog.find(".dialog-header");
      return { dialog, header, style: dialog.$dialog[0].style };
    }

    it("moves with the pointer and clamps to the container", () => {
      const { dialog, header, style } = build();
      header.trigger(pointer("pointerdown", { button: 0, pointerId: 1, clientX: 100, clientY: 100 }));
      expect(dialog.$dialog.hasClass("dragging")).toBe(true);

      $(document).trigger(pointer("pointermove", { pointerId: 1, clientX: 150, clientY: 120 }));
      expect(style.left).toBe("300px");
      expect(style.top).toBe("220px");

      $(document).trigger(pointer("pointermove", { pointerId: 1, clientX: 5000, clientY: -5000 }));
      expect(style.left).toBe("500px");
      expect(style.top).toBe("0px");

      $(document).trigger(pointer("pointerup", { pointerId: 1 }));
      expect(dialog.$dialog.hasClass("dragging")).toBe(false);
    });

    it("announces every move on the window", () => {
      const { header } = build();
      const moved = vi.fn();
      window.addEventListener("dialog:move", moved);

      header.trigger(pointer("pointerdown", { button: 0, pointerId: 1, clientX: 100, clientY: 100 }));
      $(document).trigger(pointer("pointermove", { pointerId: 1, clientX: 150, clientY: 120 }));
      $(document).trigger(pointer("pointerup", { pointerId: 1 }));
      expect(moved).toHaveBeenCalledTimes(1);

      // Earlier specs leave dialogs behind, and a resize repositions all of them
      geometry.setContainer(1000, 600);
      $(window).trigger("resize");
      expect(moved.mock.calls.length).toBeGreaterThan(1);

      window.removeEventListener("dialog:move", moved);
    });

    it("ignores other pointers, non-primary buttons, and the close button", () => {
      const { dialog, header, style } = build();

      header.trigger(pointer("pointerdown", { button: 2, pointerId: 1, clientX: 0, clientY: 0 }));
      expect(dialog.$dialog.hasClass("dragging")).toBe(false);

      header.find("button").trigger(pointer("pointerdown", { button: 0, pointerId: 1, clientX: 0, clientY: 0 }));
      expect(dialog.$dialog.hasClass("dragging")).toBe(false);

      header.trigger(pointer("pointerdown", { button: 0, pointerId: 1, clientX: 100, clientY: 100 }));
      $(document).trigger(pointer("pointermove", { pointerId: 2, clientX: 900, clientY: 900 }));
      expect(style.left).toBe("250px");
      $(document).trigger(pointer("pointerup", { pointerId: 2 }));
      expect(dialog.$dialog.hasClass("dragging")).toBe(true);
    });

    it("stops when the dialog closes or the window loses focus", () => {
      const { dialog, header } = build();
      header.trigger(pointer("pointerdown", { button: 0, pointerId: 1, clientX: 0, clientY: 0 }));
      dialog.close();
      expect(dialog.$dialog.hasClass("dragging")).toBe(false);

      header.trigger(pointer("pointerdown", { button: 0, pointerId: 1, clientX: 0, clientY: 0 }));
      $(window).triggerHandler("blur"); // jsdom does not implement window.blur()
      expect(dialog.$dialog.hasClass("dragging")).toBe(false);
    });

    it("keeps the dragged position proportionally across container resizes", () => {
      const { header, style } = build();
      header.trigger(pointer("pointerdown", { button: 0, pointerId: 1, clientX: 0, clientY: 0 }));
      $(document).trigger(pointer("pointermove", { pointerId: 1, clientX: 250, clientY: 200 }));
      $(document).trigger(pointer("pointerup", { pointerId: 1 }));
      expect(style.left).toBe("500px"); // Right edge

      geometry.setContainer(1000, 600);
      $(window).trigger("resize");
      expect(style.left).toBe("700px");
    });
  });

  describe("container resize", () => {
    it("repositions every dialog, even after another one was destroyed", () => {
      const a = new Dialog(content({ "data-width": 300 }));
      const b = new Dialog(content({ "data-width": 300 }));
      expect(a.$dialog[0].style.left).toBe("250px");

      b.destroy();
      geometry.setContainer(1000, 600);
      $(window).trigger("resize");
      expect(a.$dialog[0].style.left).toBe("350px");
    });
  });

  describe("destroy", () => {
    it("fires dialog:destroy, stops observing, and removes the frame", () => {
      const dialog = new Dialog(content());
      const destroyed = vi.fn();
      dialog.$element.on("dialog:destroy", destroyed);
      const element = dialog.$element[0];

      dialog.destroy();
      expect(destroyed).toHaveBeenCalledOnce();
      expect(geometry.unobserved).toEqual([element]);
      expect($("#dialog-container > .dialog").length).toBe(0);
      expect(document.body.contains(element)).toBe(false);
    });
  });
});
