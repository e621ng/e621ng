import { vi } from "vitest";

vi.mock("@/pages/posts/posts", () => ({ default: { update_tag_count: vi.fn() } }));
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
    const { wrapper, ajaxCalls } = await mountTagEditor({ postTags: "wolf " });
    await wrapper.find(".related-tag-functions a").trigger("click"); // "Tags"
    await ajaxCalls[0].resolve({ related: [{ name: "feral", category_id: 0 }] });

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

  // B2 pin: the remove branch rebuilds the value from this.tags.toLowerCase(),
  // so one removal lowercases the WHOLE textarea, collapses whitespace on the
  // matched line, and appends an extra trailing space. The fix (edit the
  // original-case string) flips this pin.
  it("lowercases and reflows the entire value on remove (B2 pin)", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "Wolf   Canine\nForest Tree " });
    await toggleTag(wrapper, "canine", false);
    // Matched line collapsed + lowercased; untouched line lowercased but keeps
    // its trailing space; an extra " " is appended after the join.
    expect(textareaValue(wrapper)).toBe("wolf\nforest tree  ");
  });

  it("removes the tag from its own line, leaving other groups' content alone (B2 pin)", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "wolf canine\nforest tree " });
    await toggleTag(wrapper, "tree", false);
    expect(textareaValue(wrapper)).toBe("wolf canine\nforest ");
  });

  it("reflects toggles back into the related item's active state", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor({ postTags: "wolf canine " });
    await wrapper.find(".related-tag-functions a").trigger("click");
    await ajaxCalls[0].resolve({ related: [{ name: "canine", category_id: 0 }] });

    const item = relatedItem(wrapper, "canine")!;
    expect(item.classes()).toContain("tag-active");

    await item.trigger("click"); // active → emits remove
    expect(textareaValue(wrapper)).not.toContain("canine");
    expect(item.classes()).not.toContain("tag-active");
  });
});
