import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { flushPromises, VueWrapper } from "@vue/test-utils";
import { jsonResponse } from "../../helpers";
import { MountReplacementUploaderOptions, mountReplacementUploader, provideUploadValue, unmountAll } from "./mountReplacementUploader";

// submit()'s catch logs via console.error; silence the expected noise.
beforeEach(() => {
  vi.spyOn(console, "error").mockImplementation(() => {});
});
afterEach(unmountAll);

const submitButton = (wrapper: VueWrapper) => wrapper.findAll("button").find((b) => b.text().startsWith("Upload"))!;
const errorMessage = (wrapper: VueWrapper) => wrapper.find(".error_message");
const REASON_STORAGE_KEY = "autocomplete-reason-datalist";

async function fillValidForm (wrapper: VueWrapper): Promise<void> {
  await wrapper.find("#no_source").setValue(true); // suppresses the missing-source warning
  await provideUploadValue(wrapper);
}

async function clickSubmit (wrapper: VueWrapper): Promise<void> {
  await submitButton(wrapper).trigger("click");
  await flushPromises();
}

// Payload capture: submit and return the url/init from the fetch call.
// This is the transport seam (was jQuery.ajax option capture).
async function submitAndCapture (opts: MountReplacementUploaderOptions = {}) {
  const mounted = await mountReplacementUploader(opts);
  await fillValidForm(mounted.wrapper);
  await clickSubmit(mounted.wrapper);
  const call = mounted.fetchSpy.mock.calls.at(-1)!;
  const init = call[1] as RequestInit;
  return { ...mounted, url: call[0] as string, init, data: init.body as FormData };
}

// Outcome: configure what the submit request resolves/rejects to, then submit.
async function submitOutcome (response: any, opts: MountReplacementUploaderOptions = {}) {
  const mounted = await mountReplacementUploader(opts);
  await fillValidForm(mounted.wrapper);
  if (response instanceof Error) mounted.fetchSpy.mockRejectedValue(response);
  else mounted.fetchSpy.mockResolvedValue(response);
  await clickSubmit(mounted.wrapper);
  return mounted;
}

describe("post_replacements/replacement_uploader — submit payload", () => {
  it("POSTs FormData to /post_replacements.json with the post_id from the page URL and a CSRF header", async () => {
    const { url, init, data } = await submitAndCapture({ postId: "4567" });
    expect(url).toBe("/post_replacements.json?post_id=4567");
    expect(init.method).toBe("POST");
    expect(data).toBeInstanceOf(FormData);
    expect("X-CSRF-Token" in (init.headers as object)).toBe(true);
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
    await provideUploadValue(mounted.wrapper, { value: new File(["x"], "art.png", { type: "image/png" }) });
    await clickSubmit(mounted.wrapper);
    const data = (mounted.fetchSpy.mock.calls.at(-1)![1] as RequestInit).body as FormData;
    expect(data.get("post_replacement[replacement_file]")).toBeInstanceOf(File);
    expect(data.get("post_replacement[replacement_url]")).toBeNull();
  });

  it("sends the first source", async () => {
    const mounted = await mountReplacementUploader();
    await provideUploadValue(mounted.wrapper);
    await mounted.wrapper.find(".upload-source-row input").setValue("https://example.com/page");
    await clickSubmit(mounted.wrapper);
    const data = (mounted.fetchSpy.mock.calls.at(-1)![1] as RequestInit).body as FormData;
    expect(data.get("post_replacement[source]")).toBe("https://example.com/page");
  });

  it("sends an empty source when 'no available source' is checked, even with text typed", async () => {
    const mounted = await mountReplacementUploader();
    await provideUploadValue(mounted.wrapper);
    await mounted.wrapper.find(".upload-source-row input").setValue("https://example.com/page");
    await mounted.wrapper.find("#no_source").setValue(true);
    await clickSubmit(mounted.wrapper);
    const data = (mounted.fetchSpy.mock.calls.at(-1)![1] as RequestInit).body as FormData;
    expect(data.get("post_replacement[source]")).toBe("");
  });

  it("sends the reason", async () => {
    const mounted = await mountReplacementUploader();
    await fillValidForm(mounted.wrapper);
    await mounted.wrapper.find("#replacement-reason").setValue("Better quality");
    await clickSubmit(mounted.wrapper);
    const data = (mounted.fetchSpy.mock.calls.at(-1)![1] as RequestInit).body as FormData;
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
    const data = (mounted.fetchSpy.mock.calls.at(-1)![1] as RequestInit).body as FormData;
    expect(data.get("post_replacement[as_pending]")).toBe("true");
  });
});

