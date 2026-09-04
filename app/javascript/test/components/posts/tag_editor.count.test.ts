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

  it("updates the count on keyup", async () => {
    const { wrapper, updateTagCount } = await mountTagEditor();
    updateTagCount.mockClear();
    await wrapper.find("textarea").trigger("keyup");
    expect(updateTagCount).toHaveBeenCalled();
  });

  // B1 pin: autocomplete's insert() and context-menu paste dispatch `input`
  // (which v-model consumes) but no keyup — and today the count does NOT
  // refresh. The fix (watching `tags` instead of @keyup) flips this pin.
  it("does not update the count on input events alone (B1 pin)", async () => {
    const { wrapper, updateTagCount } = await mountTagEditor();
    updateTagCount.mockClear();
    await wrapper.find("textarea").setValue("wolf canine feral");
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
