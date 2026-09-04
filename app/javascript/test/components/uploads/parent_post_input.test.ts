import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { flushPromises, mount, VueWrapper } from "@vue/test-utils";
import ParentPostInput from "@/pages/uploads/new/parent_post_input.vue";

const wrappers: VueWrapper[] = [];

beforeEach(() => vi.useFakeTimers());
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
  vi.useRealTimers();
});

function make () {
  const wrapper = mount(ParentPostInput, { props: { modelValue: "" } });
  wrappers.push(wrapper);
  return wrapper;
}

function fetchOk (post: unknown) {
  return { ok: true, status: 200, json: async () => ({ post }) };
}

async function type (w: VueWrapper, v: string) {
  await w.find("input").setValue(v);
  await vi.advanceTimersByTimeAsync(500); // debounce
  await flushPromises();
}

const error = (w: VueWrapper) => w.find(".upload-parent-error");

describe("uploads/parent_post_input", () => {
  it("emits the trimmed value immediately on input", async () => {
    const w = make();
    await w.find("input").setValue("  55  ");
    expect(w.emitted("update:modelValue")!.at(-1)).toEqual(["55"]);
  });

  it.each([["0"], ["-1"], ["1.5"], ["abc"]])("rejects %s as a non-positive-integer without fetching", async (bad) => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const w = make();
    await type(w, bad);
    expect(error(w).exists()).toBe(true);
    expect(error(w).text()).toContain("positive integer");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("fetches and shows a preview for a valid id", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      fetchOk({ id: 123, preview: { url: "/data/preview/123.jpg" } }) as unknown as Response,
    );
    const w = make();
    await type(w, "123");
    expect(globalThis.fetch).toHaveBeenCalledWith("/posts/123.json", expect.anything());
    const img = w.find(".upload-parent-preview img");
    expect(img.exists()).toBe(true);
    expect(img.attributes("src")).toBe("/data/preview/123.jpg");
  });

  it("reports a 404 as not found", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue({ ok: false, status: 404 } as unknown as Response);
    const w = make();
    await type(w, "999");
    expect(error(w).text()).toContain("not found");
  });

  it("reports a post with no preview as unavailable", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(fetchOk({ id: 7, preview: { url: null } }) as unknown as Response);
    const w = make();
    await type(w, "7");
    expect(error(w).text()).toContain("unavailable");
  });
});
