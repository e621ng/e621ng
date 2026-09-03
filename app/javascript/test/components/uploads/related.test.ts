import { afterEach, describe, expect, it } from "vitest";
import { mount, VueWrapper } from "@vue/test-utils";
import Related from "@/pages/uploads/new/related.vue";

const wrappers: VueWrapper[] = [];
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
  delete (window as any).uploaderSettings;
});

function make (props: Record<string, unknown> = {}) {
  const wrapper = mount(Related, {
    props: { tags: [], related: [], loading: false, ...props },
  });
  wrappers.push(wrapper);
  return wrapper;
}

const titles = (w: VueWrapper) => w.findAll(".related-title").map((t) => t.text());
const itemText = (w: VueWrapper) => w.findAll(".related-item a").map((a) => a.text());

describe("uploads/related", () => {
  it("renders Quick Tags and Recent groups from props, recent sorted by name", async () => {
    const w = make({
      uploadedTags: [{ name: "fav", category_id: 0 }],
      recentTags: [{ name: "zzz", category_id: 0 }, { name: "aaa", category_id: 0 }],
    });
    expect(titles(w)).toEqual(["Quick Tags", "Recent"]);
    // Recent is sorted; Quick Tags keeps its given order.
    expect(itemText(w)).toEqual(["fav", "aaa", "zzz"]);
  });

  it("falls back to window.uploaderSettings when the props are absent", async () => {
    (window as any).uploaderSettings = { uploadTags: [{ name: "legacy", category_id: 0 }], recentTags: [] };
    const w = make(); // no uploadedTags/recentTags props
    expect(titles(w)).toContain("Quick Tags");
    expect(itemText(w)).toContain("legacy");
  });

  it("renders server-provided related groups", () => {
    const w = make({ related: [{ title: "Related: artist", tags: [{ name: "picasso", category_id: 1 }] }] });
    expect(titles(w)).toContain("Related: artist");
    expect(itemText(w)).toContain("picasso");
  });

  it("shows a loading placeholder group while loading", () => {
    const w = make({ loading: true });
    expect(titles(w)).toContain("Loading Related Tags");
  });

  it("splits a group into rows of 15", () => {
    const tags = Array.from({ length: 20 }, (_, i) => ({ name: `t${i}`, category_id: 0 }));
    const w = make({ related: [{ title: "Big", tags }] });
    expect(w.findAll(".related-section .related-items").length).toBe(2);
  });

  it("marks active tags and applies the category class", () => {
    const w = make({
      tags: ["picasso"],
      related: [{ title: "Related: artist", tags: [{ name: "picasso", category_id: 1 }, { name: "monet", category_id: 1 }] }],
    });
    const picasso = w.findAll(".related-item a").find((a) => a.text() === "picasso")!;
    expect(picasso.classes()).toContain("tag-active");
    expect(picasso.classes()).toContain("tag-type-1");
    expect(w.findAll(".related-item a").find((a) => a.text() === "monet")!.classes()).not.toContain("tag-active");
  });

  it("emits tag-active with the toggled state on click", async () => {
    const w = make({
      tags: ["picasso"],
      related: [{ title: "Related: artist", tags: [{ name: "picasso", category_id: 1 }, { name: "monet", category_id: 1 }] }],
    });
    await w.findAll(".related-item a").find((a) => a.text() === "monet")!.trigger("click");
    expect(w.emitted("tag-active")!.at(-1)).toEqual(["monet", true]); // not active → add

    await w.findAll(".related-item a").find((a) => a.text() === "picasso")!.trigger("click");
    expect(w.emitted("tag-active")!.at(-1)).toEqual(["picasso", false]); // active → remove
  });
});
