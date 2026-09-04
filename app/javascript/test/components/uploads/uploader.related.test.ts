import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { flushPromises, VueWrapper } from "@vue/test-utils";
import { jsonResponse } from "../../helpers";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

const relatedLink = (w: VueWrapper, label: string) => w.findAll(".related-tag-functions a").find((a) => a.text() === label)!;
const relatedItem = (w: VueWrapper, name: string) => w.findAll(".related-item a").find((a) => a.text() === name);

function stubRelated (fetchSpy: any, data: Record<string, { name: string, category_id: number }[]>) {
  fetchSpy.mockResolvedValue(jsonResponse(data));
}

// Click a "Related:" bar link and let the async fetch settle.
async function loadRelated (w: VueWrapper, label: string) {
  await relatedLink(w, label).trigger("click");
  await flushPromises();
}

describe("uploads/uploader — related tags", () => {
  // POSTed, not GETed: the query is the full tag string, which can far exceed
  // URL length limits on a heavily-tagged post.
  it("POSTs the current tags and category id to the endpoint", async () => {
    const { wrapper, fetchSpy } = await mountUploader();
    await wrapper.find("#post_tags").setValue("wolf outside");
    stubRelated(fetchSpy, {});
    await loadRelated(wrapper, "Artists");
    const [url, init] = fetchSpy.mock.calls.at(-1)! as [string, RequestInit];
    expect(url).toBe("/related_tag/bulk.json");
    expect(init.method).toBe("POST");
    const params = new URLSearchParams(String(init.body));
    expect(params.get("query")).toBe("wolf outside");
    expect(params.get("category_id")).toBe("1");
  });

  it("sends category_id=0 for the general category (not treated as 'no filter')", async () => {
    const { wrapper, fetchSpy } = await mountUploader();
    await wrapper.find("#post_tags").setValue("seed");
    stubRelated(fetchSpy, {});
    await (wrapper.vm as any).findRelated("general"); // idFor('general') === 0
    await flushPromises();
    const init = fetchSpy.mock.calls.at(-1)![1] as RequestInit;
    expect(new URLSearchParams(String(init.body)).get("category_id")).toBe("0");
  });

  it("renders returned groups, sorted by tag name", async () => {
    const { wrapper, fetchSpy } = await mountUploader();
    await wrapper.find("#post_tags").setValue("seed");
    stubRelated(fetchSpy, { artist: [{ name: "zed", category_id: 1 }, { name: "abe", category_id: 1 }] });
    await loadRelated(wrapper, "Tags");

    expect(wrapper.find(".related-title").text()).toBe("Related: artist");
    expect(wrapper.findAll(".related-item a").map((a) => a.text())).toEqual(["abe", "zed"]);
  });

  it("shows no results when the lookup fails, even if the body is JSON", async () => {
    const { wrapper, fetchSpy } = await mountUploader();
    await wrapper.find("#post_tags").setValue("seed");
    // A 500 whose body is valid JSON must NOT be rendered as related tags.
    fetchSpy.mockResolvedValue(jsonResponse({ artist: [{ name: "abe", category_id: 1 }] }, { status: 500 }));
    await loadRelated(wrapper, "Artists");
    expect(wrapper.find(".related-section").exists()).toBe(false);
    expect((wrapper.vm as any).loadingRelated).toBe(false);
  });

  it("toggles the panel off when the same category is clicked twice", async () => {
    const { wrapper, fetchSpy } = await mountUploader();
    await wrapper.find("#post_tags").setValue("seed");
    stubRelated(fetchSpy, { artist: [{ name: "abe", category_id: 1 }] });
    await loadRelated(wrapper, "Artists");
    expect(wrapper.find(".related-section").exists()).toBe(true);

    await loadRelated(wrapper, "Artists");
    expect(wrapper.find(".related-section").exists()).toBe(false);
  });

  describe("pushTag routing (via clicking a related tag)", () => {
    it("appends a non-checkbox tag to Other Tags", async () => {
      const { wrapper, fetchSpy } = await mountUploader();
      await wrapper.find("#post_tags").setValue("seed");
      stubRelated(fetchSpy, { related: [{ name: "foobar", category_id: 0 }] });
      await loadRelated(wrapper, "Tags");

      await relatedItem(wrapper, "foobar")!.trigger("click");
      expect((wrapper.find("#post_tags").element as HTMLTextAreaElement).value).toContain("foobar");
    });

    it("toggles the matching checkbox for a checkbox tag instead", async () => {
      const { wrapper, fetchSpy } = await mountUploader();
      await wrapper.find("#post_tags").setValue("seed");
      stubRelated(fetchSpy, { related: [{ name: "male", category_id: 0 }] });
      await loadRelated(wrapper, "Tags");

      await relatedItem(wrapper, "male")!.trigger("click");
      const maleButton = wrapper.findAll("button.toggle-button").find((b) => b.text() === "Male")!;
      expect(maleButton.classes()).toContain("active");
      expect((wrapper.find("#post_tags").element as HTMLTextAreaElement).value).not.toContain("male");
    });
  });
});
