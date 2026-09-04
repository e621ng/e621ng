import { afterEach, describe, expect, it } from "vitest";
import { mount, VueWrapper } from "@vue/test-utils";
import TagCounter from "@/pages/uploads/new/tag_counter.vue";

const wrappers: VueWrapper[] = [];
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
});

function make (tags: string) {
  const wrapper = mount(TagCounter, { props: { tags } });
  wrappers.push(wrapper);
  return wrapper;
}

const countText = (w: VueWrapper) => w.find(".count").text();
const faceClass = (w: VueWrapper) => w.find("#face").classes().find((c) => c.startsWith("face-"));
const tagList = (n: number) => Array.from({ length: n }, (_, i) => `tag${i}`).join(" ");

describe("uploads/tag_counter", () => {
  it("shows '0 tags' for an empty value", () => {
    expect(countText(make(""))).toBe("0 tags");
  });

  it("uses the singular for exactly one tag", () => {
    expect(countText(make("wolf "))).toBe("1 tag");
  });

  it("pluralizes and counts across newline groups", () => {
    expect(countText(make("wolf canine\nforest tree "))).toBe("4 tags");
  });

  it("counts unique tokens only", () => {
    expect(countText(make("wolf wolf canine"))).toBe("2 tags");
  });

  it("does not fold case when deduplicating (raw-token semantics)", () => {
    expect(countText(make("Wolf wolf"))).toBe("2 tags");
  });

  it("picks the face by count thresholds", () => {
    expect(faceClass(make(tagList(14)))).toBe("face-frown");
    expect(faceClass(make(tagList(15)))).toBe("face-meh");
    expect(faceClass(make(tagList(24)))).toBe("face-meh");
    expect(faceClass(make(tagList(25)))).toBe("face-smile");
  });

  it("renders the matching face icon paths", () => {
    // The frown and smile mouths are distinct path data.
    expect(make(tagList(3)).find("#face").html()).toContain("M16 16s-1.5-2-4-2-4 2-4 2");
    expect(make(tagList(30)).find("#face").html()).toContain("M8 14s1.5 2 4 2 4-2 4-2");
  });
});
