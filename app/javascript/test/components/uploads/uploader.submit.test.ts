import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { nextTick } from "vue";
import { DOMWrapper, flushPromises, VueWrapper } from "@vue/test-utils";
import { htmlResponse, jsonResponse } from "../../helpers";
import { mountUploader, MountUploaderOptions, unmountAll } from "./mountUploader";

// submit()'s catch logs via console.error; silence the expected noise.
beforeEach(() => {
  vi.spyOn(console, "error").mockImplementation(() => {});
});
afterEach(unmountAll);

async function fillValidForm (wrapper: VueWrapper): Promise<void> {
  await wrapper.find("#post_tags").setValue("a b c d e f g h i j");
  await wrapper.find(".rating-s").trigger("click");
  await wrapper.find("#no_source").setValue(true); // suppresses the missing-source warning
  (wrapper.vm as any).uploadValue = "https://example.com/image.png"; // an upload must be provided
  await nextTick();
}

async function clickSubmit (wrapper: VueWrapper): Promise<void> {
  await wrapper.find("button[accesskey='s']").trigger("click");
  await flushPromises();
}

// Payload capture: submit and return the FormData/init from the fetch call.
// This is the §4 transport seam (was jQuery.ajax option capture).
async function submitAndCapture (opts: MountUploaderOptions = {}) {
  const mounted = await mountUploader(opts);
  await fillValidForm(mounted.wrapper);
  await clickSubmit(mounted.wrapper);
  const call = mounted.fetchSpy.mock.calls.at(-1)!;
  expect(call[0]).toBe("/uploads.json");
  const init = call[1] as RequestInit;
  return { ...mounted, init, data: init.body as FormData };
}

// Outcome: configure what the upload request resolves/rejects to, then submit.
async function submitOutcome (response: any, opts: MountUploaderOptions = {}) {
  const mounted = await mountUploader(opts);
  await fillValidForm(mounted.wrapper);
  if (response instanceof Error) mounted.fetchSpy.mockRejectedValue(response);
  else mounted.fetchSpy.mockResolvedValue(response);
  await clickSubmit(mounted.wrapper);
  return mounted;
}

const errorBox = (wrapper: VueWrapper, needle: string) => wrapper.findAll(".box-section.background-red").find((b) => b.text().includes(needle));

