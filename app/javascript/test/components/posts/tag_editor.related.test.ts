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
const queryParams = (url: string) => new URL(url, "http://localhost").searchParams;

describe("posts/tag_editor — findRelated", () => {
  it("GETs the full tag string from the bulk endpoint via the HTTP helper", async () => {
    const postTags = "wolf canine ";
    const { wrapper, fetchCalls } = await mountTagEditor({ postTags });
    await relatedLink(wrapper, "Tags").trigger("click");

    expect(fetchCalls).toHaveLength(1);
    const url = new URL(fetchCalls[0].url, "http://localhost");
    expect(url.pathname).toBe("/related_tag/bulk.json");
    expect(url.searchParams.get("query")).toBe(postTags);
    expect(url.searchParams.has("category_id")).toBe(false);
  });

  it("sends the artist category id resolved from its name", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Artists").trigger("click");
    expect(queryParams(fetchCalls[0].url).get("category_id")).toBe("1");
  });

  it("sends the meta category id resolved from its name", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Metatags").trigger("click");
    expect(queryParams(fetchCalls[0].url).get("category_id")).toBe("7");
  });

  it("maps every category link to its canonical id", async () => {
    const expected: Record<string, string> = {
      Artists: "1", Contributors: "2", Copyrights: "3",
      Characters: "4", Species: "5", Metatags: "7",
    };
    for (const [label, id] of Object.entries(expected)) {
      const { wrapper, fetchCalls, restore } = await mountTagEditor();
      await relatedLink(wrapper, label).trigger("click");
      expect(queryParams(fetchCalls[0].url).get("category_id"), label).toBe(id);
      restore();
    }
  });

  it("scopes the query to the textarea selection when one exists", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor({ postTags: "wolf dog cat " });
    const textarea = wrapper.find("textarea").element as HTMLTextAreaElement;
    textarea.selectionStart = 5;
    textarea.selectionEnd = 8;
    await relatedLink(wrapper, "Tags").trigger("click");
    expect(queryParams(fetchCalls[0].url).get("query")).toBe("dog");
  });

  it("shows the loading row while in flight and clears it on success", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Tags").trigger("click");
    expect(groupTitles(wrapper)).toContain("Loading Related Tags");

    await fetchCalls[0].resolve({ artist: [{ name: "abe", category_id: 1 }] });
    expect(groupTitles(wrapper)).not.toContain("Loading Related Tags");
  });

  it("clears the loading row on failure with no groups and no error surface", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Tags").trigger("click");
    await fetchCalls[0].fail();

    expect(groupTitles(wrapper)).toEqual([]);
    const Toast = (await import("@/utility/Toast")).default;
    expect(Toast.alert).not.toHaveBeenCalled();
  });

  it("renders returned groups titled and sorted by tag name, dropping empty ones", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Tags").trigger("click");
    await fetchCalls[0].resolve({
      wolf: [{ name: "zed", category_id: 0 }, { name: "abe", category_id: 0 }],
      empty: [],
    });

    expect(groupTitles(wrapper)).toEqual(["Related: wolf"]);
    expect(wrapper.findAll(".related-item a").map((a) => a.text())).toEqual(["abe", "zed"]);
  });

  it("re-expands a collapsed panel when a category is queried", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await wrapper.find("h3 a").trigger("click");
    expect(wrapper.find(".related-tags").isVisible()).toBe(false);

    await relatedLink(wrapper, "Tags").trigger("click");
    await fetchCalls[0].resolve({ wolf: [{ name: "abe", category_id: 0 }] });
    expect(wrapper.find(".related-tags").isVisible()).toBe(true);
  });

  // B3 fixed: the re-entry guard makes a second click a no-op while a lookup is
  // in flight — no concurrent requests, no race.
  it("ignores a second category click while a lookup is in flight (B3 fixed)", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Artists").trigger("click");
    await relatedLink(wrapper, "Species").trigger("click");
    expect(fetchCalls).toHaveLength(1);

    await fetchCalls[0].resolve({ artist: [{ name: "abe", category_id: 1 }] });
    expect(groupTitles(wrapper)).toEqual(["Related: artist"]);
  });

  // I3 parity: same-category re-click collapses the results instead of
  // re-fetching, matching uploader.vue.
  it("collapses the results on a same-category re-click without re-fetching (I3 parity)", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Artists").trigger("click");
    await fetchCalls[0].resolve({ artist: [{ name: "abe", category_id: 1 }] });
    expect(groupTitles(wrapper)).toEqual(["Related: artist"]);

    await relatedLink(wrapper, "Artists").trigger("click");
    expect(groupTitles(wrapper)).toEqual([]);
    expect(fetchCalls).toHaveLength(1);
  });

  it("re-fetches when a different category follows the collapse", async () => {
    const { wrapper, fetchCalls } = await mountTagEditor();
    await relatedLink(wrapper, "Artists").trigger("click");
    await fetchCalls[0].resolve({ artist: [{ name: "abe", category_id: 1 }] });
    await relatedLink(wrapper, "Artists").trigger("click"); // collapse

    await relatedLink(wrapper, "Species").trigger("click");
    expect(fetchCalls).toHaveLength(2);
    expect(queryParams(fetchCalls[1].url).get("category_id")).toBe("5");
  });
});
