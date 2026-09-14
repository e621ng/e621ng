import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { mountUploader, unmountAll } from "./mountUploader";

// The autocomplete mock is module-scoped, so its call history accumulates across
// mounts; clear it per-test so the negative tag-query assertion is order-independent.
beforeEach(() => vi.clearAllMocks());
afterEach(unmountAll);

describe("uploads/uploader — lifecycle", () => {
  it("installs the unload guard on mount and releases it on unmount", async () => {
    const { wrapper } = await mountUploader();
    expect(typeof window.onbeforeunload).toBe("function");

    wrapper.unmount();
    expect(window.onbeforeunload).toBeNull();
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
