import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { flushPromises, mount, VueWrapper } from "@vue/test-utils";
import { jsonResponse } from "../../helpers";
import TagPreview from "@/pages/uploads/new/tag_preview.vue";

const wrappers: VueWrapper[] = [];

beforeEach(() => vi.useFakeTimers());
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
  vi.useRealTimers();
});

// fetch POST /tags/preview.json → resolve with the given rows.
function stubFetch (response: any[]) {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(response) as Response);
}

// The body of the last fetch call, as posted form fields.
function lastBody (fetchSpy: ReturnType<typeof stubFetch>) {
  const init = fetchSpy.mock.calls.at(-1)![1] as RequestInit;
  return init.body as URLSearchParams;
}

function make (tags: string) {
  const wrapper = mount(TagPreview, { props: { tags } });
  wrappers.push(wrapper);
  return wrapper;
}

async function settle () {
  await vi.advanceTimersByTimeAsync(1000); // debounce
  await flushPromises();
  await flushPromises(); // fetch → json() microtasks
}

describe("uploads/tag_preview", () => {
  it("requests preview data for the current tags as a form POST with CSRF", async () => {
    const fetchSpy = stubFetch([{ name: "foo", post_count: 5, category: 0 }]);
    make("foo");
    await settle();
    const [url, init] = fetchSpy.mock.calls.at(-1)! as [string, RequestInit];
    expect(url).toBe("/tags/preview.json");
    expect(init.method).toBe("POST");
    expect(lastBody(fetchSpy).get("tags")).toBe("foo"); // form-urlencoded, not JSON
    expect("X-CSRF-Token" in (init.headers as object)).toBe(true);
    expect(wrappers[0].findAll(".tag-preview-tag").length).toBeGreaterThan(0);
  });

  it("only fetches tags missing from the cache", async () => {
    const fetchSpy = stubFetch([{ name: "foo", post_count: 5, category: 0 }]);
    const w = make("foo");
    await settle();

    fetchSpy.mockClear();
    await w.setProps({ tags: "foo bar" });
    await settle();
    expect(lastBody(fetchSpy).get("tags")).toBe("bar");
  });

  it("persists the enabled flag and hides the preview when toggled off", async () => {
    stubFetch([{ name: "foo", post_count: 5, category: 0 }]);
    const w = make("foo");
    await settle();

    const toggle = () => w.findAll("a").find((a) => a.text().includes("tag preview"))!;
    expect(toggle().text()).toContain("Hide");

    await toggle().trigger("click");
    expect(window.localStorage.getItem("e6.posts.tagpreview")).toBe("false");
    expect(w.find(".tag-preview").exists()).toBe(false);
    expect(toggle().text()).toContain("Show");
  });

  it("marks an invalid-category tag as invalid", async () => {
    stubFetch([{ id: 1, name: "foo", post_count: 5, category: 6 }]); // 6 = invalid
    const w = make("foo");
    await settle();
    expect(w.find(".tag-preview-tag .invalid").exists()).toBe(true);
  });

  it("clears the duplicate badge when the colliding tag is removed (no cache mutation)", async () => {
    stubFetch([
      { id: 1, name: "wolf", post_count: 5, category: 0 },
      { id: 2, name: "wolves", post_count: 3, category: 0, alias: "wolf" }, // resolves to "wolf"
    ]);
    const w = make("wolf wolves");
    await settle();
    expect(w.findAll(".tag-preview-tag .duplicate").length).toBeGreaterThan(0);

    await w.setProps({ tags: "wolves" }); // drop the collision; "wolves" is already cached
    await settle();
    expect(w.find(".tag-preview-tag .duplicate").exists()).toBe(false);
  });

  it("marks a tag implied by another as implied", async () => {
    stubFetch([
      { id: 1, name: "foo", post_count: 5, category: 0, implies: ["bar"] },
      { id: 2, name: "bar", post_count: 9, category: 0 },
    ]);
    const w = make("foo");
    await settle();
    expect(w.find(".tag-preview-tag .implied").exists()).toBe(true);
  });
});
