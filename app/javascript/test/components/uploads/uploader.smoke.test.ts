import { vi } from "vitest";

// vi.mock is file-scoped + hoisted — every uploader test file needs this header.
vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

describe("uploads/uploader — mount smoke", () => {
  it("mounts the full tree without throwing", async () => {
    const { wrapper } = await mountUploader();
    expect(wrapper.find(".flex-grid-outer").exists()).toBe(true);
    expect(wrapper.find("button[accesskey='s']").text()).toBe("Upload");
  });

  it("runs mounted(): wires autocomplete and constructs the DText editor", async () => {
    await mountUploader();
    // Resolve the mocked modules the component actually used (post-reset instance).
    const Autocomplete = (await import("@/components/autocomplete")).default;
    const DTextFormatter = (await import("@/components/DTextFormatter.ts")).default;
    expect(Autocomplete.initialize_autocomplete).toHaveBeenCalledWith("tag-edit");
    expect(DTextFormatter).toHaveBeenCalled();
  });

  it("renders normal mode by default and compact mode when requested", async () => {
    const normal = (await mountUploader()).wrapper;
    // Artists/Characters sections only exist in normal mode.
    expect(normal.find("#post_artist").exists()).toBe(true);

    const compact = (await mountUploader({ compactMode: true })).wrapper;
    expect(compact.find("#post_artist").exists()).toBe(false);
  });

  it("seeds the rating buttons per safe mode", async () => {
    const normal = (await mountUploader()).wrapper;
    expect(normal.find(".rating-e").exists()).toBe(true);

    const safe = (await mountUploader({ safeSite: true })).wrapper;
    expect(safe.find(".rating-e").exists()).toBe(false);
    expect(safe.find(".rating-s").exists()).toBe(true);
  });
});
