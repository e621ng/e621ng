import { afterEach, describe, expect, it } from "vitest";
import { mount, VueWrapper } from "@vue/test-utils";
import FilePreview from "@/components/uploads/file_preview.vue";

const wrappers: VueWrapper[] = [];
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
});

function make (data: { url: string, isVideo: boolean }) {
  const wrapper = mount(FilePreview, { props: { classes: "", data }, attachTo: document.body });
  wrappers.push(wrapper);
  return wrapper;
}

// jsdom never decodes media, so stub the natural dimensions then fire the load event.
async function loadImage (w: VueWrapper, width: number, height: number) {
  const img = w.find("img").element as HTMLImageElement;
  Object.defineProperty(img, "naturalWidth", { value: width, configurable: true });
  Object.defineProperty(img, "naturalHeight", { value: height, configurable: true });
  await w.find("img").trigger("load");
}

const THUMB_NONE = "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==";

describe("uploads/file_preview", () => {
  it("shows the placeholder thumbnail when there is no url", () => {
    const w = make({ url: "", isVideo: false });
    expect(w.find("img").attributes("src")).toBe(THUMB_NONE);
    expect(w.find(".upload_preview_dims").text()).toBe("");
  });

  it("reports dimensions once the image loads", async () => {
    const w = make({ url: "http://example.com/a.png", isVideo: false });
    await loadImage(w, 800, 600);
    expect(w.find(".upload_preview_dims").text()).toBe("800×600");
    expect(w.find(".background-red").isVisible()).toBe(false);
  });

  it("warns when a dimension exceeds 15000px", async () => {
    const w = make({ url: "http://example.com/huge.png", isVideo: false });
    await loadImage(w, 16000, 100);
    expect(w.find(".background-red").isVisible()).toBe(true);
    expect(w.find(".background-red").text()).toContain("15,000px");
  });

  it("resets dimensions when the source changes", async () => {
    const w = make({ url: "http://example.com/a.png", isVideo: false });
    await loadImage(w, 800, 600);
    await w.setProps({ data: { url: "http://example.com/b.png", isVideo: false } });
    expect(w.find(".upload_preview_dims").text()).toBe("");
  });

  it("retries through the preview proxy when the direct load fails", async () => {
    const url = "https://i.pximg.net/img-original/img/a b.png";
    const w = make({ url, isVideo: false });
    await w.find("img").trigger("error");
    expect(w.find(".preview-fail").exists()).toBe(false);
    expect(w.find("img").attributes("src")).toBe("/uploads/preview?url=" + encodeURIComponent(url));
  });

  it("shows the failure notice when the proxied preview also errors", async () => {
    const w = make({ url: "http://example.com/broken.png", isVideo: false });
    await w.find("img").trigger("error");
    await w.find("img").trigger("error");
    expect(w.find(".preview-fail").exists()).toBe(true);
    expect(w.find("img").exists()).toBe(false);
  });

  it("does not proxy local file previews", async () => {
    const w = make({ url: "blob:http://localhost/abc", isVideo: false });
    await w.find("img").trigger("error");
    expect(w.find(".preview-fail").exists()).toBe(true);
  });

  it("does not proxy videos", async () => {
    const w = make({ url: "http://example.com/a.webm", isVideo: true });
    await w.find("video").trigger("error");
    expect(w.find(".preview-fail").exists()).toBe(true);
  });

  it("goes back to the direct url when the source changes", async () => {
    const w = make({ url: "http://example.com/a.png", isVideo: false });
    await w.find("img").trigger("error");
    await w.setProps({ data: { url: "http://example.com/b.png", isVideo: false } });
    expect(w.find("img").attributes("src")).toBe("http://example.com/b.png");
  });

  it("renders a video element for video data", () => {
    const w = make({ url: "http://example.com/a.webm", isVideo: true });
    expect(w.find("video").exists()).toBe(true);
    expect(w.find("img").exists()).toBe(false);
  });
});
