import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { nextTick } from "vue";
import { VueWrapper } from "@vue/test-utils";
import { mountTagEditor, unmountAll } from "./mountTagEditor";

afterEach(unmountAll);

const textareaValue = (w: VueWrapper) => (w.find("textarea").element as HTMLTextAreaElement).value;
const relatedItem = (w: VueWrapper, name: string) => w.findAll(".related-item a").find((a) => a.text() === name);

// Toggle a tag through the related-tags component boundary (what a related-item
// click emits: `tag-active` with the name and the desired state).
async function toggleTag (wrapper: VueWrapper, tag: string, add: boolean) {
  (wrapper.findComponent(".related-tags") as any).vm.$emit("tag-active", tag, add);
  await nextTick();
}

describe("posts/tag_editor — pushTag", () => {
  it("adds a clicked related tag to the textarea (full click round-trip)", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor({ postTags: "wolf " });
    await wrapper.find(".related-tag-functions a").trigger("click"); // "Tags"
    await fetchCalls[0].resolve({ related: [{ name: "feral", category_id: 0 }] });

    await relatedItem(wrapper, "feral")!.trigger("click");
    expect(textareaValue(wrapper)).toBe("wolf feral ");
  });

  it("appends with a trailing space, preserving the existing casing and grouping", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "Wolf canine\nforest tree " });
    await toggleTag(wrapper, "feral", true);
    expect(textareaValue(wrapper)).toBe("Wolf canine\nforest tree feral ");
  });

  it("inserts a separating space when the value does not end with one", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "wolf" });
    await toggleTag(wrapper, "feral", true);
    expect(textareaValue(wrapper)).toBe("wolf feral ");
  });

  it("deduplicates case-insensitively on add", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "Wolf " });
    await toggleTag(wrapper, "wolf", true);
    expect(textareaValue(wrapper)).toBe("Wolf ");
  });

  // B2 fixed: a removal only rewrites the line that held the tag; casing and
  // untouched lines are preserved verbatim, with a single trailing space.
  it("preserves casing and untouched lines on remove (B2 fixed)", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "Wolf   Canine\nForest Tree " });
    await toggleTag(wrapper, "canine", false);
    expect(textareaValue(wrapper)).toBe("Wolf\nForest Tree ");
  });

  it("removes the tag from its own line, leaving other groups' content alone", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "wolf canine\nforest tree " });
    await toggleTag(wrapper, "tree", false);
    expect(textareaValue(wrapper)).toBe("wolf canine\nforest ");
  });

  it("removes a mid-edit uppercase variant case-insensitively", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "Wolf feral " });
    await toggleTag(wrapper, "wolf", false);
    expect(textareaValue(wrapper)).toBe("feral ");
  });

  it("reflects toggles back into the related item's active state", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor({ postTags: "wolf canine " });
    await wrapper.find(".related-tag-functions a").trigger("click");
    await fetchCalls[0].resolve({ related: [{ name: "canine", category_id: 0 }] });

    const item = relatedItem(wrapper, "canine")!;
    expect(item.classes()).toContain("tag-active");

    await item.trigger("click"); // active → emits remove
    expect(textareaValue(wrapper)).not.toContain("canine");
    expect(item.classes()).not.toContain("tag-active");
  });
});
