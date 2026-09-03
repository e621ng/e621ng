import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import type { VueWrapper } from "@vue/test-utils";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

// The "Related:" bar links, in order: Tags, Artists, Contributors, Copyrights, Characters, Species, Metatags.
const relatedLink = (w: VueWrapper, label: string) => w.findAll(".related-tag-functions a").find((a) => a.text() === label)!;

function stubRelated (getJSON: any, data: Record<string, { name: string, category_id: number }[]>) {
  getJSON.mockImplementation((_url: string, _params: unknown, cb: (d: unknown) => void) => {
    cb(data);
    return { always: (fn: () => void) => fn() };
  });
}

const relatedItem = (w: VueWrapper, name: string) => w.findAll(".related-item a").find((a) => a.text() === name);

describe("uploads/uploader — related tags", () => {
  it("queries the endpoint with the current tags and category id", async () => {
    const { wrapper, getJSON } = await mountUploader();
    await wrapper.find("#post_tags").setValue("wolf outside");
    stubRelated(getJSON, {});
    await relatedLink(wrapper, "Artists").trigger("click");
    expect(getJSON).toHaveBeenCalledWith(
      "/related_tag/bulk.json",
      { query: "wolf outside", category_id: 1 },
      expect.any(Function),
    );
  });

  it("renders returned groups, sorted by tag name", async () => {
    const { wrapper, getJSON } = await mountUploader();
    await wrapper.find("#post_tags").setValue("seed");
    stubRelated(getJSON, { artist: [{ name: "zed", category_id: 1 }, { name: "abe", category_id: 1 }] });
    await relatedLink(wrapper, "Tags").trigger("click");

    expect(wrapper.find(".related-title").text()).toBe("Related: artist");
    const items = wrapper.findAll(".related-item a").map((a) => a.text());
    expect(items).toEqual(["abe", "zed"]);
  });

  it("toggles the panel off when the same category is clicked twice", async () => {
    const { wrapper, getJSON } = await mountUploader();
    await wrapper.find("#post_tags").setValue("seed");
    stubRelated(getJSON, { artist: [{ name: "abe", category_id: 1 }] });
    await relatedLink(wrapper, "Artists").trigger("click");
    expect(wrapper.find(".related-section").exists()).toBe(true);

    await relatedLink(wrapper, "Artists").trigger("click");
    expect(wrapper.find(".related-section").exists()).toBe(false);
  });

  describe("pushTag routing (via clicking a related tag)", () => {
    it("appends a non-checkbox tag to Other Tags", async () => {
      const { wrapper, getJSON } = await mountUploader();
      await wrapper.find("#post_tags").setValue("seed");
      stubRelated(getJSON, { related: [{ name: "foobar", category_id: 0 }] });
      await relatedLink(wrapper, "Tags").trigger("click");

      await relatedItem(wrapper, "foobar")!.trigger("click");
      expect((wrapper.find("#post_tags").element as HTMLTextAreaElement).value).toContain("foobar");
    });

    it("toggles the matching checkbox for a checkbox tag instead", async () => {
      const { wrapper, getJSON } = await mountUploader();
      await wrapper.find("#post_tags").setValue("seed");
      stubRelated(getJSON, { related: [{ name: "male", category_id: 0 }] });
      await relatedLink(wrapper, "Tags").trigger("click");

      await relatedItem(wrapper, "male")!.trigger("click");
      const maleButton = wrapper.findAll("button.toggle-button").find((b) => b.text() === "Male")!;
      expect(maleButton.classes()).toContain("active");
      // Routed to the checkbox, not appended as free text.
      expect((wrapper.find("#post_tags").element as HTMLTextAreaElement).value).not.toContain("male");
    });
  });
});
