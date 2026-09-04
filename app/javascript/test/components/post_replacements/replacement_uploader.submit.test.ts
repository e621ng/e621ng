import { afterEach, describe, expect, it } from "vitest";
import { nextTick } from "vue";
import { VueWrapper } from "@vue/test-utils";
import { MountReplacementUploaderOptions, mountReplacementUploader, unmountAll } from "./mountReplacementUploader";

afterEach(unmountAll);

const submitButton = (wrapper: VueWrapper) => wrapper.findAll("button").find((b) => b.text().startsWith("Upload"))!;

async function fillValidForm (wrapper: VueWrapper): Promise<void> {
  await wrapper.find("#no_source").setValue(true); // suppresses the missing-source warning
  (wrapper.vm as any).uploadValue = "https://example.com/image.png";
  await nextTick();
}

async function clickSubmit (wrapper: VueWrapper): Promise<void> {
  await submitButton(wrapper).trigger("click");
  await nextTick();
}

// Payload capture: submit and return the url/settings from the $.ajax call.
async function submitAndCapture (opts: MountReplacementUploaderOptions = {}) {
  const mounted = await mountReplacementUploader(opts);
  await fillValidForm(mounted.wrapper);
  await clickSubmit(mounted.wrapper);
  const call = mounted.ajaxSpy.mock.calls.at(-1)!;
  const settings = call[1] as any;
  return { ...mounted, url: call[0] as string, settings, data: settings.data as FormData };
}

// Outcome: submit, then drive the captured success/error callback by hand
// ($.ajax is stubbed inert; the component only ever sees these callbacks).
async function submitOutcome (kind: "success" | "error", payload: any, opts: MountReplacementUploaderOptions = {}) {
  const mounted = await submitAndCapture(opts);
  mounted.settings[kind](payload);
  await nextTick();
  return mounted;
}

describe("post_replacements/replacement_uploader — submit payload", () => {
  it("POSTs FormData to /post_replacements.json with the post_id from the page URL", async () => {
    const { url, settings, data } = await submitAndCapture({ postId: "4567" });
    expect(url).toBe("/post_replacements.json?post_id=4567");
    expect(settings.method).toBe("POST");
    expect(settings.processData).toBe(false);
    expect(settings.contentType).toBe(false);
    expect(data).toBeInstanceOf(FormData);
  });

  it("sends a literal 'null' post_id when the page URL has none", async () => {
    const { url } = await submitAndCapture({ postId: null });
    expect(url).toBe("/post_replacements.json?post_id=null");
  });

  it("sends a direct URL (string upload value) rather than a file", async () => {
    const { data } = await submitAndCapture();
    expect(data.get("post_replacement[replacement_url]")).toBe("https://example.com/image.png");
    expect(data.get("post_replacement[replacement_file]")).toBeNull();
  });

  it("sends the file when the upload value is a File", async () => {
    const mounted = await mountReplacementUploader();
    await fillValidForm(mounted.wrapper);
    (mounted.wrapper.vm as any).uploadValue = new File(["x"], "art.png", { type: "image/png" });
    await nextTick();
    await clickSubmit(mounted.wrapper);
    const data = (mounted.ajaxSpy.mock.calls.at(-1)![1] as any).data as FormData;
    expect(data.get("post_replacement[replacement_file]")).toBeInstanceOf(File);
    expect(data.get("post_replacement[replacement_url]")).toBeNull();
  });

  it("still submits an empty replacement_url when no file or URL was provided", async () => {
    const mounted = await mountReplacementUploader();
    await mounted.wrapper.find("#no_source").setValue(true);
    // deliberately no upload value
    await clickSubmit(mounted.wrapper);
    const data = (mounted.ajaxSpy.mock.calls.at(-1)![1] as any).data as FormData;
    expect(data.get("post_replacement[replacement_url]")).toBe("");
  });

  it("sends the first source", async () => {
    const mounted = await mountReplacementUploader();
    await mounted.wrapper.find(".upload-source-row input").setValue("https://example.com/page");
    await clickSubmit(mounted.wrapper);
    const data = (mounted.ajaxSpy.mock.calls.at(-1)![1] as any).data as FormData;
    expect(data.get("post_replacement[source]")).toBe("https://example.com/page");
  });

  it("sends an empty source when 'no available source' is checked, even with text typed", async () => {
    const mounted = await mountReplacementUploader();
    await mounted.wrapper.find(".upload-source-row input").setValue("https://example.com/page");
    await mounted.wrapper.find("#no_source").setValue(true);
    await clickSubmit(mounted.wrapper);
    const data = (mounted.ajaxSpy.mock.calls.at(-1)![1] as any).data as FormData;
    expect(data.get("post_replacement[source]")).toBe("");
  });

  it("sends the reason", async () => {
    const mounted = await mountReplacementUploader();
    await fillValidForm(mounted.wrapper);
    await mounted.wrapper.find("#replacement-reason").setValue("Better quality");
    await clickSubmit(mounted.wrapper);
    const data = (mounted.ajaxSpy.mock.calls.at(-1)![1] as any).data as FormData;
    expect(data.get("post_replacement[reason]")).toBe("Better quality");
  });

  it("always sends as_pending — 'false' for a plain member", async () => {
    const { data } = await submitAndCapture();
    expect(data.get("post_replacement[as_pending]")).toBe("false");
  });

  it("sends as_pending=true when an approver checks the box", async () => {
    const mounted = await mountReplacementUploader({ approver: true });
    await fillValidForm(mounted.wrapper);
    await mounted.wrapper.find("#as_pending").setValue(true);
    await clickSubmit(mounted.wrapper);
    const data = (mounted.ajaxSpy.mock.calls.at(-1)![1] as any).data as FormData;
    expect(data.get("post_replacement[as_pending]")).toBe("true");
  });

  it("persists the submitted reason to the autocomplete datalist storage", async () => {
    const mounted = await mountReplacementUploader();
    await fillValidForm(mounted.wrapper);
    await mounted.wrapper.find("#replacement-reason").setValue("Fixed by the artist");
    await clickSubmit(mounted.wrapper);
    // submittedReason is set at submit time (before any response) and flows into
    // autocompletable-input's addToList watcher.
    expect(JSON.parse(window.localStorage.getItem("autocomplete-reason-datalist")!)).toContain("Fixed by the artist");
  });
});

