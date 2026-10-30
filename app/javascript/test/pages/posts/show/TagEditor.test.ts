import { afterEach, describe, expect, it, vi } from "vitest";

const { app, createApp, getJSON, toast } = vi.hoisted(() => {
  const app = { mount: vi.fn() };
  return {
    app,
    createApp: vi.fn(() => app),
    getJSON: vi.fn(() => Promise.resolve({ upload_tags: ["wolf"], recent_tags: ["fox"] })),
    toast: { alert: vi.fn() },
  };
});

vi.mock("vue", () => ({ createApp }));
vi.mock("@/pages/posts/show/tag_editor.vue", () => ({ default: { name: "TagEditorApp" } }));
vi.mock("@/utility/HTTP", () => ({ default: { getJSON } }));
vi.mock("@/utility/Toast", () => ({ default: toast }));

async function load () {
  document.body.innerHTML = "<div id=\"tag-string-editor\" class=\"pending\" data-tags=\"wolf fox\"></div>";
  const TagEditor = (await import("@/pages/posts/show/TagEditor")).default;
  void TagEditor.instance;
}

const openTab = () => $(document).trigger("danbooru:open-post-edit-tab");
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("TagEditor", () => {
  afterEach(() => {
    $(document).off("danbooru:open-post-edit-tab");
    createApp.mockClear();
    app.mount.mockReset();
    toast.alert.mockClear();
  });

  it("mounts the editor on the first edit-tab open only", async () => {
    await load();
    expect(createApp).not.toHaveBeenCalled();

    openTab();
    openTab();
    await flush();

    expect(createApp).toHaveBeenCalledOnce();
    expect(createApp).toHaveBeenCalledWith({ name: "TagEditorApp" }, { postTags: "wolf fox", uploadTags: ["wolf"], recentTags: ["fox"] });
    expect(app.mount).toHaveBeenCalledWith("#tag-string-editor");
    expect(document.getElementById("tag-string-editor").classList.contains("pending")).toBe(false);
  });

  it("retries on the next open after a failed mount", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    app.mount.mockImplementationOnce(() => { throw new Error("boom"); });
    await load();

    openTab();
    await flush();
    expect(toast.alert).toHaveBeenCalledWith("Failed to load the tag editor. Please try again.");

    openTab();
    await flush();
    expect(createApp).toHaveBeenCalledTimes(2);
  });
});
