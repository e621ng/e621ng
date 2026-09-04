import { afterEach, describe, expect, it } from "vitest";
import { flushPromises, VueWrapper } from "@vue/test-utils";
import { mountReplacementUploader, provideUploadValue, unmountAll } from "./mountReplacementUploader";

afterEach(unmountAll);

const submitButton = (wrapper: VueWrapper) => wrapper.findAll("button").find((b) => b.text().startsWith("Upload"))!;
const sourceWarnings = (wrapper: VueWrapper) => wrapper.findAll(".source_warning").filter((w) => w.isVisible());

async function clickSubmit (wrapper: VueWrapper): Promise<void> {
  await submitButton(wrapper).trigger("click");
  await flushPromises();
}
describe("post_replacements/replacement_uploader — guards", () => {
  it("hides the source warnings until the first submit attempt", async () => {
    const { wrapper } = await mountReplacementUploader();
    expect(sourceWarnings(wrapper)).toHaveLength(0);
    expect(submitButton(wrapper).attributes("disabled")).toBeUndefined();
  });

  it("blocks submission with a missing source: warning shown, button disabled, no request", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await clickSubmit(wrapper);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(sourceWarnings(wrapper).some((w) => w.text().includes("A source must be provided"))).toBe(true);
    expect(submitButton(wrapper).attributes("disabled")).toBeDefined();
  });

  it("blocks submission with a non-URL source", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await wrapper.find(".upload-source-row input").setValue("just some text");
    await clickSubmit(wrapper);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(sourceWarnings(wrapper).some((w) => w.text().includes("must be a URL"))).toBe(true);
  });

  it("unblocks when 'no available source' is checked", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await provideUploadValue(wrapper);
    await clickSubmit(wrapper);
    expect(fetchSpy).not.toHaveBeenCalled();
    await wrapper.find("#no_source").setValue(true);
    await clickSubmit(wrapper);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("unblocks when a URL-shaped source is entered", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await provideUploadValue(wrapper);
    await wrapper.find(".upload-source-row input").setValue("https://example.com/page");
    await clickSubmit(wrapper);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("does not require a reason to submit", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    await provideUploadValue(wrapper);
    // no reason
    await clickSubmit(wrapper);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("blocks submission when no file or URL is provided: warning shown, no request", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    await clickSubmit(wrapper);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain("You must provide a file or a URL");
    expect(submitButton(wrapper).attributes("disabled")).toBeDefined();
  });

  it("blocks submission when the file input reports an invalid value", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    await provideUploadValue(wrapper, { invalid: true });
    await clickSubmit(wrapper);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(submitButton(wrapper).attributes("disabled")).toBeDefined();
  });

  it("unblocks when the file input reports a valid value again", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    await provideUploadValue(wrapper, { invalid: true });
    await clickSubmit(wrapper);
    expect(fetchSpy).not.toHaveBeenCalled();
    await provideUploadValue(wrapper);
    await clickSubmit(wrapper);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("blocks re-entry while a submission is in flight", async () => {
    const { wrapper, fetchSpy } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    await provideUploadValue(wrapper);
    fetchSpy.mockImplementation(() => new Promise(() => {})); // keep the first submit in flight
    await clickSubmit(wrapper);
    await clickSubmit(wrapper);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("shows no error box before a submission has failed", async () => {
    const { wrapper } = await mountReplacementUploader();
    expect(wrapper.find(".error_message").exists()).toBe(false);
  });
});
