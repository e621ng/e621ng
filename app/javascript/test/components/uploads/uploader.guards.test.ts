import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { nextTick } from "vue";
import type { VueWrapper } from "@vue/test-utils";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

const submitButton = (w: VueWrapper) => w.find("button[accesskey='s']");
const clickSubmit = (w: VueWrapper) => submitButton(w).trigger("click");

describe("uploads/uploader — validation guards", () => {
  it("hides every error box until a submit is attempted (showErrors gating)", async () => {
    const { wrapper } = await mountUploader();
    // background-red boxes exist in the DOM but are v-show:false / v-if absent.
    for (const box of wrapper.findAll(".box-section.background-red"))
      expect(box.isVisible()).toBe(false);
    // The button itself is NOT disabled before a submit attempt.
    expect(submitButton(wrapper).attributes("disabled")).toBeUndefined();
  });

  it("surfaces the requirement boxes and disables submit after a failed attempt", async () => {
    const { wrapper } = await mountUploader();
    await clickSubmit(wrapper);
    expect(wrapper.findAll(".box-section.background-red").some((b) => b.isVisible())).toBe(true);
    expect(submitButton(wrapper).attributes("disabled")).toBeDefined();
  });

  it("counts down the 'more tags' requirement and clears it at four", async () => {
    const { wrapper } = await mountUploader();
    await clickSubmit(wrapper);
    const tagBox = () => wrapper.findAll(".box-section.background-red").find((b) => b.text().includes("more tags"));

    await wrapper.find("#post_tags").setValue("a b");
    expect(tagBox()!.isVisible()).toBe(true);
    expect(tagBox()!.text()).toContain("2");

    await wrapper.find("#post_tags").setValue("a b c d");
    expect(tagBox()?.isVisible() ?? false).toBe(false);
  });

  it("requires a rating", async () => {
    const { wrapper } = await mountUploader();
    await clickSubmit(wrapper);
    const ratingBox = () => wrapper.findAll(".box-section.background-red").find((b) => b.text().includes("appropriate rating"));
    expect(ratingBox()).toBeTruthy();

    await wrapper.find(".rating-s").trigger("click");
    expect(ratingBox()).toBeUndefined();
  });

  it("lets a fully-satisfied form submit (preventUpload clears)", async () => {
    const { wrapper, fetchSpy } = await mountUploader();
    await wrapper.find("#post_tags").setValue("a b c d");
    await wrapper.find(".rating-s").trigger("click");
    await wrapper.find("#no_source").setValue(true); // suppresses the missing-source warning
    (wrapper.vm as any).uploadValue = "https://example.com/image.png"; // an upload must be provided
    await nextTick();
    await clickSubmit(wrapper);
    // Reached the network layer → all guards passed.
    expect(fetchSpy).toHaveBeenCalledWith("/uploads.json", expect.anything());
  });

  describe("beforeunload warning", () => {
    it("does not warn on a pristine form", async () => {
      await mountUploader();
      expect((window.onbeforeunload as () => unknown)()).toBeUndefined();
    });

    it("warns once the form has tags", async () => {
      const { wrapper } = await mountUploader();
      await wrapper.find("#post_tags").setValue("wolf");
      expect((window.onbeforeunload as () => unknown)()).toBe(true);
    });
  });
});
