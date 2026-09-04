import { vi } from "vitest";

vi.mock("@/pages/posts/posts", () => ({ default: { update_tag_count: vi.fn() } }));
vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { mountTagEditor, unmountAll } from "./mountTagEditor";

afterEach(unmountAll);

describe("posts/tag_editor — mount", () => {
  it("renders the textarea with the uploaderSettings tag string verbatim", async () => {
    const postTags = "Wolf canine\nforest tree ";
    const { wrapper } = await mountTagEditor({ postTags });
    const textarea = wrapper.find("textarea").element as HTMLTextAreaElement;
    expect(textarea.value).toBe(postTags);
  });

  it("participates in the server-rendered form via id/name, with autocomplete markup", async () => {
    const { wrapper } = await mountTagEditor();
    const textarea = wrapper.find("textarea");
    expect(textarea.attributes("id")).toBe("post_tag_string");
    expect(textarea.attributes("name")).toBe("post[tag_string]");
    expect(textarea.attributes("data-autocomplete")).toBe("tag-edit");
  });

  it("focuses the textarea after the mount timer", async () => {
    const { wrapper } = await mountTagEditor();
    expect(document.activeElement).toBe(wrapper.find("textarea").element);
  });

  it("renders the seven related-category links", async () => {
    const { wrapper } = await mountTagEditor();
    const labels = wrapper.findAll(".related-tag-functions a").map((a) => a.text());
    expect(labels).toEqual(["Tags", "Artists", "Contributors", "Copyrights", "Characters", "Species", "Metatags"]);
  });

  it("shows the related panel expanded by default and collapses it via the header link", async () => {
    const { wrapper } = await mountTagEditor();
    const headerLink = wrapper.find("h3 a");
    expect(wrapper.find(".related-tags").isVisible()).toBe(true);
    expect(headerLink.text()).toBe("<<");

    await headerLink.trigger("click");
    expect(wrapper.find(".related-tags").isVisible()).toBe(false);
    expect(headerLink.text()).toBe(">>");
  });

  // G1 pin: related.vue has no props here, so Quick Tags / Recent come from the
  // window.uploaderSettings side-channel that RelatedTag.ts populates. The
  // globals cleanup replaces this with real props — these tests keep the groups
  // rendering through that change.
  it("renders Quick Tags and Recent groups from the uploaderSettings global (G1 pin)", async () => {
    const { wrapper } = await mountTagEditor({
      uploadTags: [{ name: "signature", category_id: 0 }],
      recentTags: [{ name: "sky", category_id: 0 }],
    });
    const titles = wrapper.findAll(".related-title").map((t) => t.text());
    expect(titles).toEqual(["Quick Tags", "Recent"]);
    expect(wrapper.findAll(".related-item a").map((a) => a.text())).toEqual(["signature", "sky"]);
  });

  it("initializes tag-edit autocomplete when the user setting is on", async () => {
    const { initializeAutocomplete } = await mountTagEditor({ autocomplete: true });
    expect(initializeAutocomplete).toHaveBeenCalledWith("tag-edit");
  });

  it("skips autocomplete init when the user setting is off", async () => {
    const { initializeAutocomplete } = await mountTagEditor({ autocomplete: false });
    expect(initializeAutocomplete).not.toHaveBeenCalled();
  });

  it("feeds the current tag string to the tag preview", async () => {
    const postTags = "wolf canine ";
    const { wrapper } = await mountTagEditor({ postTags });
    const preview = wrapper.findComponent(".tag-preview-area") as any;
    expect(preview.props("tags")).toBe(postTags);
  });
});
