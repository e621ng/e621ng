import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import FavoriteFolder from "@/models/FavoriteFolder";

vi.mock("@/models/FavoriteFolder", () => ({
  default: {
    create: vi.fn(() => Promise.resolve({ id: 1, name: "New Folder", parent_id: null })),
    rename: vi.fn(() => Promise.resolve({ id: 1, name: "Renamed", parent_id: null })),
  },
}));

function buildNewFolderTrigger (parentId = "") {
  const trigger = document.createElement("button");
  trigger.id = "favorite-folder-new-trigger";
  trigger.dataset.parentId = parentId;
  document.body.appendChild(trigger);
  return trigger;
}

function buildRenameTrigger (folderId = "9", folderName = "Existing") {
  const trigger = document.createElement("button");
  trigger.className = "favorite-folder-rename-trigger";
  trigger.dataset.folderId = folderId;
  trigger.dataset.folderName = folderName;
  document.body.appendChild(trigger);
  return trigger;
}

async function loadModule () {
  await import("@/pages/favorites/FavoriteFolderOverlay");
  // The module's bottom-of-file $(() => {...}) bootstrap runs on jQuery's DOM-ready
  // callback, which fires asynchronously even when the document is already loaded.
  await Promise.resolve();
  await new Promise((resolve) => setTimeout(resolve, 0));
}

function overlayEl (): HTMLElement {
  return document.querySelector(".st-overlay") as HTMLElement;
}

function fireClick (el: Element) {
  el.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
}

let reloadSpy: ReturnType<typeof vi.fn>;

beforeEach(() => {
  // jsdom's real location.reload isn't configurable enough for vi.spyOn/defineProperty -
  // stub the whole global instead (cleaned up automatically by setup.ts's
  // vi.unstubAllGlobals() in its own afterEach).
  reloadSpy = vi.fn();
  vi.stubGlobal("location", { ...window.location, reload: reloadSpy });
});

afterEach(() => {
  vi.mocked(FavoriteFolder.create).mockClear();
  vi.mocked(FavoriteFolder.rename).mockClear();
});

