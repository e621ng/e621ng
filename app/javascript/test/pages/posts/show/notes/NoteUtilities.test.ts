import { beforeEach, describe, expect, it, vi } from "vitest";
import { renderNotesPage, stubGeometry } from "./fixtures";

async function load () {
  vi.resetModules();
  const NoteUtilities = (await import("@/pages/posts/show/notes/NoteUtilities")).default;
  const LStorage = (await import("@/utility/storage/Local")).default;
  return { NoteUtilities, LStorage };
}

describe("NoteUtilities", () => {
  beforeEach(() => {
    renderNotesPage();
  });

  it("seeds the container enabled attribute from storage", async () => {
    stubGeometry();
    const { NoteUtilities } = await load();
    expect(NoteUtilities.container.attr("enabled")).toBe("true");
    expect(NoteUtilities.visible).toBe(true);
  });

  it("reads a stored preference for hidden notes", async () => {
    stubGeometry();
    localStorage.setItem("e6.posts.notes", "false");
    const { NoteUtilities } = await load();
    expect(NoteUtilities.visible).toBe(false);
    expect(NoteUtilities.container.attr("enabled")).toBe("false");
  });

  it("persists visibility, updates the attribute and fires note:visible", async () => {
    stubGeometry();
    const { NoteUtilities, LStorage } = await load();
    const events: string[] = [];
    $("#note-container").on("note:visible:true note:visible:false", (event) => { events.push(event.type); });

    NoteUtilities.visible = false;
    expect(NoteUtilities.container.attr("enabled")).toBe("false");
    expect(LStorage.Posts.Notes).toBe(false);
    expect(localStorage.getItem("e6.posts.notes")).toBe("false");

    NoteUtilities.visible = true;
    expect(events).toEqual(["note:visible:false", "note:visible:true"]);
  });

  it("toggles editing mode: attribute, events, translated section, and abort", async () => {
    stubGeometry();
    const { NoteUtilities } = await load();
    const events: string[] = [];
    $("#note-container").on("note:editing:true note:editing:false note:abort", (event) => { events.push(event.type); });
    const section = $("#mark-as-translated-section");

    NoteUtilities.toggleEditing();
    expect(NoteUtilities.editing).toBe(true);
    expect(NoteUtilities.container.attr("editing")).toBe("true");
    expect(section.css("display")).not.toBe("none");

    NoteUtilities.toggleEditing();
    expect(NoteUtilities.editing).toBe(false);
    expect(NoteUtilities.container.attr("editing")).toBe("false");
    expect(section.css("display")).toBe("none");
    expect(events).toEqual(["note:editing:true", "note:editing:false", "note:abort"]);
  });

  it("reflects dragging and resizing on the container", async () => {
    stubGeometry();
    const { NoteUtilities } = await load();

    NoteUtilities.dragging = true;
    expect(NoteUtilities.container.attr("dragging")).toBe("true");
    NoteUtilities.dragging = false;
    expect(NoteUtilities.container.attr("dragging")).toBe("false");

    NoteUtilities.resizing = true;
    expect(NoteUtilities.container.attr("resizing")).toBe("true");
  });

  it("computes the scale ratio from the original image width", async () => {
    stubGeometry({ width: 800 });
    const { NoteUtilities } = await load();
    expect(NoteUtilities.scaleRatio).toBe(0.5);
    expect(NoteUtilities.noteMinWidth).toBe(10);
    expect(NoteUtilities.containerDimensions).toEqual({ width: 800, height: 600 });
    expect(NoteUtilities.containerOffset).toEqual({ x: 0, y: 0 });
  });

  it("invalidates cached measurements when the container resizes", async () => {
    const geometry = stubGeometry({ width: 800 });
    const { NoteUtilities } = await load();
    expect(NoteUtilities.scaleRatio).toBe(0.5);

    geometry.setContainerWidth(400);
    expect(NoteUtilities.scaleRatio).toBe(0.5); // Still cached

    const scaled = vi.fn();
    $("<div class='note-box'>").appendTo(NoteUtilities.container).on("note:scale", scaled);
    geometry.fireResize();
    expect(NoteUtilities.scaleRatio).toBe(0.25);
    expect(NoteUtilities.containerDimensions.width).toBe(400);
    expect(scaled).toHaveBeenCalledTimes(1);
  });
});
