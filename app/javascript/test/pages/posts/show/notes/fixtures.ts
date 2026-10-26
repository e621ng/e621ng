import { vi } from "vitest";
import { setSiteData } from "../../../../helpers";

export interface StagedNoteFixture {
  id: number;
  x: number;
  y: number;
  width: number;
  height: number;
  body: string;
  html?: string;
}

export interface NotesPageOptions {
  member?: boolean;
  imageContainer?: boolean;
  fileExt?: string;
  width?: number;
  height?: number;
  notes?: StagedNoteFixture[];
}

export const POST_ID = 123;

/** Note that sits at (200,200) with size 400x200 in image pixels: at the default 0.5 scale, (100,100) 200x100 on screen. */
export const SAMPLE_NOTE: StagedNoteFixture = { id: 7, x: 200, y: 200, width: 400, height: 200, body: "hello", html: "<p>hello</p>" };

function escapeAttr (value: string): string {
  return value.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
}

/**
 * Renders the parts of posts#show that the notes component touches:
 * the image container, note staging area, editing toggles, and the editor form.
 */
export function renderNotesPage ({
  member = true,
  imageContainer = true,
  fileExt = "png",
  width = 1600,
  height = 1200,
  notes = [],
}: NotesPageOptions = {}): void {
  const staged = notes.map((note) => `<article class="staged-note"
      data-width="${note.width}" data-height="${note.height}" data-x="${note.x}" data-y="${note.y}"
      data-id="${note.id}" data-body="${escapeAttr(note.body)}">${note.html ?? note.body}</article>`).join("");

  document.body.innerHTML = `
    ${imageContainer
      ? `<section id="image-container" data-id="${POST_ID}" data-file-ext="${fileExt}" data-width="${width}" data-height="${height}">
           <div id="note-container" enabled="false"></div>
         </section>`
      : ""}
    <a id="translate" href="#">Edit Notes</a>
    <section id="mark-as-translated-section" style="display: none;">
      <button type="button" id="translation-cancel">Close Editor</button>
    </section>
    <section id="note-staging" style="display: none;">${staged}</section>
    <form id="note-editor">
      <textarea id="note-editor-input"></textarea>
      <button type="submit">Submit</button>
      <button type="button" name="note-cancel">Cancel</button>
      <button type="button" name="note-delete">Delete</button>
      <button type="button" name="note-history">History</button>
    </form>`;

  // Must come after innerHTML, which replaces the body
  setSiteData("site-user", {
    id: member ? 1 : 0,
    name: member ? "member" : "Anonymous",
    level: member ? 20 : 0,
    is: { member, anonymous: !member },
  });
}

export interface Geometry {
  /** Simulates the container ResizeObserver firing */
  fireResize: () => void;
  /** Changes the reported container width for subsequent measurements */
  setContainerWidth: (width: number) => void;
}

/**
 * jsdom has no layout, so container measurements come back as 0.
 * Stub the jQuery measurement methods and the browser APIs the component needs.
 */
export function stubGeometry ({ width = 800, height = 600 } = {}): Geometry {
  let containerWidth = width;
  const observers: Array<() => void> = [];

  vi.stubGlobal("ResizeObserver", class {
    constructor (callback: () => void) { observers.push(callback); }
    observe () {}
    unobserve () {}
    disconnect () {}
  });

  // Synchronous animation frames keep the drag handlers deterministic
  vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) => {
    callback(0);
    return 1;
  });
  vi.stubGlobal("cancelAnimationFrame", () => {});

  vi.spyOn($.fn, "width").mockImplementation(() => containerWidth);
  vi.spyOn($.fn, "height").mockImplementation(() => height);

  if (!Element.prototype.scrollIntoView)
    Element.prototype.scrollIntoView = () => {};
  vi.spyOn(Element.prototype, "scrollIntoView").mockImplementation(() => {});

  return {
    fireResize: () => observers.forEach((callback) => callback()),
    setContainerWidth: (value) => { containerWidth = value; },
  };
}

/** Makes jQuery's `.position()` report the inline left/top, as a browser would for an absolutely positioned note. */
export function stubPositionFromStyle (): void {
  vi.spyOn($.fn, "position").mockImplementation(function (this: JQuery<HTMLElement>) {
    const style = this[0].style;
    return { left: parseFloat(style.left) || 0, top: parseFloat(style.top) || 0 };
  });
}

export interface MouseOptions {
  x?: number;
  y?: number;
  button?: number;
}

/** Triggers a jQuery mouse event with page coordinates on the given element */
export function mouse (target: Element | JQuery<HTMLElement>, type: string, { x = 0, y = 0, button = 0 }: MouseOptions = {}): void {
  $(target as HTMLElement).trigger($.Event(type, { pageX: x, pageY: y, button, which: button + 1 }));
}

export function pressEscape (): void {
  $(document).trigger($.Event("keydown", { key: "Escape" }));
}

export async function loadNoteManager () {
  vi.resetModules();
  const NoteManager = (await import("@/pages/posts/show/notes")).default;
  const Note = (await import("@/pages/posts/show/notes/Note")).default;
  const NoteUtilities = (await import("@/pages/posts/show/notes/NoteUtilities")).default;
  return { NoteManager, Note, NoteUtilities, manager: NoteManager.instance };
}
