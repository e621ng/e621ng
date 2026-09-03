import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import type { VueWrapper } from "@vue/test-utils";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

const value = (w: VueWrapper, selector: string) => (w.find(selector).element as HTMLInputElement | HTMLTextAreaElement).value;
const tagsOf = (w: VueWrapper) => w.findComponent(".tag-preview-area").props("tags") as string;
const checkActive = (w: VueWrapper, label: string) => w.findAll("button.toggle-button").find((b) => b.text() === label)?.classes().includes("active") ?? false;

describe("uploads/uploader — query-param import", () => {
  it("imports free-form tags into Other Tags (with the trailing-space quirk)", async () => {
    const { wrapper } = await mountUploader({ search: "?tags=a+a+b" });
    // Deduped, and a trailing space is appended ("or vue panics").
    expect(value(wrapper, "#post_tags")).toBe("a b ");
  });

  it("activates the matching checkbox when an imported tag owns one (normal mode)", async () => {
    const { wrapper } = await mountUploader({ search: "?tags=male+solo+standing" });
    // Route-by-value: checkbox-owned tags flip their checkbox on...
    expect(checkActive(wrapper, "Male")).toBe(true);
    expect(checkActive(wrapper, "Solo")).toBe(true);
    // ...and every imported tag still ends up in the assembled tag string.
    const tags = tagsOf(wrapper).split(" ");
    expect(tags).toEqual(expect.arrayContaining(["male", "solo", "standing"]));
  });

  it("folds a checkbox-owned tag into Other Tags in compact mode (no checkboxes exist)", async () => {
    const { wrapper } = await mountUploader({ compactMode: true, search: "?tags=male" });
    expect(wrapper.findAll("button.toggle-button").some((b) => b.text() === "Male")).toBe(false);
    expect(value(wrapper, "#post_tags")).toContain("male");
  });

  it("routes per-category tag params to their fields in normal mode", async () => {
    const { wrapper } = await mountUploader({
      search: "?tags-artist=picasso&tags-character=pikachu&tags-species=rodent&tags-content=young",
    });
    expect(value(wrapper, "#post_artist")).toContain("picasso");
    expect(value(wrapper, "#post_character")).toContain("pikachu");
    expect(value(wrapper, "#post_species")).toContain("rodent");
    expect(value(wrapper, "#post_content")).toContain("young");
  });

  it("folds every tag param into Other Tags in compact mode", async () => {
    const { wrapper } = await mountUploader({
      compactMode: true,
      search: "?tags-artist=picasso&tags-character=pikachu",
    });
    const other = value(wrapper, "#post_tags");
    expect(other).toContain("picasso");
    expect(other).toContain("pikachu");
  });

  it("imports a valid rating and ignores an invalid one", async () => {
    const explicit = (await mountUploader({ search: "?rating=Explicit" })).wrapper;
    expect(explicit.find(".rating-e").classes()).toContain("active");

    const bogus = (await mountUploader({ search: "?rating=z" })).wrapper;
    expect(bogus.find(".rating-e").classes()).not.toContain("active");
    expect(bogus.find(".rating-s").classes()).not.toContain("active");
  });

  it("imports parent, description, and comma-split sources", async () => {
    const { wrapper } = await mountUploader({
      search: "?parent=12345&description=hello+there&sources=https://a,https://b",
    });
    expect(value(wrapper, "input[placeholder='Ex. 12345']")).toBe("12345");
    expect(value(wrapper, "#post_description")).toBe("hello there");
    const sourceInputs = wrapper.findAll(".upload-source-row input");
    expect(sourceInputs.map((i) => (i.element as HTMLInputElement).value)).toEqual(["https://a", "https://b"]);
  });

  describe("permission-gated params", () => {
    it("applies rating_locked / locked_tags / upload_as_pending only when allowed", async () => {
      const { wrapper } = await mountUploader({
        admin: true,
        privileged: true,
        uploadFree: true,
        search: "?rating_locked=true&locked_tags=secret&upload_as_pending=true",
      });
      expect(value(wrapper, "input[data-autocomplete='tag-query']")).toBe("secret");
      // rating-lock + as-pending checkboxes are both checked
      const checked = wrapper.findAll("input[type='checkbox']").filter((c) => (c.element as HTMLInputElement).checked);
      expect(checked.length).toBeGreaterThanOrEqual(2);
    });

    it("ignores gated params for a regular member (fields absent)", async () => {
      const { wrapper } = await mountUploader({
        search: "?rating_locked=true&locked_tags=secret&upload_as_pending=true",
      });
      expect(wrapper.find("input[data-autocomplete='tag-query']").exists()).toBe(false);
    });
  });
});
