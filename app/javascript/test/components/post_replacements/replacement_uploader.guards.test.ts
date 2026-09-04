import { afterEach, describe, expect, it } from "vitest";
import { nextTick } from "vue";
import { VueWrapper } from "@vue/test-utils";
import { mountReplacementUploader, unmountAll } from "./mountReplacementUploader";

afterEach(unmountAll);

const submitButton = (wrapper: VueWrapper) => wrapper.findAll("button").find((b) => b.text().startsWith("Upload"))!;
const sourceWarnings = (wrapper: VueWrapper) => wrapper.findAll(".source_warning").filter((w) => w.isVisible());

async function clickSubmit (wrapper: VueWrapper): Promise<void> {
  await submitButton(wrapper).trigger("click");
  await nextTick();
}

describe("post_replacements/replacement_uploader — guards", () => {
  it("hides the source warnings until the first submit attempt", async () => {
    const { wrapper } = await mountReplacementUploader();
    expect(sourceWarnings(wrapper)).toHaveLength(0);
    expect(submitButton(wrapper).attributes("disabled")).toBeUndefined();
  });

  it("blocks submission with a missing source: warning shown, button disabled, no request", async () => {
    const { wrapper, ajaxSpy } = await mountReplacementUploader();
    await clickSubmit(wrapper);
    expect(ajaxSpy).not.toHaveBeenCalled();
    expect(sourceWarnings(wrapper).some((w) => w.text().includes("A source must be provided"))).toBe(true);
    expect(submitButton(wrapper).attributes("disabled")).toBeDefined();
  });

  it("blocks submission with a non-URL source", async () => {
    const { wrapper, ajaxSpy } = await mountReplacementUploader();
    await wrapper.find(".upload-source-row input").setValue("just some text");
    await clickSubmit(wrapper);
    expect(ajaxSpy).not.toHaveBeenCalled();
    expect(sourceWarnings(wrapper).some((w) => w.text().includes("must be a URL"))).toBe(true);
  });

  it("unblocks when 'no available source' is checked", async () => {
    const { wrapper, ajaxSpy } = await mountReplacementUploader();
    await clickSubmit(wrapper);
    expect(ajaxSpy).not.toHaveBeenCalled();
    await wrapper.find("#no_source").setValue(true);
    await clickSubmit(wrapper);
    expect(ajaxSpy).toHaveBeenCalledTimes(1);
  });

  it("unblocks when a URL-shaped source is entered", async () => {
    const { wrapper, ajaxSpy } = await mountReplacementUploader();
    await wrapper.find(".upload-source-row input").setValue("https://example.com/page");
    await clickSubmit(wrapper);
    expect(ajaxSpy).toHaveBeenCalledTimes(1);
  });

  it("does not require a file, URL, or reason to submit", async () => {
    const { wrapper, ajaxSpy } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    // no upload value, no reason
    await clickSubmit(wrapper);
    expect(ajaxSpy).toHaveBeenCalledTimes(1);
  });

  it("ignores the file-input 'invalid' flag: an invalid file still submits", async () => {
    const { wrapper, ajaxSpy } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    const fileInput = wrapper.findComponent(".uploader-file-input") as VueWrapper;
    fileInput.vm.$emit("change", {
      value: "https://example.com/too_big.png",
      preview: { url: "", isVideo: false },
      invalid: true,
    });
    await nextTick();
    await clickSubmit(wrapper);
    expect(ajaxSpy).toHaveBeenCalledTimes(1);
    const data = (ajaxSpy.mock.calls.at(-1)![1] as any).data as FormData;
    expect(data.get("post_replacement[replacement_url]")).toBe("https://example.com/too_big.png");
  });

  it("blocks re-entry while a submission is in flight", async () => {
    const { wrapper, ajaxSpy } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    await clickSubmit(wrapper);
    await clickSubmit(wrapper);
    expect(ajaxSpy).toHaveBeenCalledTimes(1);
  });

  it("shows no error box before a submission has failed", async () => {
    const { wrapper } = await mountReplacementUploader();
    expect(wrapper.find(".error_message").exists()).toBe(false);
  });
});
