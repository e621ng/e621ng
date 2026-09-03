import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { flushPromises, mount, VueWrapper } from "@vue/test-utils";
import ArtistTagInput from "@/pages/uploads/new/artist_tag_input.vue";

const wrappers: VueWrapper[] = [];

beforeEach(() => vi.useFakeTimers());
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
  vi.useRealTimers();
});

// Route fetch responses by URL. `tags` is the /tags.json result, `aliases` the /tag_aliases.json result.
function stubFetch (tags: any[], aliases: any[] = []) {
  return vi.spyOn(globalThis, "fetch").mockImplementation((url: any) => {
    const body = String(url).includes("/tag_aliases.json") ? aliases : tags;
    return Promise.resolve({ ok: true, json: async () => body } as Response);
  });
}

function make (modelValue = "") {
  const wrapper = mount(ArtistTagInput, { props: { modelValue } });
  wrappers.push(wrapper);
  return wrapper;
}

async function checkAfter (w: VueWrapper, value: string) {
  await w.setProps({ modelValue: value });
  await vi.advanceTimersByTimeAsync(1000); // debounce
  await flushPromises();
  await flushPromises(); // second fetch hop (aliases), if any
}

const notices = (w: VueWrapper) => w.findAll(".artist-tag-notice");
const lastEmit = (w: VueWrapper) => w.emitted("update:modelValue")?.at(-1)?.[0];

describe("uploads/artist_tag_input", () => {
  it("emits typed input immediately", async () => {
    const w = make();
    await w.find("textarea").setValue("picasso");
    expect(lastEmit(w)).toBe("picasso");
  });

  it("offers to make an unknown tag into an artist tag", async () => {
    stubFetch([], []); // not found + no alias
    const w = make();
    await checkAfter(w, "newartist");
    expect(notices(w)).toHaveLength(1);
    expect(notices(w)[0].attributes("data-type")).toBe("make_artist");
    expect(notices(w)[0].text()).toContain("newartist");
  });

  it("warns that a populated general tag is the wrong category", async () => {
    stubFetch([{ name: "tree", category: 0, post_count: 500 }]);
    const w = make();
    await checkAfter(w, "tree");
    expect(notices(w)[0].attributes("data-type")).toBe("wrong");
    expect(notices(w)[0].text()).toContain("populated general tag");
  });

  it("says nothing when the tag is already an artist tag", async () => {
    stubFetch([{ name: "picasso", category: 1, post_count: 100 }]);
    const w = make();
    await checkAfter(w, "picasso");
    expect(notices(w)).toHaveLength(0);
  });

  it("names the wrong category for a non-general tag", async () => {
    stubFetch([{ name: "pikachu", category: 4, post_count: 100 }]);
    const w = make();
    await checkAfter(w, "pikachu");
    expect(notices(w)[0].text()).toContain("character");
  });

  it("prefixes with artist: when 'make artist' is clicked", async () => {
    stubFetch([], []);
    const w = make();
    await checkAfter(w, "newartist");
    await notices(w)[0].find("a").trigger("click");
    expect(lastEmit(w)).toBe("artist:newartist ");
  });

  it("removes a wrong-category tag when its notice is clicked", async () => {
    stubFetch([{ name: "tree", category: 0, post_count: 500 }]);
    const w = make();
    await checkAfter(w, "tree");
    await notices(w)[0].find("a").trigger("click");
    expect(lastEmit(w)).toBe(" "); // removing the only tag leaves the trailing-space artifact
  });

  it("ignores tags already carrying an artist:/art: prefix", async () => {
    const fetchSpy = stubFetch([]);
    const w = make();
    await checkAfter(w, "artist:picasso art:monet");
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(notices(w)).toHaveLength(0);
  });
});