describe("pages/favorites/FavoriteFolderOverlay", () => {
  it("does nothing on a page with no New Folder trigger", async () => {
    await loadModule();
    expect(overlayEl()).toBeNull();
  });

  it("opens the overlay with a New Folder heading and an empty name field when the trigger is clicked", async () => {
    const trigger = buildNewFolderTrigger();
    await loadModule();

    fireClick(trigger);

    const overlay = overlayEl();
    expect(overlay).not.toBeNull();
    expect(overlay.classList.contains("hidden")).toBe(false);
    expect(overlay.querySelector("h1")?.textContent).toBe("New Folder");
    expect((overlay.querySelector("input") as HTMLInputElement).value).toBe("");
  });

  it("submits the trigger's data-parent-id as the parent for a create", async () => {
    const trigger = buildNewFolderTrigger("42");
    await loadModule();

    fireClick(trigger);
    const overlay = overlayEl();
    (overlay.querySelector("input") as HTMLInputElement).value = "Sub Folder";
    overlay.querySelector("form")?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));

    expect(FavoriteFolder.create).toHaveBeenCalledWith("Sub Folder", "42");
  });

  it("submits null parent_id for a root-level create", async () => {
    const trigger = buildNewFolderTrigger("");
    await loadModule();

    fireClick(trigger);
    const overlay = overlayEl();
    (overlay.querySelector("input") as HTMLInputElement).value = "Root Folder";
    overlay.querySelector("form")?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));

    expect(FavoriteFolder.create).toHaveBeenCalledWith("Root Folder", null);
  });

  it("opens the same overlay with a Rename Folder heading and the existing name pre-filled", async () => {
    buildNewFolderTrigger();
    const renameTrigger = buildRenameTrigger("9", "Existing Name");
    await loadModule();

    fireClick(renameTrigger);

    const overlay = overlayEl();
    expect(overlay.classList.contains("hidden")).toBe(false);
    expect(overlay.querySelector("h1")?.textContent).toBe("Rename Folder");
    expect((overlay.querySelector("input") as HTMLInputElement).value).toBe("Existing Name");
  });

  it("submits a PATCH-equivalent rename against the trigger's folder id", async () => {
    buildNewFolderTrigger();
    const renameTrigger = buildRenameTrigger("9", "Existing Name");
    await loadModule();

    fireClick(renameTrigger);
    const overlay = overlayEl();
    (overlay.querySelector("input") as HTMLInputElement).value = "New Name";
    overlay.querySelector("form")?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));

    expect(FavoriteFolder.rename).toHaveBeenCalledWith("9", "New Name");
    expect(FavoriteFolder.create).not.toHaveBeenCalled();
  });

  it("closes on Escape", async () => {
    const trigger = buildNewFolderTrigger();
    await loadModule();
    fireClick(trigger);
    const overlay = overlayEl();
    expect(overlay.classList.contains("hidden")).toBe(false);

    overlay.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    expect(overlay.classList.contains("hidden")).toBe(true);
  });

  it("closes when the bare backdrop is clicked", async () => {
    const trigger = buildNewFolderTrigger();
    await loadModule();
    fireClick(trigger);
    const overlay = overlayEl();

    // Dispatched directly on the backdrop, not a descendant.
    overlay.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(overlay.classList.contains("hidden")).toBe(true);
  });

  it("does not close when a click lands inside the wrapper", async () => {
    const trigger = buildNewFolderTrigger();
    await loadModule();
    fireClick(trigger);
    const overlay = overlayEl();
    const wrapper = overlay.querySelector(".favorite-folder-overlay-wrapper") as HTMLElement;

    wrapper.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(overlay.classList.contains("hidden")).toBe(false);
  });

  it("puts the heading inside form.simple_form, matching the login modal's h1-inside-the-card hierarchy", async () => {
    const trigger = buildNewFolderTrigger();
    await loadModule();
    fireClick(trigger);
    const overlay = overlayEl();

    const heading = overlay.querySelector("h1");
    expect(heading?.closest("form.simple_form")).not.toBeNull();
    expect(heading?.parentElement).toBe(overlay.querySelector("form.simple_form"));
  });

  it("keeps the overlay open and shows the backend error inline when the request fails", async () => {
    vi.mocked(FavoriteFolder.create).mockImplementationOnce(() => Promise.reject(new Error("A folder with that name already exists here")));
    const trigger = buildNewFolderTrigger();
    await loadModule();

    fireClick(trigger);
    const overlay = overlayEl();
    (overlay.querySelector("input") as HTMLInputElement).value = "Duplicate";
    overlay.querySelector("form")?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));

    await Promise.resolve();
    await Promise.resolve();

    expect(overlay.classList.contains("hidden")).toBe(false);
    expect(overlay.querySelector(".st-overlay-error")?.textContent).toBe("A folder with that name already exists here");
    expect(reloadSpy).not.toHaveBeenCalled();
  });

  it("reloads the page on a successful save", async () => {
    const trigger = buildNewFolderTrigger();
    await loadModule();

    fireClick(trigger);
    const overlay = overlayEl();
    (overlay.querySelector("input") as HTMLInputElement).value = "Good Folder";
    overlay.querySelector("form")?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));

    await Promise.resolve();
    await Promise.resolve();

    expect(reloadSpy).toHaveBeenCalled();
  });

  it("clears a stale error when the overlay is reopened", async () => {
    vi.mocked(FavoriteFolder.create).mockImplementationOnce(() => Promise.reject(new Error("Duplicate name")));
    const trigger = buildNewFolderTrigger();
    await loadModule();

    fireClick(trigger);
    let overlay = overlayEl();
    (overlay.querySelector("input") as HTMLInputElement).value = "Duplicate";
    overlay.querySelector("form")?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    await Promise.resolve();
    await Promise.resolve();
    expect(overlay.querySelector(".st-overlay-error")?.textContent).not.toBe("");

    overlay.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    fireClick(trigger);
    overlay = overlayEl();
    expect(overlay.querySelector(".st-overlay-error")?.textContent).toBe("");
  });

  it("does not submit a second request while the first one is still pending", async () => {
    let resolveCreate: (value: { id: number; name: string; parent_id: null }) => void = () => {};
    vi.mocked(FavoriteFolder.create).mockImplementationOnce(() => new Promise((resolve) => { resolveCreate = resolve; }));
    const trigger = buildNewFolderTrigger();
    await loadModule();

    fireClick(trigger);
    const overlay = overlayEl();
    (overlay.querySelector("input") as HTMLInputElement).value = "Slow Folder";
    const form = overlay.querySelector("form") as HTMLFormElement;
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));

    expect(FavoriteFolder.create).toHaveBeenCalledTimes(1);
    resolveCreate({ id: 1, name: "Slow Folder", parent_id: null });
  });

  describe("while a request is pending", () => {
    async function openWithPendingSubmit () {
      let rejectCreate: (error: Error) => void = () => {};
      vi.mocked(FavoriteFolder.create).mockImplementationOnce(() => new Promise((_resolve, reject) => { rejectCreate = reject; }));
      const trigger = buildNewFolderTrigger();
      await loadModule();

      fireClick(trigger);
      const overlay = overlayEl();
      (overlay.querySelector("input") as HTMLInputElement).value = "Slow Folder";
      overlay.querySelector("form")?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
      return { overlay, rejectCreate };
    }

    it("ignores Escape", async () => {
      const { overlay } = await openWithPendingSubmit();
      overlay.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
      expect(overlay.classList.contains("hidden")).toBe(false);
    });

    it("ignores a backdrop click", async () => {
      const { overlay } = await openWithPendingSubmit();
      overlay.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
      expect(overlay.classList.contains("hidden")).toBe(false);
    });

    it("ignores the close button", async () => {
      const { overlay } = await openWithPendingSubmit();
      const closeButton = overlay.querySelector("button.close-button") as HTMLButtonElement;
      expect(closeButton.disabled).toBe(true);
      fireClick(closeButton);
      expect(overlay.classList.contains("hidden")).toBe(false);
    });

    it("does not open a second operation on the same overlay", async () => {
      const { overlay } = await openWithPendingSubmit();
      const renameTrigger = buildRenameTrigger("9", "Existing");
      fireClick(renameTrigger);
      expect(overlay.querySelector("h1")?.textContent).not.toBe("Rename Folder");
    });

    it("restores close behavior once the request fails, keeping the modal open with an inline error", async () => {
      const { overlay, rejectCreate } = await openWithPendingSubmit();
      rejectCreate(new Error("A folder with that name already exists here"));
      await Promise.resolve();
      await Promise.resolve();

      expect(overlay.classList.contains("hidden")).toBe(false);
      expect(overlay.querySelector(".st-overlay-error")?.textContent).toBe("A folder with that name already exists here");

      const closeButton = overlay.querySelector("button.close-button") as HTMLButtonElement;
      expect(closeButton.disabled).toBe(false);
      overlay.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
      expect(overlay.classList.contains("hidden")).toBe(true);
    });
  });
});
