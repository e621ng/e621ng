import { mount, VueWrapper } from "@vue/test-utils";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse } from "../helpers";

import UploadStatus, { type UploadJson } from "@/pages/uploads/show/upload_status.vue";

function uploadJson (overrides: Partial<UploadJson> = {}): UploadJson {
  return {
    id: 5,
    status: "processing",
    processing_step: "thumbnail",
    post_id: null,
    error_message: null,
    warning_messages: [],
    duplicate_post_id: null,
    ...overrides,
  };
}

describe("uploads/show — UploadStatus", () => {
  let fetchSpy: ReturnType<typeof vi.spyOn>;
  let locationAssign: ReturnType<typeof vi.fn>;
  let originalLocation: Location;
  const wrappers: VueWrapper[] = [];

  function mountStatus (initial: UploadJson, fileExt = "jpg"): VueWrapper {
    const wrapper = mount(UploadStatus, {
      props: { uploadId: 5, fileExt, retryUrl: "/uploads/new?tags=foo", initial },
      attachTo: document.body,
    });
    wrappers.push(wrapper);
    return wrapper;
  }

  beforeEach(() => {
    vi.useFakeTimers();
    originalLocation = window.location;
    locationAssign = vi.fn();
    const fakeLocation: any = new URL("http://localhost/uploads/5");
    fakeLocation.assign = locationAssign;
    Object.defineProperty(window, "location", { configurable: true, writable: true, value: fakeLocation });
    fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(uploadJson()));
  });

  afterEach(() => {
    for (const wrapper of wrappers.splice(0)) wrapper.unmount();
    Object.defineProperty(window, "location", { configurable: true, writable: true, value: originalLocation });
    vi.useRealTimers();
  });

  it("renders the checklist with the active step and no audio step for images", () => {
    const wrapper = mountStatus(uploadJson());
    const items = wrapper.findAll("ol.steps li");
    expect(items.map((item) => item.text())).toEqual(["Checking the file", "Generating previews", "Creating the post"]);
    expect(items[0].classes()).toContain("done");
    expect(items[1].classes()).toContain("active");
    expect(items[2].classes()).toContain("pending");
  });

  it("includes the audio step for videos", () => {
    const wrapper = mountStatus(uploadJson(), "mp4");
    expect(wrapper.findAll("ol.steps li").map((item) => item.text())).toContain("Detecting audio");
  });

  it("polls every second at first, then every three seconds", async () => {
    mountStatus(uploadJson());
    await vi.advanceTimersByTimeAsync(1000);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(String(fetchSpy.mock.calls[0][0])).toContain("/uploads/5.json");
    await vi.advanceTimersByTimeAsync(9000);
    expect(fetchSpy).toHaveBeenCalledTimes(10);
    await vi.advanceTimersByTimeAsync(3000);
    expect(fetchSpy).toHaveBeenCalledTimes(11);
  });

  it("navigates to the post once the upload completes", async () => {
    fetchSpy.mockResolvedValue(jsonResponse(uploadJson({ status: "completed", post_id: 42, processing_step: null })));
    const wrapper = mountStatus(uploadJson());
    await vi.advanceTimersByTimeAsync(1000);
    expect(locationAssign).toHaveBeenCalledWith("/posts/42");
    expect(wrapper.text()).toContain("Post created");
    await vi.advanceTimersByTimeAsync(5000);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("stops polling and offers the prefilled form when processing failed", async () => {
    fetchSpy.mockResolvedValue(jsonResponse(uploadJson({ status: "failed", error_message: "file is corrupt", processing_step: null })));
    const wrapper = mountStatus(uploadJson());
    await vi.advanceTimersByTimeAsync(1000);
    expect(wrapper.text()).toContain("file is corrupt");
    expect(wrapper.find("a[href='/uploads/new?tags=foo']").exists()).toBe(true);
    await vi.advanceTimersByTimeAsync(5000);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(locationAssign).not.toHaveBeenCalled();
  });

  it("links to the existing post for duplicates", () => {
    const wrapper = mountStatus(uploadJson({ status: "duplicate: 7", duplicate_post_id: 7 }));
    expect(wrapper.find("a[href='/posts/7']").exists()).toBe(true);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("shows the recorded warnings", () => {
    const wrapper = mountStatus(uploadJson({ warning_messages: ["Tag does not exist"] }));
    expect(wrapper.find(".background-yellow").text()).toContain("Tag does not exist");
  });

  it("reports a lost connection after repeated failures and keeps trying", async () => {
    fetchSpy.mockRejectedValue(new Error("network"));
    const wrapper = mountStatus(uploadJson());
    await vi.advanceTimersByTimeAsync(2000);
    expect(wrapper.text()).not.toContain("Connection lost");
    await vi.advanceTimersByTimeAsync(1000);
    expect(wrapper.text()).toContain("Connection lost");
    await vi.advanceTimersByTimeAsync(1000);
    expect(fetchSpy).toHaveBeenCalledTimes(4);
  });

  it("defers polling while the tab is hidden", async () => {
    Object.defineProperty(document, "hidden", { configurable: true, get: () => true });
    mountStatus(uploadJson());
    await vi.advanceTimersByTimeAsync(5000);
    expect(fetchSpy).not.toHaveBeenCalled();
    Object.defineProperty(document, "hidden", { configurable: true, get: () => false });
    document.dispatchEvent(new Event("visibilitychange"));
    await vi.advanceTimersByTimeAsync(0);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });
});
