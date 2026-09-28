import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import Favorite from "@/models/Favorite";

vi.mock("@/models/Favorite", () => ({ default: { move: vi.fn(() => Promise.resolve({})) } }));

// jsdom does not implement these (confirmed: both are `undefined` on Element.prototype /
// document under jsdom). They're only reached once a drag has actually activated past
// the movement threshold; the stuck-state regression tests below never cross it, so most
// tests don't need these at all. The few that do exercise activation get a harmless stub.
beforeAll(() => {
  if (!Element.prototype.setPointerCapture) {
    Element.prototype.setPointerCapture = vi.fn();
  }
  if (!document.elementFromPoint) {
    document.elementFromPoint = vi.fn(() => null);
  }
});

function buildContainer () {
  const container = document.createElement("section");
  container.className = "posts-container";
  document.body.appendChild(container);
  return container;
}

function buildSource (id = "123") {
  const source = document.createElement("article");
  source.className = "thumbnail";
  source.dataset.id = id;

  const link = document.createElement("a");
  link.className = "thm-link";
  link.setAttribute("href", `/posts/${id}`);

  const img = document.createElement("img");
  link.appendChild(img);

  const desc = document.createElement("div");
  desc.className = "thm-desc";

  source.appendChild(link);
  source.appendChild(desc);
  return { source, link, img, desc };
}

function buildDropTarget (folderId = "9") {
  const target = document.createElement("article");
  target.className = "favorite-folder-card";
  target.dataset.dropTarget = "folder";
  target.dataset.folderId = folderId;
  return target;
}

function firePointer (type: string, el: Element | Document, opts: Partial<PointerEventInit> = {}) {
  const event = new PointerEvent(type, {
    bubbles: true,
    cancelable: true,
    pointerId: 1,
    button: 0,
    clientX: 0,
    clientY: 0,
    ...opts,
  });
  el.dispatchEvent(event);
  return event;
}

// Simulates a RAF that resolved to `target` BEFORE release and is still the correct
// target AT release - i.e. document.elementFromPoint keeps returning `target` through
// the pointerup call too, matching how onPointerUp now re-resolves synchronously from
// the release coordinates rather than trusting a possibly-stale drag.currentTarget.
// Callers must call the returned restore() after firing pointerup.
function mockElementFromPoint (target: Element | null) {
  const spy = vi.spyOn(document, "elementFromPoint").mockReturnValue(target);
  return () => spy.mockRestore();
}

afterEach(() => {
  document.body.innerHTML = "";
  vi.mocked(Favorite.move).mockClear();
  vi.mocked(Favorite.move).mockImplementation(() => Promise.resolve({}));
});