describe("uploads/uploader — submit payload", () => {
  it("POSTs to /uploads.json with FormData and a CSRF header", async () => {
    const { init } = await submitAndCapture();
    expect(init.method).toBe("POST");
    expect(init.body).toBeInstanceOf(FormData);
    expect("X-CSRF-Token" in (init.headers as object)).toBe(true);
  });

  it("sends a direct URL (string upload value) rather than a file", async () => {
    const { data } = await submitAndCapture();
    expect(data.get("upload[direct_url]")).toBe("https://example.com/image.png");
    expect(data.get("upload[file]")).toBeNull();
  });

  it("blocks submission and warns when no file or URL is provided", async () => {
    const mounted = await mountUploader();
    await mounted.wrapper.find("#post_tags").setValue("a b c d");
    await mounted.wrapper.find(".rating-s").trigger("click");
    await mounted.wrapper.find("#no_source").setValue(true);
    // deliberately no upload value
    mounted.fetchSpy.mockClear();
    await clickSubmit(mounted.wrapper);

    expect(mounted.fetchSpy).not.toHaveBeenCalled();
    expect(errorBox(mounted.wrapper, "provide a file")?.isVisible()).toBe(true);
  });

  it("sends the file when the upload value is a File", async () => {
    const mounted = await mountUploader();
    await fillValidForm(mounted.wrapper);
    (mounted.wrapper.vm as any).uploadValue = new File(["x"], "art.png", { type: "image/png" });
    await nextTick();
    await clickSubmit(mounted.wrapper);
    const data = mounted.fetchSpy.mock.calls.at(-1)![1].body as FormData;
    expect(data.get("upload[file]")).toBeInstanceOf(File);
    expect(data.get("upload[direct_url]")).toBeNull();
  });

  it("includes the core fields", async () => {
    const mounted = await mountUploader();
    await mounted.wrapper.find("#post_tags").setValue("a b c d e f g h i j");
    await mounted.wrapper.find(".rating-e").trigger("click");
    await mounted.wrapper.find("#post_description").setValue("a description");
    (mounted.wrapper.vm as any).sources = ["https://example.com/a", "https://example.com/b"];
    (mounted.wrapper.vm as any).parentID = "12345";
    (mounted.wrapper.vm as any).uploadValue = "https://example.com/image.png";
    await nextTick();
    await clickSubmit(mounted.wrapper);

    const data = mounted.fetchSpy.mock.calls.at(-1)![1].body as FormData;
    expect(data.get("upload[tag_string]")).toBe("a b c d e f g h i j");
    expect(data.get("upload[rating]")).toBe("e");
    expect(data.get("upload[source]")).toBe("https://example.com/a\nhttps://example.com/b");
    expect(data.get("upload[description]")).toBe("a description");
    expect(data.get("upload[parent_id]")).toBe("12345");
  });

  it("omits parent_id when no parent is set", async () => {
    const { data } = await submitAndCapture();
    expect(data.get("upload[parent_id]")).toBeNull();
  });

  it("submits an empty source when 'no available source' is checked", async () => {
    const mounted = await mountUploader();
    (mounted.wrapper.vm as any).sources = ["https://example.com/typed"];
    await nextTick();
    await fillValidForm(mounted.wrapper); // checks #no_source
    await clickSubmit(mounted.wrapper);

    const data = mounted.fetchSpy.mock.calls.at(-1)![1].body as FormData;
    expect(data.get("upload[source]")).toBe("");
  });

  it("omits privileged fields for a regular member", async () => {
    const { data } = await submitAndCapture();
    expect(data.get("upload[locked_tags]")).toBeNull();
    expect(data.get("upload[locked_rating]")).toBeNull();
    expect(data.get("upload[as_pending]")).toBeNull();
  });

  it("includes privileged fields when the user is allowed", async () => {
    const { data } = await submitAndCapture({ admin: true, privileged: true, uploadFree: true });
    expect(data.get("upload[locked_tags]")).not.toBeNull();
    expect(data.get("upload[locked_rating]")).not.toBeNull();
    expect(data.get("upload[as_pending]")).not.toBeNull();
  });
});

