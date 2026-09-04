import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

describe("uploads/uploader — lifecycle", () => {
  it("installs the unload guard on mount and releases it on unmount", async () => {
    const { wrapper } = await mountUploader();
    expect(typeof window.onbeforeunload).toBe("function");

    wrapper.unmount();
    expect(window.onbeforeunload).toBeNull();
  });
});
