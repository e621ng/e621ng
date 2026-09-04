import { afterEach, describe, expect, it } from "vitest";
import { VueWrapper } from "@vue/test-utils";
import { mountReplacementUploader, unmountAll } from "./mountReplacementUploader";

afterEach(unmountAll);

const sourceInput = (wrapper: VueWrapper) => wrapper.find(".upload-source-row input");

describe("post_replacements/replacement_uploader — mount", () => {
  it("renders the file input, a single source row, and the reason field", async () => {
    const { wrapper } = await mountReplacementUploader();
    expect(wrapper.find(".uploader-file-input").exists()).toBe(true);
    expect(wrapper.findAll(".upload-source-row")).toHaveLength(1);
    expect(wrapper.find("#replacement-reason").exists()).toBe(true);
    // maxSources=1 — no add-another-source button
    expect(wrapper.find(".upload-source-add").exists()).toBe(false);
  });

  it("starts with an empty source and reason", async () => {
    const { wrapper } = await mountReplacementUploader();
    expect((sourceInput(wrapper).element as HTMLInputElement).value).toBe("");
    expect((wrapper.find("#replacement-reason").element as HTMLInputElement).value).toBe("");
  });

  it("prefills the source from ?additional_source=", async () => {
    const { wrapper } = await mountReplacementUploader({ params: { additional_source: "https://example.com/page" } });
    expect((sourceInput(wrapper).element as HTMLInputElement).value).toBe("https://example.com/page");
  });

  it("prefills the reason from ?reason=", async () => {
    const { wrapper } = await mountReplacementUploader({ params: { reason: "Corrupted upload" } });
    expect((wrapper.find("#replacement-reason").element as HTMLInputElement).value).toBe("Corrupted upload");
  });

  it("hides the as-pending checkbox from non-approvers", async () => {
    const { wrapper } = await mountReplacementUploader();
    expect(wrapper.find("#as_pending").exists()).toBe(false);
  });

  it("shows the as-pending checkbox to approvers, unchecked", async () => {
    const { wrapper } = await mountReplacementUploader({ approver: true });
    const checkbox = wrapper.find("#as_pending");
    expect(checkbox.exists()).toBe(true);
    expect((checkbox.element as HTMLInputElement).checked).toBe(false);
  });
});