describe("uploads/uploader — low-tag confirmation", () => {
  const dialog = () => new DOMWrapper(document.querySelector<HTMLDialogElement>("#upload-tag-confirmation")!);
  const confirm = async () => {
    await dialog().find("button.submit").trigger("click");
    await flushPromises();
  };
  async function prepare (opts: MountUploaderOptions = {}, tags = "a b c d") {
    const mounted = await mountUploader(opts);
    // jsdom doesn't provide showModal() or close(), so supply them for these tests.
    const element = dialog().element;
    element.showModal = vi.fn(() => { element.open = true; });
    element.close = vi.fn(() => {
      if (!element.open) return;
      element.open = false;
      element.dispatchEvent(new Event("close"));
    });
    await fillValidForm(mounted.wrapper);
    await mounted.wrapper.find("#post_tags").setValue(tags);
    mounted.fetchSpy.mockResolvedValue(jsonResponse({ reason: "invalid", message: "Test response." }, { status: 422 }));
    mounted.fetchSpy.mockClear();
    await clickSubmit(mounted.wrapper);
    return mounted;
  }

  it("still uploads when showModal is unavailable", async () => {
    const { wrapper, fetchSpy } = await mountUploader();
    await fillValidForm(wrapper);
    await wrapper.find("#post_tags").setValue("a b c d");
    Object.defineProperty(dialog().element, "showModal", { value: undefined });
    fetchSpy.mockResolvedValue(jsonResponse({ location: "/posts/999" }));
    fetchSpy.mockClear();

    await clickSubmit(wrapper);

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(fetchSpy).toHaveBeenCalledWith("/uploads.json", expect.objectContaining({
      method: "POST",
    }));
    const data = fetchSpy.mock.calls[0][1].body as FormData;
    expect(data.get("upload[tag_string]")).toBe("a b c d");
  });

  it.each([false, true])("requires confirmation in compact mode %s and keeps the upload payload unchanged", async (compactMode) => {
    const { fetchSpy } = await prepare({ compactMode });
    expect(dialog().isVisible()).toBe(true);
    expect(dialog().element.showModal).toHaveBeenCalledTimes(1);
    expect(fetchSpy).not.toHaveBeenCalled();
    await confirm();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [url, init] = fetchSpy.mock.calls[0];
    expect(url).toBe("/uploads.json");
    expect(Array.from((init.body as FormData).entries())).toEqual([
      ["upload[direct_url]", "https://example.com/image.png"],
      ["upload[tag_string]", "a b c d"],
      ["upload[rating]", "s"],
      ["upload[source]", ""],
      ["upload[description]", ""],
    ]);
    expect(dialog().element.open).toBe(false);
  });

  it("requires confirmation at nine tags", async () => {
    const { fetchSpy } = await prepare({}, "a b c d e f g h i");
    expect(dialog().isVisible()).toBe(true);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it.each(["cancel", "close", "escape"])("cancels with %s, restores focus, and requires confirmation again", async (action) => {
    const { wrapper, fetchSpy } = await prepare();
    if (action === "escape") {
      // Simulate pressing Escape: send the cancel event, then close the dialog.
      const event = new Event("cancel", { cancelable: true });
      if (dialog().element.dispatchEvent(event)) {
        dialog().element.close();
      }
      await nextTick();
    } else {
      const button = action === "close" ? ".close-dialog" : ".dialog-actions button:not(.submit)";
      await dialog().find(button).trigger("click");
    }
    expect(dialog().element.open).toBe(false);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(document.activeElement).toBe(wrapper.find('button[accesskey="s"]').element);
    await clickSubmit(wrapper);
    expect(dialog().isVisible()).toBe(true);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("reuses the dialog and submits only once on repeated clicks", async () => {
    const { wrapper, fetchSpy } = await prepare();
    await clickSubmit(wrapper);
    expect(document.querySelectorAll("#upload-tag-confirmation")).toHaveLength(1);
    expect(dialog().element.showModal).toHaveBeenCalledTimes(1);
    fetchSpy.mockReturnValue(new Promise(() => {}));
    await confirm();
    await confirm();
    await clickSubmit(wrapper);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("asks again if the tags changed while the dialog was open", async () => {
    const { wrapper, fetchSpy } = await prepare();
    await wrapper.find("#post_tags").setValue("a b c e");
    await confirm();
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(dialog().isVisible()).toBe(true);
    await confirm();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect((fetchSpy.mock.calls[0][1].body as FormData).get("upload[tag_string]")).toBe("a b c e");
  });

  it("rechecks the hard minimum and other validation on confirmation", async () => {
    const { wrapper, fetchSpy } = await prepare();
    await wrapper.find("#post_tags").setValue("a b c");
    await confirm();
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(dialog().element.open).toBe(false);
    await wrapper.find("#post_tags").setValue("a b c d");
    await clickSubmit(wrapper);
    (wrapper.vm as any).uploadValue = "";
    await nextTick();
    await confirm();
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(errorBox(wrapper, "provide a file")?.isVisible()).toBe(true);
  });

  it("requires a fresh confirmation after a failed upload", async () => {
    const { wrapper, fetchSpy } = await prepare();
    await confirm();
    expect(errorBox(wrapper, "Test response.")?.isVisible()).toBe(true);
    await clickSubmit(wrapper);
    expect(dialog().isVisible()).toBe(true);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    await confirm();
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });

  it("uses the normal success redirect and releases the unload guard after confirmation", async () => {
    const { fetchSpy, locationAssign } = await prepare();
    fetchSpy.mockResolvedValue(jsonResponse({ location: "/posts/999" }));
    await confirm();
    expect(locationAssign).toHaveBeenCalledWith("/posts/999");
    const unload = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(unload);
    expect(unload.defaultPrevented).toBe(false);
  });

  it("opens the guide and examples separately and removes the dialog on unmount", async () => {
    const { wrapper } = await prepare();
    const links = [wrapper.find(".box-section.background-yellow a"), ...dialog().findAll("a")];
    for (const link of links) {
      expect(link.attributes("target")).toBe("_blank");
      expect(link.attributes("rel")).toBe("noopener");
    }
    wrapper.unmount();
    expect(document.querySelector("#upload-tag-confirmation")).toBeNull();
  });
});

describe("uploads/uploader — submit outcomes", () => {
  it("navigates and toasts on success", async () => {
    const { locationAssign } = await submitOutcome(jsonResponse({ location: "/posts/999" }));
    const Toast = (await import("@/utility/Toast")).default;
    expect(Toast.notice).toHaveBeenCalledWith("Post uploaded successfully.");
    expect(locationAssign).toHaveBeenCalledWith("/posts/999");
    // Guard released (allowNavigate): a beforeunload after success isn't prevented.
    const unload = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(unload);
    expect(unload.defaultPrevented).toBe(false);
  });

  it("reports a Cloudflare challenge", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({}, { status: 403, headers: { "cf-mitigated": "challenge" } }));
    expect(errorBox(wrapper, "security challenge")?.isVisible()).toBe(true);
  });

  it("reports a Cloudflare 403 (non-JSON block page)", async () => {
    const { wrapper } = await submitOutcome(htmlResponse(403, { headers: { server: "cloudflare" } }));
    expect(errorBox(wrapper, "Cloudflare (403)")?.isVisible()).toBe(true);
  });

  it("shows the origin's message for a JSON 403, not the Cloudflare one", async () => {
    // Behind CF, origin 403s (privilege/lockdown errors) also carry the CF
    // headers — the JSON body is what identifies them as origin responses.
    const { wrapper } = await submitOutcome(
      jsonResponse({ reason: "Access Denied: not allowed" }, { status: 403, headers: { "server": "cloudflare", "cf-ray": "abc123" } }),
    );
    expect(errorBox(wrapper, "Access Denied: not allowed")?.isVisible()).toBe(true);
    expect(errorBox(wrapper, "Cloudflare (403)")).toBeUndefined();
  });

  it("flags a duplicate with a link to the existing post", async () => {
    const { wrapper } = await submitOutcome(
      jsonResponse({ reason: "duplicate", post_id: 42, message: "Already uploaded." }, { status: 409 }),
    );
    expect(wrapper.find("a[href='/posts/42']").exists()).toBe(true);
    expect(errorBox(wrapper, "Already uploaded.")?.isVisible()).toBe(true);
  });

  it("clears a stale duplicate banner on the next submit", async () => {
    const mounted = await mountUploader();
    await fillValidForm(mounted.wrapper);
    const dupBanner = () => mounted.wrapper.findAll(".box-section.background-red").find((b) => b.text().includes("is a duplicate of"));

    mounted.fetchSpy.mockResolvedValueOnce(jsonResponse({ reason: "duplicate", post_id: 42, message: "Already uploaded." }, { status: 409 }));
    await clickSubmit(mounted.wrapper);
    expect(dupBanner()?.isVisible()).toBe(true);

    // A subsequent non-duplicate failure must clear the duplicate banner.
    mounted.fetchSpy.mockResolvedValueOnce(jsonResponse({ reason: "invalid", message: "Bad tags." }, { status: 422 }));
    await clickSubmit(mounted.wrapper);
    expect(dupBanner()?.isVisible()).toBe(false);
  });

  it("shows the server message for an invalid upload", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({ reason: "invalid", message: "Bad tags." }, { status: 422 }));
    expect(errorBox(wrapper, "Bad tags.")?.isVisible()).toBe(true);
  });

  it("prefixes a bare message with 'Error:'", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({ message: "Something broke." }, { status: 500 }));
    expect(errorBox(wrapper, "Error: Something broke.")?.isVisible()).toBe(true);
  });

  it("falls back to reason when there is no message", async () => {
    const { wrapper } = await submitOutcome(jsonResponse({ reason: "server_error" }, { status: 500 }));
    expect(errorBox(wrapper, "Error: server_error")?.isVisible()).toBe(true);
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
    expect(errorBox(wrapper, "could not be completed")?.isVisible()).toBe(true);
  });

  it("falls back to a generic message on a network error", async () => {
    const { wrapper } = await submitOutcome(new Error("network down"));
    expect(errorBox(wrapper, "could not be completed")?.isVisible()).toBe(true);
  });
});