describe("post_replacements/replacement_uploader — submit outcomes", () => {
  it("navigates to the returned location on success", async () => {
    const { locationAssign } = await submitOutcome("success", { location: "/post_replacements?search[post_id]=123" });
    expect(locationAssign).toHaveBeenCalledWith("/post_replacements?search[post_id]=123");
  });

  it("keeps the submitting state after success (button stays 'Uploading...')", async () => {
    const { wrapper } = await submitOutcome("success", { location: "/x" });
    expect(submitButton(wrapper).text()).toBe("Uploading...");
    expect(submitButton(wrapper).attributes("disabled")).toBeDefined();
  });

  it("shows the error reason and re-enables the button on failure", async () => {
    const { wrapper } = await submitOutcome("error", { responseJSON: { reason: "Duplicate of what it is replacing" } });
    expect(wrapper.find(".error_message").text()).toContain("Duplicate of what it is replacing");
    expect(submitButton(wrapper).text()).toBe("Upload");
    expect(submitButton(wrapper).attributes("disabled")).toBeUndefined();
  });

  it("falls back to the error message when there is no reason", async () => {
    const { wrapper } = await submitOutcome("error", { responseJSON: { message: "Something broke." } });
    expect(wrapper.find(".error_message").text()).toContain("Something broke.");
  });

  it("prefers reason over message when both are present", async () => {
    const { wrapper } = await submitOutcome("error", { responseJSON: { reason: "the reason", message: "the message" } });
    expect(wrapper.find(".error_message").text()).toContain("the reason");
  });

  it("allows a retry after a failure", async () => {
    const mounted = await submitOutcome("error", { responseJSON: { reason: "nope" } });
    mounted.ajaxSpy.mockClear();
    await clickSubmit(mounted.wrapper);
    expect(mounted.ajaxSpy).toHaveBeenCalledTimes(1);
  });
});
