import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { flushPromises, VueWrapper } from "@vue/test-utils";
import { mountTagEditor, unmountAll } from "./mountTagEditor";

afterEach(unmountAll);

const countText = (w: VueWrapper) => w.find(".header .count").text();
const faceClass = (w: VueWrapper) => w.find(".header svg.face").classes().find((c) => c.startsWith("face-"));
const tagList = (n: number) => Array.from({ length: n }, (_, i) => `tag${i}`).join(" ");

// The counter is a pure computed over the tag string (tag_counter.vue) — no
// DOM reads, no event wiring, no flush timing. Semantics are unit-tested in
// test/components/uploads/tag_counter.test.ts; this spec covers the editor
// integration.
describe("posts/tag_editor — tag counter", () => {
  it("renders the correct count immediately at mount", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "wolf canine\nforest tree " });
    expect(countText(wrapper)).toBe("4 tags");
  });

  it("updates the count as the value changes", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "wolf " });
    await wrapper.find("textarea").setValue("wolf canine feral");
    expect(countText(wrapper)).toBe("3 tags");
  });

  it("updates the count after a related tag is toggled in", async () => {
    const { wrapper } = await mountTagEditor({ postTags: "wolf " });
    (wrapper.findComponent(".related-tags") as any).vm.$emit("tag-active", "feral", true);
    await flushPromises();
    expect(countText(wrapper)).toBe("2 tags");
  });

  it("flips the face when the count crosses a threshold", async () => {
    const { wrapper } = await mountTagEditor({ postTags: tagList(14) });
    expect(faceClass(wrapper)).toBe("face-frown");
    await wrapper.find("textarea").setValue(tagList(15));
    expect(faceClass(wrapper)).toBe("face-meh");
  });
});
