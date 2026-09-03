import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { nextTick } from "vue";
import type { VueWrapper } from "@vue/test-utils";
import { mountUploader, MountUploaderOptions, unmountAll } from "./mountUploader";

afterEach(unmountAll);

// Fill the form so preventUpload clears and submit() reaches the network layer.
async function fillValidForm (wrapper: VueWrapper): Promise<void> {
  await wrapper.find("#post_tags").setValue("a b c d");
  await wrapper.find(".rating-s").trigger("click");
  await wrapper.find("#no_source").setValue(true); // suppresses the missing-source warning
}

// Capture the jQuery.ajax options (payload + success/error callbacks). This tiny
// helper is the ONLY §4-fragile seam: when submit() moves to fetch, only this swaps.
async function submitAndCapture (opts: MountUploaderOptions = {}) {
  const mounted = await mountUploader(opts);
  await fillValidForm(mounted.wrapper);
  await mounted.wrapper.find("button[accesskey='s']").trigger("click");
  const call = mounted.ajax.mock.calls[0];
  expect(call?.[0]).toBe("/uploads.json");
  const options = call[1] as any;
  return { ...mounted, data: options.data as FormData, success: options.success, error: options.error };
}

// jqXHR stand-in for the error branches.
function xhr (init: { headers?: Record<string, string>, status?: number, responseJSON?: any } = {}) {
  const headers = Object.fromEntries(Object.entries(init.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]));
  return {
    status: init.status ?? 500,
    statusText: "",
    responseText: init.responseJSON ? JSON.stringify(init.responseJSON) : "",
    responseJSON: init.responseJSON,
    getResponseHeader: (name: string) => headers[name.toLowerCase()] ?? null,
  };
}

function errorBox (wrapper: VueWrapper, needle: string) {
  return wrapper.findAll(".box-section.background-red").find((b) => b.text().includes(needle));
}

describe("uploads/uploader — submit payload", () => {
  it("sends a direct URL (string upload value) rather than a file", async () => {
    const { data } = await submitAndCapture();
    expect(data.get("upload[direct_url]")).toBe("");
    expect(data.get("upload[file]")).toBeNull();
  });

  it("sends the file when the upload value is a File", async () => {
    const mounted = await mountUploader();
    (mounted.wrapper.vm as any).uploadValue = new File(["x"], "art.png", { type: "image/png" });
    await fillValidForm(mounted.wrapper);
    await mounted.wrapper.find("button[accesskey='s']").trigger("click");
    const data = mounted.ajax.mock.calls[0][1].data as FormData;
    expect(data.get("upload[file]")).toBeInstanceOf(File);
    expect(data.get("upload[direct_url]")).toBeNull();
  });

  it("includes the core fields", async () => {
    const mounted = await mountUploader();
    await mounted.wrapper.find("#post_tags").setValue("a b c d");
    await mounted.wrapper.find(".rating-e").trigger("click");
    await mounted.wrapper.find("#post_description").setValue("a description");
    (mounted.wrapper.vm as any).sources = ["https://example.com/a", "https://example.com/b"];
    (mounted.wrapper.vm as any).parentID = "12345";
    await nextTick();
    await mounted.wrapper.find("button[accesskey='s']").trigger("click");

    const data = mounted.ajax.mock.calls[0][1].data as FormData;
    expect(data.get("upload[tag_string]")).toBe("a b c d");
    expect(data.get("upload[rating]")).toBe("e");
    expect(data.get("upload[source]")).toBe("https://example.com/a\nhttps://example.com/b");
    expect(data.get("upload[description]")).toBe("a description");
    expect(data.get("upload[parent_id]")).toBe("12345");
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

describe("uploads/uploader — submit outcomes", () => {
  it("navigates and toasts on success", async () => {
    const { wrapper, success, locationAssign } = await submitAndCapture();
    const Toast = (await import("@/utility/Toast")).default;
    success({ location: "/posts/999" });
    await nextTick();
    expect(Toast.notice).toHaveBeenCalledWith("Post uploaded successfully.");
    expect(locationAssign).toHaveBeenCalledWith("/posts/999");
    // beforeunload guard released.
    expect((window.onbeforeunload as () => unknown)()).toBeUndefined();
    void wrapper;
  });

  it("reports a Cloudflare challenge", async () => {
    const { wrapper, error } = await submitAndCapture();
    error(xhr({ headers: { "cf-mitigated": "challenge" }, status: 403 }), "error", "");
    await nextTick();
    expect(errorBox(wrapper, "security challenge")?.isVisible()).toBe(true);
  });

  it("reports a Cloudflare 403", async () => {
    const { wrapper, error } = await submitAndCapture();
    error(xhr({ headers: { server: "cloudflare" }, status: 403 }), "error", "");
    await nextTick();
    expect(errorBox(wrapper, "Cloudflare (403)")?.isVisible()).toBe(true);
  });

  it("flags a duplicate with a link to the existing post", async () => {
    const { wrapper, error } = await submitAndCapture();
    error(xhr({ status: 409, responseJSON: { reason: "duplicate", post_id: 42, message: "Already uploaded." } }), "error", "");
    await nextTick();
    expect(wrapper.find("a[href='/posts/42']").exists()).toBe(true);
    expect(errorBox(wrapper, "Already uploaded.")?.isVisible()).toBe(true);
  });

  it("shows the server message for an invalid upload", async () => {
    const { wrapper, error } = await submitAndCapture();
    error(xhr({ status: 422, responseJSON: { reason: "invalid", message: "Bad tags." } }), "error", "");
    await nextTick();
    expect(errorBox(wrapper, "Bad tags.")?.isVisible()).toBe(true);
  });

  it("prefixes a bare message with 'Error:'", async () => {
    const { wrapper, error } = await submitAndCapture();
    error(xhr({ status: 500, responseJSON: { message: "Something broke." } }), "error", "");
    await nextTick();
    expect(errorBox(wrapper, "Error: Something broke.")?.isVisible()).toBe(true);
  });

  it("falls back to reason when there is no message", async () => {
    const { wrapper, error } = await submitAndCapture();
    error(xhr({ status: 500, responseJSON: { reason: "server_error" } }), "error", "");
    await nextTick();
    expect(errorBox(wrapper, "Error: server_error")?.isVisible()).toBe(true);
  });

  it("falls back to textStatus/errorThrown when there is no JSON", async () => {
    const { wrapper, error } = await submitAndCapture();
    error(xhr({ status: 500 }), "timeout", "Timeout");
    await nextTick();
    const box = errorBox(wrapper, "timeout");
    expect(box?.isVisible()).toBe(true);
    expect(box?.text()).toContain("Timeout");
  });
});
