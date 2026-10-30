import { beforeEach, describe, expect, it, vi } from "vitest";

const bulk = {
  update: vi.fn(), favorite: vi.fn(), unfavorite: vi.fn(), vote: vi.fn(), delete: vi.fn(),
  undelete: vi.fn(), unflag: vi.fn(), approve: vi.fn(), applyTagDiff: vi.fn(), syncThumbnail: vi.fn(),
};
const postSet = { add_post: vi.fn(), remove_post: vi.fn(), populateSelect: vi.fn() };
const hotkeys = { enabled: true, listeners: new Map<string, () => void>(), register (name: string, listener: () => void) { this.listeners.set(name, listener); } };
const user = { is: { privileged: true } };
const toast = { alert: vi.fn(), notice: vi.fn(), create: vi.fn(() => ({ dismiss: vi.fn() })) };

vi.mock("@/pages/posts/BulkActions", () => ({ default: bulk }));
vi.mock("@/models/PostSet", () => ({ default: postSet }));
vi.mock("@/core/hotkeys", () => ({ default: hotkeys }));
vi.mock("@/models/CurrentUser", () => ({ default: user }));
vi.mock("@/utility/Toast", async (importOriginal) => ({ ...await importOriginal<object>(), default: toast }));

const POST_ID = 5;
const MODES = ["view", "edit", "add-fav", "remove-fav", "add-to-set", "remove-from-set", "vote-up", "vote-down", "rating-s", "rating-q", "rating-e", "tag-script", "remove-parent", "lock-rating", "lock-note", "approve", "delete", "undelete", "unflag"];

function render ({ modes = MODES } = {}) {
  document.body.innerHTML = `
    <div id="page">
      <select id="mode-box-mode">${modes.map((mode) => `<option value="${mode}">${mode}</option>`).join("")}</select>
      <select id="set-id" style="display: none;"><option value="12">Set</option></select>
      <div id="tag-script-ui" style="display: none;">
        <input id="tag-script-field">
        <button id="tag-script-all">All</button>
        <input id="tag-script-reason" value="why">
      </div>
      <input id="quick-mode-reason" value="dupe" style="display: none;">
      <div id="quick-edit-div" inert>
        <form id="quick-edit-form"><textarea id="post_tag_string"></textarea></form>
      </div>
      <div id="posts">
        <article class="thumbnail" data-id="${POST_ID}" data-rating="s" data-tags="wolf" data-flags="">
          <a class="thm-link" href="/posts/${POST_ID}"><img></a>
        </article>
      </div>
    </div>`;
}

async function load () {
  const PostModeMenu = (await import("@/pages/posts/index/PostModeMenu")).default;
  const QuickEdit = (await import("@/pages/posts/index/QuickEdit")).default;
  const SStorage = (await import("@/utility/storage/Session")).default;
  const LStorage = (await import("@/utility/storage/Local")).default;
  return { PostModeMenu: PostModeMenu.instance, QuickEdit: QuickEdit.instance, SStorage, LStorage };
}

function selectMode (mode: string) {
  const select = document.querySelector<HTMLSelectElement>("#mode-box-mode");
  select.value = mode;
  select.dispatchEvent(new Event("change"));
}

/** Clicks the thumbnail image; returns whether the default action was prevented */
function clickThumbnail (init: MouseEventInit = {}): boolean {
  const event = new MouseEvent("click", { bubbles: true, cancelable: true, ...init });
  document.querySelector(".thm-link img").dispatchEvent(event);
  return event.defaultPrevented;
}

const visible = (selector: string) => document.querySelector<HTMLElement>(selector).style.display !== "none";

