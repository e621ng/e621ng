import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import type { VueWrapper } from "@vue/test-utils";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

// The assembled tag string is observed where it actually leaves the component:
// the prop handed to <tag-preview> (located by its root class, so it survives the
// §2 registry refactor and the per-test module reset).
function tagsOf (wrapper: VueWrapper): string {
  return wrapper.findComponent(".tag-preview-area").props("tags") as string;
}

function checkButton (wrapper: VueWrapper, label: string) {
  const button = wrapper.findAll("button.toggle-button").find((b) => b.text() === label);
  if (!button) throw new Error(`No checkbox button labelled "${label}"`);
  return button;
}

describe("uploads/uploader — tag assembly", () => {
  it("is empty on a fresh form", async () => {
    const { wrapper } = await mountUploader();
    expect(tagsOf(wrapper)).toBe("");
  });

  it("includes free-text tags typed into Other Tags", async () => {
    const { wrapper } = await mountUploader();
    await wrapper.find("#post_tags").setValue("standing outside smile");
    expect(tagsOf(wrapper)).toContain("standing");
    expect(tagsOf(wrapper)).toContain("outside");
  });

  it("merges tags from the per-category textareas", async () => {
    const { wrapper } = await mountUploader();
    await wrapper.find("#post_character").setValue("pikachu");
    await wrapper.find("#post_species").setValue("rodent");
    await wrapper.find("#post_content").setValue("young");
    const tags = tagsOf(wrapper).split(" ");
    expect(tags).toContain("pikachu");
    expect(tags).toContain("rodent");
    expect(tags).toContain("young");
  });

  it("adds a checkbox tag when its button is toggled", async () => {
    const { wrapper } = await mountUploader();
    await checkButton(wrapper, "Male").trigger("click");
    await checkButton(wrapper, "Solo").trigger("click");
    const tags = tagsOf(wrapper).split(" ");
    expect(tags).toContain("male");
    expect(tags).toContain("solo");
  });

  it("derives a checkbox tag name by lowercasing and underscoring the label", async () => {
    const { wrapper } = await mountUploader();
    await checkButton(wrapper, "Zero Pictured").trigger("click");
    expect(tagsOf(wrapper).split(" ")).toContain("zero_pictured");
  });

  describe("sex pairings", () => {
    it("offers a pairing only once BOTH constituent sexes are selected", async () => {
      const { wrapper } = await mountUploader();
      expect(wrapper.findAll("button.toggle-button").some((b) => b.text() === "Male/Female")).toBe(false);

      await checkButton(wrapper, "Male").trigger("click");
      expect(wrapper.findAll("button.toggle-button").some((b) => b.text() === "Male/Female")).toBe(false);

      await checkButton(wrapper, "Female").trigger("click");
      expect(wrapper.findAll("button.toggle-button").some((b) => b.text() === "Male/Female")).toBe(true);
    });

    it("adds the pairing tag when its checkbox is selected", async () => {
      const { wrapper } = await mountUploader();
      await checkButton(wrapper, "Male").trigger("click");
      await checkButton(wrapper, "Female").trigger("click");
      await checkButton(wrapper, "Male/Female").trigger("click");
      expect(tagsOf(wrapper).split(" ")).toContain("male/female");
    });

    it("cascades: deselecting a sex clears its pairings from the tag string and UI", async () => {
      const { wrapper } = await mountUploader();
      await checkButton(wrapper, "Male").trigger("click");
      await checkButton(wrapper, "Female").trigger("click");
      await checkButton(wrapper, "Male/Female").trigger("click");
      expect(tagsOf(wrapper).split(" ")).toContain("male/female");

      await checkButton(wrapper, "Female").trigger("click");
      expect(tagsOf(wrapper).split(" ")).not.toContain("male/female");
      expect(tagsOf(wrapper).split(" ")).not.toContain("female");
      expect(wrapper.findAll("button.toggle-button").some((b) => b.text() === "Male/Female")).toBe(false);
    });
  });

  describe("whitespace / comma sanitisation (as-is)", () => {
    it("collapses runs of whitespace to single spaces and trims", async () => {
      const { wrapper } = await mountUploader();
      await wrapper.find("#post_tags").setValue("  a    b   c  ");
      expect(tagsOf(wrapper)).toBe("a b c");
    });

    // Pins the current .replace(',', ' ') behaviour: only the FIRST comma is
    // replaced. This is a known quirk — characterised, not endorsed.
    it("replaces only the first comma with a space", async () => {
      const { wrapper } = await mountUploader();
      await wrapper.find("#post_tags").setValue("a,b,c");
      expect(tagsOf(wrapper)).toBe("a b,c");
    });
  });

  describe("compact mode", () => {
    it("returns only the Other Tags field (no checkboxes/per-category inputs)", async () => {
      const { wrapper } = await mountUploader({ compactMode: true });
      expect(wrapper.find("#post_character").exists()).toBe(false);
      await wrapper.find("#post_tags").setValue("solo male");
      expect(tagsOf(wrapper)).toBe("solo male");
    });
  });
});