describe("pages/favorites/FavoriteFolderDrag", () => {
  it("does not leave drag state stuck when the pointer is released over a different element before crossing the threshold", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    container.appendChild(source);
    const instance = new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    expect(instance.drag).not.toBeNull();

    // The pointer is released over document.body, not sourceEl - before pointer capture
    // is ever acquired (it's only acquired on activation), a real browser is free to
    // deliver this event to whatever's actually under the pointer. Listeners bound only
    // to sourceEl would never see this, leaving `drag` stuck forever.
    firePointer("pointerup", document.body, { clientX: 1, clientY: 1 });

    expect(instance.drag).toBeNull();

    // A fresh drag can start immediately after - proving onPointerDown's `if (this.drag)
    // return` guard isn't left permanently blocking future drags by the stuck state.
    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    expect(instance.drag).not.toBeNull();
  });

  it("does not leave drag state stuck on a pointercancel delivered to a different element", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    container.appendChild(source);
    const instance = new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointercancel", document.body);

    expect(instance.drag).toBeNull();
  });

  it("never crosses into drag mode when the pointer is released below the movement threshold, leaving the click untouched", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    container.appendChild(source);
    new FavoriteFolderDrag(container);

    const downEvent = firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 2, clientY: 2 }); // below the 6px threshold
    firePointer("pointerup", document.body, { clientX: 2, clientY: 2 });

    expect(downEvent.defaultPrevented).toBe(false);
    expect(source.classList.contains("favorite-dragging")).toBe(false);

    // The browser's real click for this pointer sequence must resolve normally: nothing
    // was ever added to the suppression set, so it isn't prevented.
    const click = new MouseEvent("click", { bubbles: true, cancelable: true });
    const notPrevented = source.dispatchEvent(click);
    expect(notPrevented).toBe(true);
  });

  it("activates once the movement threshold is crossed, even via a document-level pointermove", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    container.appendChild(source);
    const instance = new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // past ACTIVATION_THRESHOLD

    expect(instance.drag?.active).toBe(true);
    expect(source.classList.contains("favorite-dragging")).toBe(true);
  });

  it("suppresses the synthetic click that follows a completed drag", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source, link } = buildSource();
    container.appendChild(source);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates
    // Post-activation events are scoped to captureEl (sourceEl) - real pointer capture
    // would redirect them there regardless of where they're dispatched; jsdom has no
    // such redirection, so the test dispatches directly on captureEl to match.
    firePointer("pointerup", source, { clientX: 20, clientY: 0 });

    const click = new MouseEvent("click", { bubbles: true, cancelable: true });
    const notPrevented = link.dispatchEvent(click);
    expect(notPrevented).toBe(false); // false means preventDefault() was called
  });

  it("activates a drag started with pointerdown on the image, not just the footer", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source, img } = buildSource();
    container.appendChild(source);
    const instance = new FavoriteFolderDrag(container);

    firePointer("pointerdown", img, { clientX: 0, clientY: 0 });
    expect(instance.drag?.sourceEl).toBe(source);

    firePointer("pointermove", document, { clientX: 20, clientY: 0 });
    expect(instance.drag?.active).toBe(true);
  });

  it("prevents native dragstart on a real post thumbnail's image, but not on a folder card", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source, img } = buildSource();
    const dropTarget = buildDropTarget();
    container.append(source, dropTarget);
    new FavoriteFolderDrag(container);

    const onThumbnail = new Event("dragstart", { bubbles: true, cancelable: true });
    img.dispatchEvent(onThumbnail);
    expect(onThumbnail.defaultPrevented).toBe(true);

    // Native drag suppression is scoped to real post thumbnails only - folder/Go Up cards
    // are not part of this feature and must keep their normal browser drag behavior.
    const onFolder = new Event("dragstart", { bubbles: true, cancelable: true });
    dropTarget.dispatchEvent(onFolder);
    expect(onFolder.defaultPrevented).toBe(false);
  });

  it("keeps the source article in the DOM and in its original grid position throughout the gesture", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource("123");
    const { source: sibling } = buildSource("456");
    container.append(source, sibling);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates

    expect(container.contains(source)).toBe(true);
    expect(Array.from(container.children).indexOf(source)).toBe(0);
    expect(source.nextElementSibling).toBe(sibling);
  });

  it("never removes or reinserts the source when the drag is cancelled", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    container.appendChild(source);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 });
    firePointer("pointercancel", source);

    expect(container.contains(source)).toBe(true);
    expect(container.children.length).toBe(1);
    expect(source.classList.contains("favorite-dragging")).toBe(false);
  });

  it("never removes the source when the pointer is released over no valid drop target", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    container.appendChild(source);
    const instance = new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 });
    // document.elementFromPoint's default stub returns null -> no drop target resolved.
    instance.updateHoverTarget(20, 0);
    firePointer("pointerup", source, { clientX: 20, clientY: 0 });

    expect(container.contains(source)).toBe(true);
    expect(Favorite.move).not.toHaveBeenCalled();
  });

  it("leaves the source exactly where it was when the move request fails", async () => {
    vi.mocked(Favorite.move).mockImplementationOnce(() => Promise.reject(new Error("nope")));
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    const dropTarget = buildDropTarget("9");
    container.append(source, dropTarget);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 });
    const restoreElementFromPoint = mockElementFromPoint(dropTarget);
    firePointer("pointerup", source, { clientX: 20, clientY: 0 });
    restoreElementFromPoint();

    await Promise.resolve();
    await Promise.resolve();

    expect(container.contains(source)).toBe(true);
    expect(Array.from(container.children).indexOf(source)).toBe(0);
    expect(source.classList.contains("favorite-dragging")).toBe(false);
  });

  it("removes the source only after a successful root -> folder move (filing an unfiled favorite creates a membership, so it leaves the root/unfiled listing)", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    const dropTarget = buildDropTarget("9");
    container.append(source, dropTarget);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 });
    const restoreElementFromPoint = mockElementFromPoint(dropTarget);
    firePointer("pointerup", source, { clientX: 20, clientY: 0 });
    restoreElementFromPoint();

    // Still present immediately after release: removal never happens optimistically, only
    // once the request has actually resolved.
    expect(container.contains(source)).toBe(true);

    await Promise.resolve();
    await Promise.resolve();

    expect(container.contains(source)).toBe(false);
    expect(Favorite.move).toHaveBeenCalledWith(123, 9);
  });

  it("removes the source only after a successful folder -> folder/root move (it's no longer a member of the folder currently being viewed)", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    const dropTarget = buildDropTarget("9");
    container.append(source, dropTarget);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 });
    const restoreElementFromPoint = mockElementFromPoint(dropTarget);
    firePointer("pointerup", source, { clientX: 20, clientY: 0 });
    restoreElementFromPoint();

    expect(container.contains(source)).toBe(true);

    await Promise.resolve();
    await Promise.resolve();

    expect(container.contains(source)).toBe(false);
    expect(Favorite.move).toHaveBeenCalledWith(123, 9);
  });

  it("never starts a drag from a folder or Go Up card", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const dropTarget = buildDropTarget();
    container.appendChild(dropTarget);
    const instance = new FavoriteFolderDrag(container);

    firePointer("pointerdown", dropTarget, { clientX: 0, clientY: 0 });
    expect(instance.drag).toBeNull();
  });

  it("produces a ghost clone with no duplicated data-id, so it can never match article.thumbnail[data-id]", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    container.appendChild(source);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 });

    const ghost = document.querySelector(".favorite-drag-ghost");
    expect(ghost).not.toBeNull();
    expect(ghost?.hasAttribute("data-id")).toBe(false);
    expect(ghost?.classList.contains("favorite-dragging")).toBe(false);
    expect(ghost?.matches("article.thumbnail[data-id]")).toBe(false);
  });

  it("A: resolves the correct drop target on release even when the queued RAF has not run yet (entered the folder just before release)", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    const dropTarget = buildDropTarget("9");
    container.append(source, dropTarget);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates

    // Post-activation move "enters" the folder - this schedules a RAF via onPointerMove
    // (updateHoverTarget), but that RAF is deliberately never flushed here, so it has not
    // run by the time pointerup fires right after - exactly the race being regressed
    // against. Before the fix, drag.currentTarget would still be null at this point, and
    // release would silently no-op instead of moving the favorite.
    const restoreDuringMove = mockElementFromPoint(dropTarget);
    firePointer("pointermove", source, { clientX: 20, clientY: 0 });
    restoreDuringMove();

    // document.elementFromPoint must resolve to the folder again at the moment of
    // release, since onPointerUp now re-resolves synchronously from the pointerup
    // event's own coordinates instead of relying on the never-run queued RAF.
    const restoreAtRelease = mockElementFromPoint(dropTarget);
    firePointer("pointerup", source, { clientX: 20, clientY: 0 });
    restoreAtRelease();

    await Promise.resolve();
    await Promise.resolve();

    expect(Favorite.move).toHaveBeenCalledWith(123, 9);
    expect(container.contains(source)).toBe(false);
  });

  it("B: uses the CURRENT target at release, never a stale previous one, when the pointer moved to a different folder before the queued RAF ran", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    const folderA = buildDropTarget("9");
    const folderB = buildDropTarget("11");
    container.append(source, folderA, folderB);
    const instance = new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates

    // First hover: the pointer was over folder A and its RAF actually ran (simulated
    // directly, matching how the tests above already simulate "the RAF already ran") -
    // drag.currentTarget is now folder A.
    const restoreA = mockElementFromPoint(folderA);
    instance.updateHoverTarget(10, 0);
    restoreA();
    expect(instance.drag?.currentTarget).toBe(folderA);

    // The pointer then moves to folder B - this schedules a new RAF via onPointerMove,
    // but it is never flushed, so drag.currentTarget is still folder A going into
    // pointerup - the exact stale-target scenario being regressed against.
    const restoreDuringMove = mockElementFromPoint(folderB);
    firePointer("pointermove", source, { clientX: 30, clientY: 0 });
    restoreDuringMove();
    expect(instance.drag?.currentTarget).toBe(folderA); // unchanged - the queued RAF hasn't run

    // Release happens over folder B - onPointerUp must re-resolve synchronously here and
    // commit against B, never the stale A.
    const restoreAtRelease = mockElementFromPoint(folderB);
    firePointer("pointerup", source, { clientX: 30, clientY: 0 });
    restoreAtRelease();

    await Promise.resolve();
    await Promise.resolve();

    expect(Favorite.move).toHaveBeenCalledWith(123, 11);
    expect(Favorite.move).not.toHaveBeenCalledWith(123, 9);
  });
});
