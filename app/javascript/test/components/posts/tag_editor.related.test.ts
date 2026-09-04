import { vi } from "vitest";

vi.mock("@/pages/posts/posts", () => ({ default: { update_tag_count: vi.fn() } }));
vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { VueWrapper } from "@vue/test-utils";
import { mountTagEditor, unmountAll } from "./mountTagEditor";

afterEach(unmountAll);

const relatedLink = (w: VueWrapper, label: string) => w.findAll(".related-tag-functions a").find((a) => a.text() === label)!;
const groupTitles = (w: VueWrapper) => w.findAll(".related-title").map((t) => t.text());

describe("posts/tag_editor — findRelated", () => {
  // I1 pins: the last related-tags call still on $.ajax, and a POST — the reason
  // related_tag/bulk keeps its POST route leg. The HTTP-helper conversion flips
  // these to a GET through fetch.
  it("POSTs the full tag string to the bulk endpoint via $.ajax (I1 pin)", async () => {
    const postTags = "wolf canine ";
    const { wrapper, ajaxCalls } = await mountTagEditor({ postTags });
    await relatedLink(wrapper, "Tags").trigger("click");

    expect(ajaxCalls).toHaveLength(1);
    expect(ajaxCalls[0].url).toBe("/related_tag/bulk.json");
    expect(ajaxCalls[0].opts.method).toBe("POST");
    expect(ajaxCalls[0].opts.dataType).toBe("json");
    expect(ajaxCalls[0].opts.data.query).toBe(postTags);
    expect(ajaxCalls[0].opts.data).not.toHaveProperty("category_id");
  });

  // I2 pins: hardcoded numeric ids, unlike uploader.vue's TagCategories names.
  it("sends the hardcoded category id for Artists (I2 pin)", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Artists").trigger("click");
    expect(ajaxCalls[0].opts.data.category_id).toBe(1);
  });

  it("sends the hardcoded category id for Metatags (I2 pin)", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Metatags").trigger("click");
    expect(ajaxCalls[0].opts.data.category_id).toBe(7);
  });

  it("scopes the query to the textarea selection when one exists", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor({ postTags: "wolf dog cat " });
    const textarea = wrapper.find("textarea").element as HTMLTextAreaElement;
    textarea.selectionStart = 5;
    textarea.selectionEnd = 8;
    await relatedLink(wrapper, "Tags").trigger("click");
    expect(ajaxCalls[0].opts.data.query).toBe("dog");
  });

  it("shows the loading row while in flight and clears it on success", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Tags").trigger("click");
    expect(groupTitles(wrapper)).toContain("Loading Related Tags");

    await ajaxCalls[0].resolve({ artist: [{ name: "abe", category_id: 1 }] });
    expect(groupTitles(wrapper)).not.toContain("Loading Related Tags");
  });

  it("clears the loading row on failure with no groups and no error surface", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Tags").trigger("click");
    await ajaxCalls[0].fail();

    expect(groupTitles(wrapper)).toEqual([]);
    const Toast = (await import("@/utility/Toast")).default;
    expect(Toast.alert).not.toHaveBeenCalled();
  });

  it("renders returned groups titled and sorted by tag name, dropping empty ones", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Tags").trigger("click");
    await ajaxCalls[0].resolve({
      wolf: [{ name: "zed", category_id: 0 }, { name: "abe", category_id: 0 }],
      empty: [],
    });

    expect(groupTitles(wrapper)).toEqual(["Related: wolf"]);
    expect(wrapper.findAll(".related-item a").map((a) => a.text())).toEqual(["abe", "zed"]);
  });

  it("re-expands a collapsed panel when a category is queried", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor();
    await wrapper.find("h3 a").trigger("click");
    expect(wrapper.find(".related-tags").isVisible()).toBe(false);

    await relatedLink(wrapper, "Tags").trigger("click");
    await ajaxCalls[0].resolve({ wolf: [{ name: "abe", category_id: 0 }] });
    expect(wrapper.find(".related-tags").isVisible()).toBe(true);
  });

  // B3 pin: no re-entry guard (unlike uploader.vue), so two in-flight lookups
  // race and the LAST-RESOLVED response wins — not the last-clicked category.
  // The guard fix makes the second click a no-op, flipping this pin.
  it("lets the last-resolved response win a race (B3 pin)", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Artists").trigger("click");
    await relatedLink(wrapper, "Species").trigger("click");
    expect(ajaxCalls).toHaveLength(2);

    await ajaxCalls[1].resolve({ species: [{ name: "wolf", category_id: 5 }] });
    await ajaxCalls[0].resolve({ artist: [{ name: "abe", category_id: 1 }] });
    expect(groupTitles(wrapper)).toEqual(["Related: artist"]);
  });

  // I3 divergence pin: uploader.vue collapses on a same-category re-click; the
  // tag editor re-fires the request instead.
  it("re-fires the request when the same category is clicked again (no toggle-off)", async () => {
    const { wrapper, ajaxCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Artists").trigger("click");
    await ajaxCalls[0].resolve({ artist: [{ name: "abe", category_id: 1 }] });

    await relatedLink(wrapper, "Artists").trigger("click");
    expect(ajaxCalls).toHaveLength(2);
  });
});