describe("PostModeMenu", () => {
  beforeEach(() => {
    render();
    for (const fn of [...Object.values(bulk), ...Object.values(postSet)]) fn.mockReset();
    hotkeys.listeners.clear();
    hotkeys.enabled = true;
    user.is.privileged = true;
    toast.create.mockClear();
  });

  describe("initialization", () => {
    it("restores the stored mode quietly", async () => {
      sessionStorage.setItem("e6.posts.mode", "tag-script");
      const { PostModeMenu } = await load();

      expect(PostModeMenu.mode).toBe("tag-script");
      expect(document.getElementById("page").dataset.modeMenu).toBe("tag-script");
      expect(visible("#tag-script-ui")).toBe(true);
      expect(toast.create).not.toHaveBeenCalled();
    });

    it("falls back to view for a mode that is not offered", async () => {
      render({ modes: ["view", "edit"] });
      sessionStorage.setItem("e6.posts.mode", "tag-script");
      const { PostModeMenu, SStorage } = await load();

      expect(PostModeMenu.mode).toBe("view");
      expect(document.getElementById("page").dataset.modeMenu).toBe("view");
      expect(SStorage.Posts.Mode).toBe("view");
    });

    it("does nothing without the mode menu", async () => {
      document.getElementById("mode-box-mode").remove();
      const { PostModeMenu } = await load();

      expect(PostModeMenu.mode).toBe("view");
      expect(clickThumbnail()).toBe(false);
      expect(hotkeys.listeners.size).toBe(0);
    });
  });

  describe("switching modes", () => {
    it("shows each mode's controls and remembers the mode", async () => {
      const { SStorage } = await load();

      selectMode("add-to-set");
      expect(visible("#set-id")).toBe(true);
      expect(postSet.populateSelect).toHaveBeenCalledTimes(1);
      expect(SStorage.Posts.Mode).toBe("add-to-set");

      selectMode("delete");
      expect(visible("#set-id")).toBe(false);
      expect(visible("#quick-mode-reason")).toBe(true);

      selectMode("tag-script");
      expect(visible("#quick-mode-reason")).toBe(false);
      expect(visible("#tag-script-ui")).toBe(true);
      expect(document.activeElement).toBe(document.getElementById("tag-script-field"));
      expect(toast.create).toHaveBeenCalledWith(expect.stringContaining("Switched to tag script #1"));
    });

    it("closes an open quick edit and restores hotkeys", async () => {
      const { QuickEdit } = await load();
      selectMode("edit");
      clickThumbnail();
      expect(QuickEdit.postID).toBe(POST_ID);
      expect(hotkeys.enabled).toBe(false);

      selectMode("view");
      expect(QuickEdit.postID).toBeNull();
      expect(hotkeys.enabled).toBe(true);
    });
  });

  describe("clicking a thumbnail", () => {
    it.each([
      ["add-fav", () => expect(bulk.favorite).toHaveBeenCalledWith(POST_ID)],
      ["remove-fav", () => expect(bulk.unfavorite).toHaveBeenCalledWith(POST_ID)],
      ["add-to-set", () => expect(postSet.add_post).toHaveBeenCalledWith("12", POST_ID)],
      ["remove-from-set", () => expect(postSet.remove_post).toHaveBeenCalledWith("12", POST_ID)],
      ["vote-up", () => expect(bulk.vote).toHaveBeenCalledWith(POST_ID, 1)],
      ["vote-down", () => expect(bulk.vote).toHaveBeenCalledWith(POST_ID, -1)],
      ["rating-s", () => expect(bulk.update).toHaveBeenCalledWith(POST_ID, { rating: "s" })],
      ["rating-q", () => expect(bulk.update).toHaveBeenCalledWith(POST_ID, { rating: "q" })],
      ["rating-e", () => expect(bulk.update).toHaveBeenCalledWith(POST_ID, { rating: "e" })],
      ["remove-parent", () => expect(bulk.update).toHaveBeenCalledWith(POST_ID, { parent_id: "" })],
      ["lock-rating", () => expect(bulk.update).toHaveBeenCalledWith(POST_ID, { is_rating_locked: "1" })],
      ["lock-note", () => expect(bulk.update).toHaveBeenCalledWith(POST_ID, { is_note_locked: "1" })],
      ["approve", () => expect(bulk.approve).toHaveBeenCalledWith(POST_ID)],
      ["delete", () => expect(bulk.delete).toHaveBeenCalledWith(POST_ID, "dupe")],
      ["undelete", () => expect(bulk.undelete).toHaveBeenCalledWith(POST_ID)],
      ["unflag", () => expect(bulk.unflag).toHaveBeenCalledWith(POST_ID, "none")],
      ["tag-script", () => expect(bulk.applyTagDiff).toHaveBeenCalledWith(POST_ID, ["canine"], "why")],
    ])("%s", async (mode, check) => {
      const { LStorage } = await load();
      LStorage.Posts.TagScript.Content = "[if wolf, canine]";
      selectMode(mode);

      expect(clickThumbnail()).toBe(true);
      check();
    });

    it("edit opens the quick editor", async () => {
      const { QuickEdit } = await load();
      selectMode("edit");

      expect(clickThumbnail()).toBe(true);
      expect(QuickEdit.postID).toBe(POST_ID);
    });

    it("follows the link in view mode", async () => {
      await load();
      expect(clickThumbnail()).toBe(false);
    });

    it.each([
      ["ctrl", { ctrlKey: true }],
      ["meta", { metaKey: true }],
      ["shift", { shiftKey: true }],
      ["middle button", { button: 1 }],
    ])("lets %s clicks through", async (_label, init) => {
      await load();
      selectMode("rating-s");

      expect(clickThumbnail(init)).toBe(false);
      expect(bulk.update).not.toHaveBeenCalled();
    });
  });

  describe("tag script hotkeys", () => {
    it("switch slots only in tag script mode", async () => {
      const { LStorage } = await load();
      expect(hotkeys.listeners.size).toBe(9);

      hotkeys.listeners.get("tag-script-3")();
      expect(LStorage.Posts.TagScript.ID).toBe(1);

      selectMode("tag-script");
      hotkeys.listeners.get("tag-script-3")();
      expect(LStorage.Posts.TagScript.ID).toBe(3);
    });

    it("are not registered for unprivileged users", async () => {
      user.is.privileged = false;
      await load();
      expect(hotkeys.listeners.size).toBe(0);
    });
  });
});
