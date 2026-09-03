import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { nextTick } from "vue";
import type { VueWrapper } from "@vue/test-utils";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

const artistField = (w: VueWrapper) => (w.find("#post_artist").element as HTMLTextAreaElement);
const linkedButton = (w: VueWrapper, name: string) => w.findAll(".upload-artist-tags button").find((b) => b.text() === name)!;

describe("uploads/uploader — verified artist buttons", () => {
  it("renders one button per linked artist in normal mode", async () => {
    const { wrapper } = await mountUploader({ verifiedArtistTags: ["artist_a", "artist_b"] });
    expect(wrapper.find(".upload-artist-tags").exists()).toBe(true);
    expect(wrapper.text()).toContain("Linked artist tags:");
    expect(wrapper.findAll(".upload-artist-tags button").map((b) => b.text())).toEqual(["artist_a", "artist_b"]);
  });

  it("toggles the artist tag in and out of the artist field on click", async () => {
    const { wrapper } = await mountUploader({ verifiedArtistTags: ["artist_a"] });
    await linkedButton(wrapper, "artist_a").trigger("click");
    await nextTick();
    expect(artistField(wrapper).value).toContain("artist_a");

    await linkedButton(wrapper, "artist_a").trigger("click");
    await nextTick();
    expect(artistField(wrapper).value).not.toContain("artist_a");
  });

  it("renders nothing when the user has no linked artists", async () => {
    const { wrapper } = await mountUploader({ verifiedArtistTags: [] });
    expect(wrapper.find(".upload-artist-tags").exists()).toBe(false);
  });

  it("renders nothing in compact mode (no #post_artist to attach to)", async () => {
    const { wrapper } = await mountUploader({ compactMode: true, verifiedArtistTags: ["artist_a"] });
    expect(wrapper.find(".upload-artist-tags").exists()).toBe(false);
  });
});
