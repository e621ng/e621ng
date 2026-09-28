import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import Favorite from "@/models/Favorite";
import FavoriteFolder from "@/models/FavoriteFolder";

vi.mock("@/models/Favorite", () => ({ default: { move: vi.fn(() => Promise.resolve({})) } }));
vi.mock("@/models/FavoriteFolder", () => ({ default: { move: vi.fn(() => Promise.resolve({})) } }));

// jsdom doesn't implement these; only activated drags need them.
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

// A full folder card: both a drop target and a drag source, with footer controls
// (rename/delete) that must never themselves start a drag.
function buildFolderCard (id = "9", name = "Folder") {
  const card = document.createElement("article");
  card.className = "thumbnail favorite-folder-card";
  card.dataset.dropTarget = "folder";
  card.dataset.folderDragSource = "true";
  card.dataset.folderId = id;
  card.dataset.folderName = name;

  const link = document.createElement("a");
  link.className = "thm-link favorite-folder-card-link";
  link.setAttribute("href", `/favorites?folder_id=${id}`);
  // Both icons present, like the real component - CSS toggles visibility.
  const closedIcon = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  closedIcon.setAttribute("class", "folder-icon-closed");
  const openIcon = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  openIcon.setAttribute("class", "folder-icon-open");
  link.append(closedIcon, openIcon);

  const desc = document.createElement("div");
  desc.className = "thm-desc favorite-folder-card-desc";

  const renameBtn = document.createElement("button");
  renameBtn.type = "button";
  renameBtn.className = "favorite-folder-rename-trigger";

  const nameSpan = document.createElement("span");
  nameSpan.className = "thm-desc-a favorite-folder-card-name";

  const deleteForm = document.createElement("form");
  deleteForm.className = "favorite-folder-delete-cell";
  const deleteBtn = document.createElement("button");
  deleteBtn.type = "submit";
  deleteBtn.className = "favorite-folder-delete-trigger";
  deleteForm.appendChild(deleteBtn);

  desc.append(renameBtn, nameSpan, deleteForm);
  card.append(link, desc);
  return { card, link, closedIcon, openIcon, desc, renameBtn, deleteBtn, deleteForm };
}

// Go Up: a drop target only, for both post AND folder drags - never a drag source itself
// (no data-id, no data-folder-drag-source).
function buildGoUp (destinationFolderId = "") {
  const goUp = document.createElement("article");
  goUp.className = "thumbnail favorite-go-up-card";
  goUp.dataset.dropTarget = "go-up";
  goUp.dataset.destinationFolderId = destinationFolderId;
  return goUp;
}

