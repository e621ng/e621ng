import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import type { VueWrapper } from "@vue/test-utils";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

const otherTags = (w: VueWrapper) => (w.find("#post_tags").element as HTMLTextAreaElement).value;

describe("uploads/uploader — tag-locked site prefill", () => {
  it("prefills the site's required tags into Other Tags", async () => {
    const { wrapper } = await mountUploader({ requiredTags: ["my_little_pony"] });
    expect(otherTags(wrapper)).toBe("my_little_pony ");
  });

  it("does not duplicate a required tag that also arrives via the URL", async () => {
    const { wrapper } = await mountUploader({ requiredTags: ["my_little_pony"], search: "?tags=my_little_pony+twilight_sparkle" });
    expect(otherTags(wrapper).trim().split(" ")).toEqual(["my_little_pony", "twilight_sparkle"]);
  });

  it("prefills nothing on an unlocked site", async () => {
    const { wrapper } = await mountUploader({});
    expect(otherTags(wrapper)).toBe("");
  });
});
