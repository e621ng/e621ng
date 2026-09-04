import { vi } from "vitest";

vi.mock("@/pages/posts/posts", () => ({ default: { update_tag_count: vi.fn() } }));
vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { flushPromises } from "@vue/test-utils";
import { mountTagEditor, unmountAll } from "./mountTagEditor";

afterEach(unmountAll);

describe("posts/tag_editor — tag count wiring", () => {
  it("does not update the count on mount (the bootstrap handshake owns that)", async () => {
    const { updateTagCount } = await mountTagEditor();
    expect(updateTagCount).not.toHaveBeenCalled();
  });

  // B1 fixed: the count follows the tag string itself (a watch), so every input
  // method — typing, mouse-driven autocomplete inserts, paste — updates it.
  it("updates the count on any value change (B1 fixed)", async () => {
    const { wrapper, updateTagCount } = await mountTagEditor();
    updateTagCount.mockClear();
    await wrapper.find("textarea").setValue("wolf canine feral");
    expect(updateTagCount).toHaveBeenCalled();
  });

  it("does not update the count on a keyup without a value change", async () => {
    const { wrapper, updateTagCount } = await mountTagEditor();
    updateTagCount.mockClear();
    await wrapper.find("textarea").trigger("keyup");
    expect(updateTagCount).not.toHaveBeenCalled();
  });

  it("updates the count after a related tag is toggled in", async () => {
    const { wrapper, updateTagCount } = await mountTagEditor();
    updateTagCount.mockClear();
    (wrapper.findComponent(".related-tags") as any).vm.$emit("tag-active", "feral", true);
    await flushPromises();
    expect(updateTagCount).toHaveBeenCalled();
  });
});
