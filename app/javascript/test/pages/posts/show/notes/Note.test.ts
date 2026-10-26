import { beforeEach, describe, expect, it, vi } from "vitest";
import { SAMPLE_NOTE, renderNotesPage, stubGeometry } from "./fixtures";

async function load () {
  vi.resetModules();
  const Note = (await import("@/pages/posts/show/notes/Note")).default;
  const NoteUtilities = (await import("@/pages/posts/show/notes/NoteUtilities")).default;
  return { Note, NoteUtilities };
}

function stagedElement (overrides: Record<string, string | undefined> = {}): HTMLElement {
  const element = document.createElement("article");
  element.className = "staged-note";
  const data: Record<string, string | undefined> = {
    id: "7", x: "200", y: "200", width: "400", height: "200", body: "hello", ...overrides,
  };
  for (const [key, value] of Object.entries(data))
    if (value !== undefined) element.dataset[key] = value;
  element.innerHTML = "<p>hello</p>";
  return element;
}

describe("Note", () => {
  beforeEach(() => {
    renderNotesPage({ notes: [] });
    stubGeometry(); // 800px container for a 1600px image: scale 0.5
  });

  describe("fromStaged", () => {
    it("parses the data attributes into numbers and renders the body html", async () => {
      const { Note } = await load();
      const note = Note.fromStaged(stagedElement());

      expect(note).not.toBeNull();
      expect(note!.id).toBe("7");
      expect(note!.x).toBe(200);
      expect(note!.width).toBe(400);
      expect(note!.content).toBe("hello");
      expect(note!.isTemporary).toBe(false);
      expect(note!.$body.html()).toBe("<p>hello</p>");
      expect(Note.getByID("7")).toBe(note);
    });

    it("returns null for elements missing a required field", async () => {
      const { Note } = await load();
      expect(Note.fromStaged(stagedElement({ width: undefined }))).toBeNull();
      expect(Note.getByID("7")).toBeNull();
    });
  });

  it("builds the box with handles and a body, scaled to the container", async () => {
    const { Note } = await load();
    const note = Note.fromStaged(stagedElement())!;

    const box = document.querySelector("#note-container .note-box") as HTMLElement;
    expect(box).toBe(note.$box[0]);
    expect(box.getAttribute("nid")).toBe("7");
    expect(box.classList.contains("hidden")).toBe(false);
    expect(box.querySelector(".note-handle-nw")).not.toBeNull();
    expect(box.querySelector(".note-handle-se")).not.toBeNull();
    expect(box.querySelector(".note-body")).toBe(note.$body[0]);

    expect(box.style.left).toBe("100px");
    expect(box.style.top).toBe("100px");
    expect(box.style.width).toBe("200px");
    expect(box.style.height).toBe("100px");
    expect(note.relX).toBe(100);
    expect(note.relWidth).toBe(200);
  });

  it("marks small notes as tiny", async () => {
    const { Note } = await load();
    const note = Note.fromStaged(stagedElement({ width: "100", height: "100" }))!;
    expect(note.$box.hasClass("tiny")).toBe(true);

    note.resizeTo({ width: 80, height: 80 });
    expect(note.$box.hasClass("tiny")).toBe(false);
  });

  describe("container-relative setters", () => {
    it("moveTo converts screen pixels to image pixels", async () => {
      const { Note } = await load();
      const note = Note.fromStaged(stagedElement())!;

      note.moveTo({ x: 50, y: 75 });
      expect(note.x).toBe(100);
      expect(note.y).toBe(150);
      expect(note.$box[0].style.left).toBe("50px");
      expect(note.$box[0].style.top).toBe("75px");
    });

    it("adjustTo rounds and keeps dimensions at least 1", async () => {
      const { Note } = await load();
      const note = Note.fromStaged(stagedElement())!;

      note.adjustTo({ x: 10, y: 10, width: 0, height: 0.2 });
      expect(note.x).toBe(20);
      expect(note.width).toBe(1);
      expect(note.height).toBe(1);
      expect(note.$box[0].style.width).toBe("0px");
    });
  });

  describe("backup / restore", () => {
    it("restores geometry, content and html, and clears the pending flag", async () => {
      const { Note } = await load();
      const note = Note.fromStaged(stagedElement())!;
      expect(note.hasBackup).toBe(false);

      note.backup();
      note.moveTo({ x: 0, y: 0 });
      note.content = "changed";
      note.$body.html("<p>changed</p>");
      note.pending = true;
      expect(note.hasBackup).toBe(true);

      note.restore();
      expect(note.x).toBe(200);
      expect(note.y).toBe(200);
      expect(note.content).toBe("hello");
      expect(note.$body.html()).toBe("<p>hello</p>");
      expect(note.$box[0].style.left).toBe("100px");
      expect(note.pending).toBe(false);
      expect(note.hasBackup).toBe(false);
    });

    it("restore is a no-op without a backup", async () => {
      const { Note } = await load();
      const note = Note.fromStaged(stagedElement())!;
      note.moveTo({ x: 0, y: 0 });
      note.restore();
      expect(note.x).toBe(0);
    });
  });

  it("applyServerData re-keys a temporary note under its real id", async () => {
    const { Note } = await load();
    const note = Note.createTemporary();
    expect(note.isTemporary).toBe(true);
    expect(Note.getByID(note.id)).toBe(note);
    const tempID = note.id;

    note.backup();
    note.pending = true;
    note.applyServerData({ ...SAMPLE_NOTE, id: 42, post_id: 1 }, "<p>hello</p>");

    expect(note.id).toBe("42");
    expect(note.isTemporary).toBe(false);
    expect(note.$box.attr("nid")).toBe("42");
    expect(Note.getByID("42")).toBe(note);
    expect(Note.getByID(tempID)).toBeNull();
    expect(note.x).toBe(200);
    expect(note.$body.html()).toBe("<p>hello</p>");
    expect(note.$box[0].style.left).toBe("100px");
    expect(note.pending).toBe(false);
    expect(note.hasBackup).toBe(false);
  });

  it("destroy removes the box and the index entry", async () => {
    const { Note } = await load();
    const note = Note.fromStaged(stagedElement())!;
    note.destroy();
    expect(document.querySelector(".note-box")).toBeNull();
    expect(Note.getByID("7")).toBeNull();
  });

  it("rescales when the container fires note:scale", async () => {
    const { Note, NoteUtilities } = await load();
    const geometry = stubGeometry();
    const note = Note.fromStaged(stagedElement())!;
    expect(note.$box[0].style.left).toBe("100px");

    geometry.setContainerWidth(400);
    void NoteUtilities.container; // Ensure the observer is registered
    geometry.fireResize();
    expect(note.$box[0].style.left).toBe("50px");
    expect(note.$box[0].style.width).toBe("100px");
  });

  it("shifts the body left when it would overflow the container", async () => {
    const { Note } = await load();
    const note = Note.fromStaged(stagedElement())!;

    vi.spyOn($.fn, "is").mockReturnValue(true);
    vi.spyOn($.fn, "position").mockReturnValue({ left: 600, top: 0 });
    vi.spyOn($.fn, "outerWidth").mockReturnValue(500);
    vi.spyOn($.fn, "outerHeight").mockReturnValue(50);

    note.adjustBodyPosition();
    expect(note.$body[0].style.left).toBe("-310px");
    expect(note.$body[0].style.top).toBe("");
  });
});
