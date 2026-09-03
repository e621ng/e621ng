import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { flushPromises, mount, VueWrapper } from "@vue/test-utils";
import $ from "jquery";
import TagPreview from "@/pages/uploads/new/tag_preview.vue";

const wrappers: VueWrapper[] = [];

beforeEach(() => vi.useFakeTimers());
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
  vi.useRealTimers();
});

// $.ajax POST /tags/preview.json → immediately invoke success with the given rows.
function stubAjax (response: any[]) {
  return vi.spyOn($, "ajax").mockImplementation(((_url: string, opts: any) => {
    opts.success(response);
    return undefined;
  }) as any);
}

function make (tags: string) {
  const wrapper = mount(TagPreview, { props: { tags } });
  wrappers.push(wrapper);
  return wrapper;
}

async function settle () {
  await vi.advanceTimersByTimeAsync(1000); // debounce
  await flushPromises();
}

describe("uploads/tag_preview", () => {
  it("requests preview data for the current tags (enabled by default)", async () => {
    const ajax = stubAjax([{ name: "foo", post_count: 5, category: 0 }]);
    make("foo");
    await settle();
    expect(ajax).toHaveBeenCalledWith("/tags/preview.json", expect.objectContaining({
      method: "POST",
      data: { tags: "foo" },
    }));
    expect(wrappers[0].findAll(".tag-preview-tag").length).toBeGreaterThan(0);
  });

  it("only fetches tags missing from the cache", async () => {
    const ajax = stubAjax([{ name: "foo", post_count: 5, category: 0 }]);
    const w = make("foo");
    await settle();

    ajax.mockClear();
    await w.setProps({ tags: "foo bar" });
    await settle();
    expect(ajax).toHaveBeenCalledWith("/tags/preview.json", expect.objectContaining({ data: { tags: "bar" } }));
  });

  it("persists the enabled flag and hides the preview when toggled off", async () => {
    stubAjax([{ name: "foo", post_count: 5, category: 0 }]);
    const w = make("foo");
    await settle();

    const toggle = () => w.findAll("a").find((a) => a.text().includes("tag preview"))!;
    expect(toggle().text()).toContain("Hide");

    await toggle().trigger("click");
    expect(window.localStorage.getItem("e6.posts.tagpreview")).toBe("false");
    expect(w.find(".tag-preview").exists()).toBe(false);
    expect(toggle().text()).toContain("Show");
  });

  it("marks a tag implied by another as implied", async () => {
    stubAjax([
      { id: 1, name: "foo", post_count: 5, category: 0, implies: ["bar"] },
      { id: 2, name: "bar", post_count: 9, category: 0 },
    ]);
    const w = make("foo");
    await settle();
    expect(w.find(".tag-preview-tag .implied").exists()).toBe(true);
  });
});
