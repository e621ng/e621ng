import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const proto = HTMLDialogElement.prototype;
const originalShowModal = proto.showModal;
const originalClose = proto.close;

function render () {
  document.body.innerHTML = `
    <dialog id="region-notice">
      <button type="button" id="region-notice-close">Close</button>
    </dialog>`;
}

function dialog (): HTMLDialogElement {
  return document.getElementById("region-notice") as HTMLDialogElement;
}

// Importing the module bootstraps it against the current document
async function load () {
  vi.resetModules();
  await import("@/core/RegionNotice");
}

describe("RegionNotice", () => {
  beforeEach(() => {
    // jsdom's dialog support is incomplete; emulate the parts used here
    proto.showModal = vi.fn(function (this: HTMLDialogElement) { this.setAttribute("open", ""); });
    proto.close = vi.fn(function (this: HTMLDialogElement) {
      this.removeAttribute("open");
      this.dispatchEvent(new Event("close"));
    });
    document.cookie = "hide_region_notice=; path=/; max-age=0";
  });

  afterEach(() => {
    proto.showModal = originalShowModal;
    proto.close = originalClose;
    document.body.innerHTML = "";
  });

  it("does nothing when the notice is not rendered", async () => {
    await load();
    expect(proto.showModal).not.toHaveBeenCalled();
  });

  it("opens the notice as a modal", async () => {
    render();
    await load();
    expect(proto.showModal).toHaveBeenCalledOnce();
    expect(dialog().hasAttribute("open")).toBe(true);
    expect(document.cookie).not.toContain("hide_region_notice");
  });

  it("falls back to the open attribute without showModal", async () => {
    proto.showModal = undefined;
    render();
    await load();
    expect(dialog().hasAttribute("open")).toBe(true);
  });

  it("closes and sets the cookie when the close button is clicked", async () => {
    render();
    await load();
    document.getElementById("region-notice-close").click();
    expect(dialog().hasAttribute("open")).toBe(false);
    expect(document.cookie).toContain("hide_region_notice=1");
  });

  it("sets the cookie when closed any other way (e.g. Esc)", async () => {
    render();
    await load();
    dialog().dispatchEvent(new Event("close"));
    expect(document.cookie).toContain("hide_region_notice=1");
  });
});