describe("post_replacements/replacement_uploader — submit outcomes", () => {
  it("navigates to the returned location on success", async () => {
    const { locationAssign } = await submitOutcome(jsonResponse({ location: "/post_replacements?search[post_id]=123" }));
    expect(locationAssign).toHaveBeenCalledWith("/post_replacements?search[post_id]=123");
  });

  it("keeps the submitting state after success (button stays 'Uploading...')", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({ location: "/x" }));
    expect(submitButton(wrapper).text()).toBe("Uploading...");
    expect(submitButton(wrapper).attributes("disabled")).toBeDefined();
  });

  it("persists the reason to the autocomplete datalist storage on success", async () => {
    window.localStorage.removeItem(REASON_STORAGE_KEY);
    const mounted = await mountReplacementUploader();
    await fillValidForm(mounted.wrapper);
    await mounted.wrapper.find("#replacement-reason").setValue("Fixed by the artist");
    await clickSubmit(mounted.wrapper);
    expect(JSON.parse(window.localStorage.getItem(REASON_STORAGE_KEY)!)).toContain("Fixed by the artist");
  });

  it("does not persist the reason when the submission fails", async () => {
    window.localStorage.removeItem(REASON_STORAGE_KEY);
    const mounted = await mountReplacementUploader();
    await fillValidForm(mounted.wrapper);
    await mounted.wrapper.find("#replacement-reason").setValue("Rejected reason");
    mounted.fetchSpy.mockResolvedValue(jsonResponse({ message: "nope" }, { status: 412 }));
    await clickSubmit(mounted.wrapper);
    expect(window.localStorage.getItem(REASON_STORAGE_KEY)).toBeNull();
  });

  it("does not store an empty reason on success", async () => {
    window.localStorage.removeItem(REASON_STORAGE_KEY);
    await submitOutcome(jsonResponse({ location: "/x" })); // reason left blank
    expect(window.localStorage.getItem(REASON_STORAGE_KEY)).toBeNull();
  });

  it("shows the error reason and re-enables the button on failure", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({ reason: "Duplicate of what it is replacing" }, { status: 412 }));
    expect(errorMessage(wrapper).text()).toContain("Duplicate of what it is replacing");
    expect(submitButton(wrapper).text()).toBe("Upload");
    expect(submitButton(wrapper).attributes("disabled")).toBeUndefined();
  });

  it("falls back to the error message when there is no reason", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({ message: "Something broke." }, { status: 412 }));
    expect(errorMessage(wrapper).text()).toContain("Something broke.");
  });

  it("prefers reason over message when both are present", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({ reason: "the reason", message: "the message" }, { status: 412 }));
    expect(errorMessage(wrapper).text()).toContain("the reason");
  });

  it("reports a Cloudflare challenge", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({}, { status: 403, headers: { "cf-mitigated": "challenge" } }));
    expect(errorMessage(wrapper).text()).toContain("security challenge");
    expect(submitButton(wrapper).attributes("disabled")).toBeUndefined();
  });

  it("reports a Cloudflare 403", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({}, { status: 403, headers: { server: "cloudflare" } }));
    expect(errorMessage(wrapper).text()).toContain("Cloudflare (403)");
  });

  it("falls back to a generic message when the error body is not JSON", async () => {
    const broken = {
      ok: false,
      status: 500,
      headers: { get: () => null },
      json: async () => { throw new SyntaxError("Unexpected token"); },
      text: async () => "",
    };
    const { wrapper } = await submitOutcome(broken);
    expect(errorMessage(wrapper).text()).toContain("could not be completed");
    expect(submitButton(wrapper).attributes("disabled")).toBeUndefined();
  });

  it("falls back to a generic message on a network error", async () => {
    const { wrapper } = await submitOutcome(new Error("network down"));
    expect(errorMessage(wrapper).text()).toContain("could not be completed");
    expect(submitButton(wrapper).attributes("disabled")).toBeUndefined();
  });

  it("allows a retry after a failure", async () => {
    const mounted = await submitOutcome(jsonResponse({ reason: "nope" }, { status: 412 }));
    mounted.fetchSpy.mockClear();
    await clickSubmit(mounted.wrapper);
    expect(mounted.fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("clears a stale error while a retry is in flight", async () => {
    const mounted = await submitOutcome(jsonResponse({ reason: "nope" }, { status: 412 }));
    expect(errorMessage(mounted.wrapper).exists()).toBe(true);
    mounted.fetchSpy.mockImplementation(() => new Promise(() => {})); // keep the retry pending
    await clickSubmit(mounted.wrapper);
    expect(errorMessage(mounted.wrapper).exists()).toBe(false);
    expect(submitButton(mounted.wrapper).text()).toBe("Uploading...");
  });
});
