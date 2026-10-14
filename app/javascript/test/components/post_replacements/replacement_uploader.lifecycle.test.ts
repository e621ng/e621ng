import { vi } from "vitest";

vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { flushPromises, VueWrapper } from "@vue/test-utils";
import { mountReplacementUploader, provideUploadValue, unmountAll } from "./mountReplacementUploader";

afterEach(unmountAll);

const guard = () => window.onbeforeunload as (() => unknown) | null;
const submitButton = (wrapper: VueWrapper) => wrapper.findAll("button").find((b) => b.text().startsWith("Upload"))!;

describe("post_replacements/replacement_uploader — lifecycle", () => {
  it("installs the unload guard on mount and releases it on unmount", async () => {
    const { wrapper } = await mountReplacementUploader();
    expect(typeof guard()).toBe("function");

    wrapper.unmount();
    expect(window.onbeforeunload).toBeNull();
  });

  it("does not warn while the form is pristine", async () => {
    await mountReplacementUploader();
    expect(guard()!()).toBeUndefined();
  });

  it("warns once an upload value is provided", async () => {
    const { wrapper } = await mountReplacementUploader();
    await provideUploadValue(wrapper);
    expect(guard()!()).toBe(true);
  });

  it("warns once a reason is typed", async () => {
    const { wrapper } = await mountReplacementUploader();
    await wrapper.find("#replacement-reason").setValue("Better quality");
    expect(guard()!()).toBe(true);
  });

  it("releases the guard after a successful submit", async () => {
    const { wrapper } = await mountReplacementUploader();
    await wrapper.find("#no_source").setValue(true);
    await provideUploadValue(wrapper);
    expect(guard()!()).toBe(true);

    // Default fetch stub is an ok response — the submit succeeds.
    await submitButton(wrapper).trigger("click");
    await flushPromises();
    expect(guard()!()).toBeUndefined();
  });
});
