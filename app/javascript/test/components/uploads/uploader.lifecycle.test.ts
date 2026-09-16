import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { nextTick } from "vue";
import { mountUploader, unmountAll } from "./mountUploader";

// The autocomplete mock is module-scoped, so its call history accumulates across
// mounts; clear it per-test so the negative tag-query assertion is order-independent.
beforeEach(() => vi.clearAllMocks());
afterEach(unmountAll);

const fireBeforeUnload = () => {
  const event = new Event("beforeunload", { cancelable: true });
  window.dispatchEvent(event);
  return event.defaultPrevented;
};

describe("uploads/uploader — lifecycle", () => {
  it("guards navigation only while dirty, and releases the listener on unmount", async () => {
    const removeSpy = vi.spyOn(window, "removeEventListener");
    const { wrapper } = await mountUploader();

    // Clean form → navigation allowed.
    expect(fireBeforeUnload()).toBe(false);

    // Dirty form → the browser prompt is triggered (preventDefault).
    (wrapper.vm as any).uploadValue = "https://example.com/a.png";
    await nextTick();
    expect(fireBeforeUnload()).toBe(true);

    wrapper.unmount();
    expect(removeSpy).toHaveBeenCalledWith("beforeunload", expect.any(Function));
  });

  it("initializes tag-query autocomplete for the Locked Tags field (admin)", async () => {
    await mountUploader({ admin: true });
    const Autocomplete = (await import("@/components/autocomplete")).default;
    expect(Autocomplete.initialize_autocomplete).toHaveBeenCalledWith("tag-edit");
    expect(Autocomplete.initialize_autocomplete).toHaveBeenCalledWith("tag-query");
  });

  it("does not initialize tag-query when the Locked Tags field is absent (non-admin)", async () => {
    await mountUploader();
    const Autocomplete = (await import("@/components/autocomplete")).default;
    expect(Autocomplete.initialize_autocomplete).toHaveBeenCalledWith("tag-edit");
    expect(Autocomplete.initialize_autocomplete).not.toHaveBeenCalledWith("tag-query");
  });
});