// New Folder: neither a drag source nor a drop target - carries none of data-id,
// data-folder-drag-source, or data-drop-target.
function buildNewFolderCard () {
  const card = document.createElement("article");
  card.className = "thumbnail favorite-new-folder-card";
  const button = document.createElement("button");
  button.type = "button";
  button.id = "favorite-folder-new-trigger";
  card.appendChild(button);
  return { card, button };
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

// Stubs document.elementFromPoint for the duration of a hover/release check. Callers
// must call the returned restore() after firing pointerup.
function mockElementFromPoint (target: Element | null) {
  const spy = vi.spyOn(document, "elementFromPoint").mockReturnValue(target);
  return () => spy.mockRestore();
}

afterEach(() => {
  document.body.innerHTML = "";
  vi.mocked(Favorite.move).mockClear();
  vi.mocked(Favorite.move).mockImplementation(() => Promise.resolve({}));
  vi.mocked(FavoriteFolder.move).mockClear();
  vi.mocked(FavoriteFolder.move).mockImplementation(() => Promise.resolve({ id: 9, name: "Folder", parent_id: null }));
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

    // Released over document.body, not sourceEl - no pointer capture yet below threshold.
    firePointer("pointerup", document.body, { clientX: 1, clientY: 1 });

    expect(instance.drag).toBeNull();
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

    const click = new MouseEvent("click", { bubbles: true, cancelable: true });
    expect(source.dispatchEvent(click)).toBe(true);
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
    // jsdom has no pointer-capture redirection, so dispatch directly on captureEl.
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

    expect(container.contains(source)).toBe(true); // not optimistic

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

  it("resolves the correct drop target on release even when the queued RAF has not run yet", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    const dropTarget = buildDropTarget("9");
    container.append(source, dropTarget);
    new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates

    // Entering the folder schedules a RAF that's deliberately never flushed here.
    const restoreDuringMove = mockElementFromPoint(dropTarget);
    firePointer("pointermove", source, { clientX: 20, clientY: 0 });
    restoreDuringMove();

    const restoreAtRelease = mockElementFromPoint(dropTarget);
    firePointer("pointerup", source, { clientX: 20, clientY: 0 });
    restoreAtRelease();

    await Promise.resolve();
    await Promise.resolve();

    expect(Favorite.move).toHaveBeenCalledWith(123, 9);
    expect(container.contains(source)).toBe(false);
  });

  it("uses the current target at release, never a stale previous one, when the pointer moved to a different folder before the queued RAF ran", async () => {
    const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
    const container = buildContainer();
    const { source } = buildSource();
    const folderA = buildDropTarget("9");
    const folderB = buildDropTarget("11");
    container.append(source, folderA, folderB);
    const instance = new FavoriteFolderDrag(container);

    firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
    firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates

    const restoreA = mockElementFromPoint(folderA);
    instance.updateHoverTarget(10, 0);
    restoreA();
    expect(instance.drag?.currentTarget).toBe(folderA);

    // Pointer moves to folder B, scheduling a new RAF that's never flushed.
    const restoreDuringMove = mockElementFromPoint(folderB);
    firePointer("pointermove", source, { clientX: 30, clientY: 0 });
    restoreDuringMove();
    expect(instance.drag?.currentTarget).toBe(folderA);

    const restoreAtRelease = mockElementFromPoint(folderB);
    firePointer("pointerup", source, { clientX: 30, clientY: 0 });
    restoreAtRelease();

    await Promise.resolve();
    await Promise.resolve();

    expect(Favorite.move).toHaveBeenCalledWith(123, 11);
    expect(Favorite.move).not.toHaveBeenCalledWith(123, 9);
  });

  describe("folder hierarchy dragging", () => {
    it("activates a folder drag once the movement threshold is crossed from the card's main body/link", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card, link } = buildFolderCard("9");
      container.appendChild(card);
      const instance = new FavoriteFolderDrag(container);

      firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
      expect(instance.drag?.kind).toBe("folder");
      firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // past ACTIVATION_THRESHOLD

      expect(instance.drag?.active).toBe(true);
      expect(card.classList.contains("favorite-dragging")).toBe(true);
    });

    it("an ordinary click below the threshold never activates a folder drag, leaving navigation untouched", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card, link } = buildFolderCard("9");
      container.appendChild(card);
      new FavoriteFolderDrag(container);

      const downEvent = firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 2, clientY: 2 }); // below the 6px threshold
      firePointer("pointerup", document.body, { clientX: 2, clientY: 2 });

      expect(downEvent.defaultPrevented).toBe(false);
      const click = new MouseEvent("click", { bubbles: true, cancelable: true });
      expect(link.dispatchEvent(click)).toBe(true);
    });

    it("pointerdown on the rename control never starts a folder drag", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card, renameBtn } = buildFolderCard("9");
      container.appendChild(card);
      const instance = new FavoriteFolderDrag(container);

      firePointer("pointerdown", renameBtn, { clientX: 0, clientY: 0 });
      expect(instance.drag).toBeNull();
    });

    it("pointerdown on the delete control/form never starts a folder drag", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card, deleteBtn } = buildFolderCard("9");
      container.appendChild(card);
      const instance = new FavoriteFolderDrag(container);

      firePointer("pointerdown", deleteBtn, { clientX: 0, clientY: 0 });
      expect(instance.drag).toBeNull();
    });

    it("dragging folder A onto folder B calls FavoriteFolder.move(A, B)", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card: cardA, link: linkA } = buildFolderCard("1");
      const { card: cardB } = buildFolderCard("2");
      container.append(cardA, cardB);
      new FavoriteFolderDrag(container);

      firePointer("pointerdown", linkA, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates
      const restore = mockElementFromPoint(cardB);
      firePointer("pointerup", cardA, { clientX: 20, clientY: 0 });
      restore();

      await Promise.resolve();
      await Promise.resolve();

      expect(FavoriteFolder.move).toHaveBeenCalledWith(1, 2);
      expect(Favorite.move).not.toHaveBeenCalled();
      expect(container.contains(cardA)).toBe(false);
    });

    it("dragging a folder onto Go Up calls FavoriteFolder.move(folder, goUpDestination)", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card, link } = buildFolderCard("5");
      const goUp = buildGoUp("42");
      container.append(card, goUp);
      new FavoriteFolderDrag(container);

      firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 });
      const restore = mockElementFromPoint(goUp);
      firePointer("pointerup", card, { clientX: 20, clientY: 0 });
      restore();

      await Promise.resolve();
      await Promise.resolve();

      expect(FavoriteFolder.move).toHaveBeenCalledWith(5, 42);
    });

    it("dragging a folder onto a top-level Go Up (no destination id) calls FavoriteFolder.move(folder, null)", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card, link } = buildFolderCard("5");
      const goUp = buildGoUp(""); // root: empty data-destination-folder-id
      container.append(card, goUp);
      new FavoriteFolderDrag(container);

      firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 });
      const restore = mockElementFromPoint(goUp);
      firePointer("pointerup", card, { clientX: 20, clientY: 0 });
      restore();

      await Promise.resolve();
      await Promise.resolve();

      expect(FavoriteFolder.move).toHaveBeenCalledWith(5, null);
    });

    it("dropping a folder onto its own card sends no request - never resolves as a valid target", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card, link } = buildFolderCard("9");
      container.appendChild(card);
      const instance = new FavoriteFolderDrag(container);

      firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 });
      const restore = mockElementFromPoint(card); // hovering back over its own card
      instance.updateHoverTarget(20, 0);
      expect(instance.drag?.currentTarget).toBeNull();
      firePointer("pointerup", card, { clientX: 20, clientY: 0 });
      restore();

      await Promise.resolve();
      await Promise.resolve();

      expect(FavoriteFolder.move).not.toHaveBeenCalled();
      expect(container.contains(card)).toBe(true);
    });

    it("a failed folder move leaves the source card in the DOM, with drag state already reset", async () => {
      vi.mocked(FavoriteFolder.move).mockImplementationOnce(() => Promise.reject(new Error("nope")));
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card: cardA, link: linkA } = buildFolderCard("1");
      const { card: cardB } = buildFolderCard("2");
      container.append(cardA, cardB);
      const instance = new FavoriteFolderDrag(container);

      firePointer("pointerdown", linkA, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 });
      const restore = mockElementFromPoint(cardB);
      firePointer("pointerup", cardA, { clientX: 20, clientY: 0 });
      restore();

      expect(instance.drag).toBeNull(); // resets synchronously, not after the promise

      await Promise.resolve();
      await Promise.resolve();

      expect(container.contains(cardA)).toBe(true);
      expect(cardA.classList.contains("favorite-dragging")).toBe(false);
    });

    it("a successful folder move removes the source card only after the promise resolves", async () => {
      let resolveMove: (value: { id: number; name: string; parent_id: number | null }) => void = () => {};
      vi.mocked(FavoriteFolder.move).mockImplementationOnce(() => new Promise((resolve) => { resolveMove = resolve; }));
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card: cardA, link: linkA } = buildFolderCard("1");
      const { card: cardB } = buildFolderCard("2");
      container.append(cardA, cardB);
      new FavoriteFolderDrag(container);

      firePointer("pointerdown", linkA, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 });
      const restore = mockElementFromPoint(cardB);
      firePointer("pointerup", cardA, { clientX: 20, clientY: 0 });
      restore();

      expect(container.contains(cardA)).toBe(true);

      resolveMove({ id: 1, name: "Folder", parent_id: 2 });
      await Promise.resolve();
      await Promise.resolve();

      expect(container.contains(cardA)).toBe(false);
    });

    it("the New Folder card is never a drag source or a drop target", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card, button } = buildNewFolderCard();
      container.appendChild(card);
      const instance = new FavoriteFolderDrag(container);

      firePointer("pointerdown", button, { clientX: 0, clientY: 0 });
      expect(instance.drag).toBeNull();

      // Also never resolves as a drop target for another drag in progress.
      const { card: folderCard, link } = buildFolderCard("9");
      container.appendChild(folderCard);
      firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 });
      const restore = mockElementFromPoint(card);
      instance.updateHoverTarget(20, 0);
      restore();
      expect(instance.drag?.currentTarget).toBeNull();
    });

    it("post drag onto a folder card still calls Favorite.move, not FavoriteFolder.move", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { source } = buildSource("123");
      const { card: folderCard } = buildFolderCard("9");
      container.append(source, folderCard);
      new FavoriteFolderDrag(container);

      firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 });
      const restore = mockElementFromPoint(folderCard);
      firePointer("pointerup", source, { clientX: 20, clientY: 0 });
      restore();

      await Promise.resolve();
      await Promise.resolve();

      expect(Favorite.move).toHaveBeenCalledWith(123, 9);
      expect(FavoriteFolder.move).not.toHaveBeenCalled();
    });

    it("post drag onto Go Up still calls Favorite.move", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { source } = buildSource("123");
      const goUp = buildGoUp("42");
      container.append(source, goUp);
      new FavoriteFolderDrag(container);

      firePointer("pointerdown", source, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 });
      const restore = mockElementFromPoint(goUp);
      firePointer("pointerup", source, { clientX: 20, clientY: 0 });
      restore();

      await Promise.resolve();
      await Promise.resolve();

      expect(Favorite.move).toHaveBeenCalledWith(123, 42);
      expect(FavoriteFolder.move).not.toHaveBeenCalled();
    });

    it("the final-pointer-position RAF regression fix also covers folder dragging (shared code path)", async () => {
      const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
      const container = buildContainer();
      const { card: cardA, link: linkA } = buildFolderCard("1");
      const { card: cardB } = buildFolderCard("2");
      container.append(cardA, cardB);
      new FavoriteFolderDrag(container);

      firePointer("pointerdown", linkA, { clientX: 0, clientY: 0 });
      firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates

      const restoreDuringMove = mockElementFromPoint(cardB);
      firePointer("pointermove", cardA, { clientX: 20, clientY: 0 });
      restoreDuringMove();

      const restoreAtRelease = mockElementFromPoint(cardB);
      firePointer("pointerup", cardA, { clientX: 20, clientY: 0 });
      restoreAtRelease();

      await Promise.resolve();
      await Promise.resolve();

      expect(FavoriteFolder.move).toHaveBeenCalledWith(1, 2);
    });

    describe("folder drag ghost", () => {
      it("uses a purpose-built ghost (favorite-folder-drag-ghost), not a clone of the full interactive card", async () => {
        const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
        const container = buildContainer();
        const { card, link } = buildFolderCard("9", "My Folder");
        container.appendChild(card);
        new FavoriteFolderDrag(container);

        firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
        firePointer("pointermove", document, { clientX: 20, clientY: 0 }); // activates

        const ghost = document.querySelector(".favorite-folder-drag-ghost");
        expect(ghost).not.toBeNull();
        expect(ghost?.classList.contains("favorite-drag-ghost")).toBe(true);
      });

      it("contains the folder name", async () => {
        const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
        const container = buildContainer();
        const { card, link } = buildFolderCard("9", "My Folder");
        container.appendChild(card);
        new FavoriteFolderDrag(container);

        firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
        firePointer("pointermove", document, { clientX: 20, clientY: 0 });

        const ghost = document.querySelector(".favorite-folder-drag-ghost");
        expect(ghost?.textContent).toContain("My Folder");
      });

      it("contains exactly one folder icon representation, not both the closed and open icons", async () => {
        const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
        const container = buildContainer();
        const { card, link } = buildFolderCard("9");
        container.appendChild(card);
        new FavoriteFolderDrag(container);

        firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
        firePointer("pointermove", document, { clientX: 20, clientY: 0 });

        const ghost = document.querySelector(".favorite-folder-drag-ghost");
        expect(ghost?.querySelectorAll("svg").length).toBe(1);
        expect(ghost?.querySelector(".folder-icon-open")).toBeNull();
        // The cloned icon also has its folder-icon-closed class stripped (that toggle
        // rule doesn't apply outside #c-favorites and isn't wanted on the ghost).
        expect(ghost?.querySelector(".folder-icon-closed")).toBeNull();
      });

      it("contains no rename control, delete form/control, data-id, drag-source marker, or drop-target marker", async () => {
        const { default: FavoriteFolderDrag } = await import("@/pages/favorites/FavoriteFolderDrag");
        const container = buildContainer();
        const { card, link } = buildFolderCard("9");
        container.appendChild(card);
        new FavoriteFolderDrag(container);

        firePointer("pointerdown", link, { clientX: 0, clientY: 0 });
        firePointer("pointermove", document, { clientX: 20, clientY: 0 });

        const ghost = document.querySelector(".favorite-folder-drag-ghost");
        expect(ghost?.querySelector(".favorite-folder-rename-trigger")).toBeNull();
        expect(ghost?.querySelector("form, .favorite-folder-delete-trigger")).toBeNull();
        expect(ghost?.querySelector("button")).toBeNull();
        expect(ghost?.querySelector("a")).toBeNull();
        expect(ghost?.hasAttribute("data-id")).toBe(false);
        expect(ghost?.querySelector("[data-id]")).toBeNull();
        expect(ghost?.hasAttribute("data-folder-drag-source")).toBe(false);
        expect(ghost?.hasAttribute("data-drop-target")).toBe(false);
        expect(ghost?.querySelector("[data-folder-drag-source], [data-drop-target]")).toBeNull();
      });
    });
  });
});
